-- RamTest v1.0 (Dino Arcade) — TEST input for the T-Rex tree charge (owner's client only). E (keyboard), DPadUp (gamepad)
-- or the on-screen Ram button (touch) (key list: RAM_KEYS below). Bound only while the character attribute RamEnabled
-- is true (TRexModelData 1.20; the raptor has none and gets no button).
-- User: "a dedicated button that makes a dino run into the nearest tree so that its clear when its happening for
-- raptors to know the animation". Only this charge knocks latched raptors off (ShakeOffServer 1.1).
-- Flow:
--   1. Press (when allowed): the nearest tree within RamRange (60) studs (flat distance from the HumanoidRootPart to the
--      lowest Trunk* part of each DinoIsland.Trees model) is the target. None -> RamInputResult "noTree" and a short
--      "No tree in range" note on screen (NOTE_TIME s); nothing else happens.
--      Otherwise RamPredictedAt = server time (this client) and DinoRamRequest:FireServer(that time, trunk part);
--      RamServer 1.0 validates it and sets the replicated RamStartedAt (StaminaServer 1.3 charges RamStaminaCost 20).
--   2. Wind-up RamWindup s (0.4): the body stops (LinearVelocity "RamHold", Plane mode, 0) and swings to face the trunk;
--      IdleAnimation 1.19 shows head down + stomp. A denial (RamDeniedAt == the stamp) cancels it ("denied").
--   3. Charge: "RamHold" drives the body straight at the trunk (re-aimed every frame) at MoveRunSpeed x RamSpeedMul
--      (1.15) and the body faces it (CFrame yaw set in PreSimulation and at RenderStep Input + 4, after TurnLimit).
--      Contact = the HumanoidRootPart or a blocking hitbox (HitboxBlocks) grown by REACH studs overlaps one of the
--      tree's Trunk* / Root parts, or the body is BLOCKED (slower than BLOCK_SPEED_MUL x the charge speed after
--      BLOCK_AFTER s, within BLOCK_DIST studs of the trunk) -> DinoRamImpact:FireServer(stamp, true),
--      RamLocalImpactAt = server time, a short push back (RECOIL_PUSH studs/s for RECOIL_PUSH_TIME s), state
--      "recoil" for RamPose.RECOIL s. No contact after RamMaxCharge (3.5) s -> DinoRamImpact:FireServer(stamp, false)
--      ("miss"), RamLocalEndAt = server time.
-- Allowed only when: alive, not stunned (StunnedUntil), not latched, on the ground, not Exhausted, stamina >=
--   RamStaminaCost (StaminaEnabled ~= false), RamCooldown (6) s since the last local ram.
-- Binding: a dino without RamEnabled unbinds the action at start (clears a binding left by a previous character).
-- Settings (character attributes, defaults RamPose 1.0): RamEnabled, RamWindup, RamRange, RamStaminaCost,
--   RamCooldown, RamSpeedMul, RamMaxCharge, MoveRunSpeed.
-- Diagnostics (character attributes, this client): RamTestState ("off" / "ready" / "windup" / "charge" / "recoil" /
--   "dead"), RamLocalState (same, read by IdleAnimation 1.19 on this client), RamInputResult ("sent" / "noTree" /
--   "dead" / "stunned" / "latched" / "busy" / "air" / "exhausted" / "stamina" / "cooldown" / "denied"), RamTargetDist
--   (studs, whole, at the press), RamContact ("trunk" / "blocked" / "miss"), RamChargeSpeed (studs/s, whole),
--   RamLocalImpactAt / RamLocalEndAt (server time).
-- Humanoid drive (found in the first play-test: on the ground the Humanoid's own controller brakes to the move input,
--   so "RamHold" alone moved the T-Rex at ~6.6 studs/s instead of 51): every frame (PreSimulation and the Input + 4
--   RenderStep, after TurnLimit's Move) Humanoid:Move(zero) during the wind-up and the recoil, and during the charge
--   Humanoid:Move(charge direction) with Humanoid.WalkSpeed = the charge speed; the WalkSpeed from before the charge is
--   put back when it ends. Diagnostic RamWalkSpeed ("charge" while overridden, "restored").
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local requestRemote = ReplicatedStorage:WaitForChild("DinoRamRequest", 10)
local impactRemote = ReplicatedStorage:WaitForChild("DinoRamImpact", 10)

local ACTION = "DinoRam"
local BIND = "DinoRamFace"
local RAM_KEYS = {Enum.KeyCode.E, Enum.KeyCode.DPadUp} -- gamepad Y stays Roar (RoarTest)
local DEFAULTS = {RamEnabled = false, RamWindup = 0.4, RamRange = 60, RamStaminaCost = 20, RamCooldown = 6,
	RamSpeedMul = 1.15, RamMaxCharge = 3.5, MoveRunSpeed = 44, StaminaEnabled = true, StaminaMax = 100}
local REACH = 1.5
local HOLD_ACCEL = 1000      -- studs/s^2 the hold may use (force limit = mass x this)
local BLOCK_AFTER = 0.25
local BLOCK_SPEED_MUL = 0.3
local BLOCK_DIST = 14
local RECOIL = 0.45          -- = RamPose.RECOIL
local RECOIL_PUSH = 12
local RECOIL_PUSH_TIME = 0.2
local NOTE_TIME = 1.2
local JUMPING = Enum.HumanoidStateType.Jumping

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local shown = {}
local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		char:SetAttribute(attr, value)
	end
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function staminaNow()
	local max = get("StaminaMax")
	local now = workspace:GetServerTimeNow()
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local function grounded()
	local st = hum:GetState()
	return hum.FloorMaterial ~= Enum.Material.Air and st ~= JUMPING and st ~= Enum.HumanoidStateType.Freefall
end

-- "No tree in range" note
local note
local function showNote(text)
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	if not (note and note.Parent) then
		local gui = Instance.new("ScreenGui")
		gui.Name = "RamNote"
		gui.ResetOnSpawn = true
		gui.IgnoreGuiInset = true
		gui.Parent = pg
		note = Instance.new("TextLabel")
		note.Name = "Note"
		note.AnchorPoint = Vector2.new(0.5, 1)
		note.Position = UDim2.new(0.5, 0, 0.78, 0)
		note.Size = UDim2.new(0, 260, 0, 36)
		note.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		note.BackgroundTransparency = 0.35
		note.TextColor3 = Color3.fromRGB(255, 235, 190)
		note.Font = Enum.Font.GothamBold
		note.TextScaled = true
		note.Visible = false
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = note
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = note
		note.Parent = gui
	end
	note.Text = text
	note.Visible = true
	local mine = {}
	note:SetAttribute("Token", tostring(mine))
	task.delay(NOTE_TIME, function()
		if note and note.Parent and note:GetAttribute("Token") == tostring(mine) then note.Visible = false end
	end)
end

-- nearest tree: {tree, trunk (lowest Trunk* part), parts (Trunk* / Root), dist}
local function nearestTree()
	local island = workspace:FindFirstChild("DinoIsland")
	local trees = island and island:FindFirstChild("Trees")
	if not trees then return nil end
	local pos = flat(hrp.Position)
	local best
	for _, tree in ipairs(trees:GetChildren()) do
		local base, parts = nil, {}
		for _, d in ipairs(tree:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name:find("^Trunk") or d.Name == "Root") then
				table.insert(parts, d)
				if d.Name:find("^Trunk") and (not base or d.Position.Y < base.Position.Y) then base = d end
			end
		end
		if base then
			local dist = (flat(base.Position) - pos).Magnitude
			if dist <= get("RamRange") and (not best or dist < best.dist) then
				best = {tree = tree, trunk = base, parts = parts, dist = dist}
			end
		end
	end
	return best
end

local holdLV
local function hold(v)
	if v then
		if not holdLV then
			local att = Instance.new("Attachment")
			att.Name = "RamHoldAttachment"
			att.Parent = hrp
			holdLV = Instance.new("LinearVelocity")
			holdLV.Name = "RamHold"
			holdLV.Attachment0 = att
			holdLV.RelativeTo = Enum.ActuatorRelativeTo.World
			holdLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			holdLV.PrimaryTangentAxis = Vector3.new(1, 0, 0)
			holdLV.SecondaryTangentAxis = Vector3.new(0, 0, 1)
			holdLV.ForceLimitsEnabled = true
			holdLV.Enabled = false
			holdLV.Parent = hrp
		end
		holdLV.MaxForce = hrp.AssemblyMass * HOLD_ACCEL
		holdLV.PlaneVelocity = Vector2.new(v.X, v.Z)
		holdLV.Enabled = true
	elseif holdLV then
		holdLV.Enabled = false
	end
end

local state = "ready"
local stamp, t0, target, face, chargeDir, chargeSpeed
local savedWalkSpeed -- WalkSpeed to put back after the charge (nil = nothing to restore)
local lastRam = -math.huge
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function setState(s)
	state = s
	show("RamTestState", s)
	show("RamLocalState", s)
end

local function dirToTarget()
	local d = target and target.trunk.Parent and flat(target.trunk.Position - hrp.Position) or Vector3.zero
	if d.Magnitude < 1e-3 then return chargeDir or flat(hrp.CFrame.LookVector).Unit end
	return d.Unit
end

local function tryPress()
	local result
	local now = workspace:GetServerTimeNow()
	if hum.Health <= 0 then
		result = "dead"
	elseif (char:GetAttribute("StunnedUntil") or 0) > now then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif state ~= "ready" then
		result = "busy"
	elseif not grounded() then
		result = "air"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get("StaminaEnabled") ~= false and staminaNow() < get("RamStaminaCost") then
		result = "stamina"
	elseif os.clock() - lastRam < get("RamCooldown") then
		result = "cooldown"
	end
	if result then
		show("RamInputResult", result)
		return
	end
	local t = nearestTree()
	if not t then
		show("RamInputResult", "noTree")
		showNote("No tree in range")
		return
	end
	target = t
	show("RamTargetDist", math.floor(t.dist + 0.5))
	overlap.FilterDescendantsInstances = t.parts
	stamp = now
	t0 = os.clock()
	lastRam = t0
	local look = flat(hrp.CFrame.LookVector)
	face = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	char:SetAttribute("RamPredictedAt", stamp)
	if requestRemote then requestRemote:FireServer(stamp, t.trunk) end
	show("RamInputResult", "sent")
	hold(Vector3.zero)
	setState("windup")
end

local function touching()
	local parts = {hrp}
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxBlocks") == true then table.insert(parts, p) end
		end
	end
	for _, p in ipairs(parts) do
		if #workspace:GetPartBoundsInBox(p.CFrame, p.Size + Vector3.new(REACH, REACH, REACH) * 2, overlap) > 0 then return true end
	end
	return false
end

local function restoreWalkSpeed()
	if savedWalkSpeed then
		hum.WalkSpeed = savedWalkSpeed
		savedWalkSpeed = nil
		show("RamWalkSpeed", "restored")
	end
end

local function impact(kind)
	restoreWalkSpeed()
	if impactRemote then impactRemote:FireServer(stamp, true) end
	show("RamContact", kind)
	char:SetAttribute("RamLocalImpactAt", workspace:GetServerTimeNow())
	hold(-chargeDir * RECOIL_PUSH)
	t0 = os.clock()
	setState("recoil")
end

local function endCharge(kind)
	restoreWalkSpeed()
	if impactRemote then impactRemote:FireServer(stamp, false) end
	show("RamContact", kind)
	char:SetAttribute("RamLocalEndAt", workspace:GetServerTimeNow())
	hold(nil)
	setState("ready")
end

-- keep the body facing the way the ram wants this frame (after TurnLimit at Input + 1)
local function applyFacing()
	if (state == "windup" or state == "charge" or state == "recoil") and face and hum.Health > 0 then
		local pos = hrp.Position
		hrp.CFrame = CFrame.lookAt(pos, pos + face)
		-- the Humanoid's controller follows Move: stand still, or run at the trunk at the charge speed
		if state == "charge" and chargeDir and chargeSpeed then
			if hum.WalkSpeed ~= chargeSpeed then hum.WalkSpeed = chargeSpeed end
			hum:Move(chargeDir, false)
		else
			hum:Move(Vector3.zero, false)
		end
	end
end

local stepConn = RunService.PreSimulation:Connect(function(dt)
	if get("RamEnabled") ~= true then
		if state ~= "ready" and state ~= "off" then hold(nil); restoreWalkSpeed(); state = "ready" end
		show("RamTestState", "off")
		return
	end
	if hum.Health <= 0 then
		if state ~= "ready" then hold(nil); restoreWalkSpeed(); setState("ready") end
		show("RamTestState", "dead")
		return
	end
	if state == "windup" then
		if char:GetAttribute("RamDeniedAt") == stamp then
			show("RamInputResult", "denied")
			hold(nil)
			setState("ready")
			return
		end
		local W = get("RamWindup")
		local want = dirToTarget()
		local k = math.min(1, dt * 12)
		local f = face:Lerp(want, k)
		face = f.Magnitude > 1e-3 and f.Unit or want
		hold(Vector3.zero)
		if os.clock() - t0 >= W then
			chargeSpeed = get("MoveRunSpeed") * get("RamSpeedMul")
			chargeDir = want
			face = want
			t0 = os.clock()
			show("RamChargeSpeed", math.floor(chargeSpeed + 0.5))
			savedWalkSpeed = hum.WalkSpeed
			hum.WalkSpeed = chargeSpeed
			show("RamWalkSpeed", "charge")
			setState("charge")
		end
	elseif state == "charge" then
		chargeDir = dirToTarget()
		face = chargeDir
		hold(chargeDir * chargeSpeed)
		local t = os.clock() - t0
		local v = flat(hrp.AssemblyLinearVelocity).Magnitude
		local dist = target.trunk.Parent and flat(target.trunk.Position - hrp.Position).Magnitude or math.huge
		if touching() then
			impact("trunk")
		elseif t > BLOCK_AFTER and v < chargeSpeed * BLOCK_SPEED_MUL and dist < BLOCK_DIST then
			impact("blocked")
		elseif t > get("RamMaxCharge") or not target.trunk.Parent then
			endCharge("miss")
		end
	elseif state == "recoil" then
		local t = os.clock() - t0
		if t >= RECOIL_PUSH_TIME then hold(nil) end
		if t >= RECOIL then setState("ready") end
	else
		show("RamTestState", state)
	end
	applyFacing()
end)

pcall(function() RunService:UnbindFromRenderStep(BIND) end) -- a binding left by a previous character
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Input.Value + 4, applyFacing)

local bound = false
local function onRam(_, inputState)
	if inputState == Enum.UserInputState.Begin then tryPress() end
	return Enum.ContextActionResult.Sink
end
local function applyBinding()
	local on = get("RamEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onRam, true, Enum.ContextActionPriority.High.Value,
			table.unpack(RAM_KEYS))
		ContextActionService:SetTitle(ACTION, "Ram")
		bound = true
	elseif not on then
		ContextActionService:UnbindAction(ACTION) -- also clears a binding left by a previous character
		bound = false
	end
	show("RamTestState", on and state or "off")
end
char:GetAttributeChangedSignal("RamEnabled"):Connect(applyBinding)
applyBinding()
show("RamLocalState", "ready")

local function cleanup()
	stepConn:Disconnect()
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	if bound then ContextActionService:UnbindAction(ACTION) end
	if holdLV then holdLV.Enabled = false end
	if note and note.Parent then note.Parent:Destroy() end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
