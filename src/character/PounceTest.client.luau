-- PounceTest v1.2 (Dino Arcade) — TEST input for the raptor pounce (owner's client only). F (keyboard), X (gamepad)
-- or the on-screen Pounce button (touch). Bound only while the character attribute PounceEnabled is true (the T-Rex
-- has no pounce and gets no button).
-- Flow:
--   1. Press (when allowed): PouncePredictedAt = server time (this client) and DinoPounceRequest:FireServer(that
--      time); PounceServer 1.0 validates it and sets the replicated PounceStartedAt (StaminaServer 1.2 charges 15).
--   2. Wind-up: PounceWindup s (default 0.1; IdleAnimation shows a crouch). A denial (PounceDeniedAt == the stamp)
--      cancels it.
--   3. Lunge: a flat leap along the body's forward: PounceUpSpeed (28 studs/s) up, horizontal speed set so the arc
--      lands PounceDistance (20) studs ahead on flat ground; a LinearVelocity (Plane mode, "PounceHold") keeps that
--      horizontal speed through the flight. The Humanoid's Jumping state applies Humanoid.JumpPower as the lift, so
--      JumpPower is set to PounceUpSpeed for the launch and put back once the Humanoid is in Freefall (the jump
--      impulse is applied a step after ChangeState; JUMP_RESTORE s at the latest), otherwise the leap's JumpPower 59
--      makes a 10-stud-high, ~45-stud arc.
--      Every frame a sphere (radius PounceReach) is swept from the raptor's front along the motion against the
--      "Hitboxes" parts of every latchable dino (Workspace model, Bitable = true,
--      Species set, not knocked out, extents at least PounceSizeRatio x the raptor's). Landing on the ground, or
--      FLIGHT_MAX s without contact, ends the lunge ("miss").
--   4. Contact: the latch frame = the contact point moved PounceLatchStandoff studs off the surface, its up = the
--      surface normal, its forward = straight up the surface (walls, sides) or the lunge direction (tops, normal.Y >
--      0.7). Sent as DinoPounceClaim:FireServer(stamp, hitboxPart, offset relative to the part). The raptor latches
--      at once (prediction); if the server has not confirmed (PounceLatched) within CONFIRM_WAIT s, or rejects it,
--      it lets go.
--   5. Latched: Humanoid.PlatformStand = true; the HumanoidRootPart is put at part.CFrame * offset every frame
--      (RenderStep after TurnLimit, and PreSimulation), velocity zeroed, so it rides the target's animated body on
--      this screen and replicates to everyone else. Damage and stamina drain are server-side (PounceServer /
--      StaminaServer).
--   6. Release: pressing jump sends DinoPounceRelease and leaps off (PounceLeapOffSpeed away from the surface +
--      PounceLeapOffUp up); a server release (PounceLatched = false: stamina, target KO, ...) drops off with a small
--      push. The body is set upright, PlatformStand off.
-- v1.1: pin. Targets now include Bitable dinos of the raptor's size or smaller (not knocked out, not already pinned).
--   Touching one pins it (PounceServer 1.1 decides latch / pin by the same size rule): the raptor stands on top of the
--   downed target, upright, facing the lunge direction, its HumanoidRootPart at the target's HumanoidRootPart X/Z and
--   PouncePinRideHeight studs above the ground under it (default: own hip height + 0.9 x the target's thickness), so it
--   follows the target as it rolls onto its side; IdleAnimation shows the same gripping / biting-down pose. Jump leaps
--   off backwards. Diagnostic: PounceKind ("latch" / "pin").
-- v1.2: pin contact column. A same-size target sits below the lunge arc (the front sweep runs at body height and the
--   arc lifts it ~2.7 studs), so the lunge flew over it. When the front sweep misses, a second sphere (radius
--   PounceReach) is swept straight down from the front point to the raptor's feet level (HumanoidRootPart half height
--   + HipHeight) against pin-target hitboxes only; a hit there is the contact. Latch targets are unchanged (front
--   sweep only). Diagnostic: PounceContactProbe ("front" / "column").
-- Binding: a dino without PounceEnabled unbinds the action at start, so a binding left by a previous character
--   (the old character's scripts are destroyed with it before their cleanup runs) never shows a Pounce button.
-- Allowed only when: alive, on the ground, not latched, not Exhausted, stamina >= PounceStaminaCost (StaminaEnabled
--   ~= false), PounceCooldown since the last local pounce.
-- Settings (character attributes): PounceEnabled, PounceWindup, PounceDistance, PounceUpSpeed, PounceReach,
--   PounceLatchStandoff, PounceLeapOffSpeed, PounceLeapOffUp, PounceCooldown, PounceStaminaCost, PounceSizeRatio.
-- Diagnostics (character attributes, this client): PounceTestState ("off" / "ready" / "windup" / "lunge" / "latched"
--   / "dead"), PounceLocalState (same, read by IdleAnimation 1.16 on this client), PounceInputResult ("sent" / "air"
--   / "exhausted" / "stamina" / "cooldown" / "latched" / "dead" / "denied"), PounceContact ("hit" / "miss" /
--   "noTargets"), PounceContactSegment, PounceLungeSpeed, PounceLatchSource ("predicted" / "server"),
--   PounceLetGo (last local release: "jump" / "rejected" / "server:<reason>" / "gone" / "dead" / "orphan" = a late
--   server latch this client was no longer riding, released at once), PounceTargets
--   (latchable / pinnable dinos found at launch), PounceKind (v1.1).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local requestRemote = ReplicatedStorage:WaitForChild("DinoPounceRequest", 10)
local claimRemote = ReplicatedStorage:WaitForChild("DinoPounceClaim", 10)
local releaseRemote = ReplicatedStorage:WaitForChild("DinoPounceRelease", 10)

local ACTION = "DinoPounce"
local BIND = "DinoPounceLatch"
local DEFAULTS = {PounceEnabled = false, PounceWindup = 0.1, PounceDistance = 20, PounceUpSpeed = 28,
	PounceReach = 1.6, PounceLatchStandoff = 2.4, PounceLeapOffSpeed = 30, PounceLeapOffUp = 35,
	PounceCooldown = 3, PounceStaminaCost = 15, PounceSizeRatio = 1.5, StaminaEnabled = true, StaminaMax = 100}
local FLIGHT_MAX = 1.0     -- seconds of lunge without contact before it ends
local CONFIRM_WAIT = 0.6   -- seconds a predicted latch waits for the server
local FRONT = 0.45         -- share of the body's length ahead of the centre where the sweep starts (~snout tip)
local HOLD_ACCEL = 1000    -- studs/s^2 the lunge hold may use (force limit = mass x this)
local JUMPING = Enum.HumanoidStateType.Jumping
local REQUEST_FRESH = 0.1
local JUMP_RESTORE = 0.15 -- seconds after the launch JumpPower is put back at the latest

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

-- jump input (same sources as JumpTest 1.0)
local jumpAction
do
	local pm = game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
	local ok, a = pcall(function()
		return pm and pm:WaitForChild("InputContexts", 5):WaitForChild("CharacterContext", 5):WaitForChild("JumpAction", 5)
	end)
	if ok and a and a:IsA("InputAction") then jumpAction = a end
end
local lastRequest = -math.huge
UserInputService.JumpRequest:Connect(function() lastRequest = os.clock() end)
local function jumpHeld()
	if jumpAction then
		local ok, v = pcall(function() return jumpAction:GetState() end)
		if ok and v == true then return true end
	end
	return hum.Jump or os.clock() - lastRequest < REQUEST_FRESH
end

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

local state = "ready"
local stamp, windupAt, launchAt, leftGround
local lungeDir, lungeSpeed = Vector3.new(1, 0, 0), 0
local targets = {}         -- hitbox parts of latchable / pinnable dinos (found at launch)
local pinTargets = {}      -- v1.2: hitbox parts of the pin targets only (found at launch)
local latchPart, latchOffset, latchSource, claimAt
local lastPounce = -math.huge
local jumpWasHeld = false
local orphanSentAt = -math.huge
local letGoAt = -math.huge -- last local release (the server's PounceLatched lags behind it)
local holdLV
local savedJumpPower -- Humanoid.JumpPower to put back after the launch (nil = nothing to restore)
local kinds = {}           -- v1.1: [target model] = "latch" / "pin" (found at launch)
local pinMode, pinRot, pinGroundY, pinHeight = false, CFrame.identity, 0, 0 -- v1.1

local function hold(target)
	if target then
		if not holdLV then
			local att = Instance.new("Attachment")
			att.Name = "PounceHoldAttachment"
			att.Parent = hrp
			holdLV = Instance.new("LinearVelocity")
			holdLV.Name = "PounceHold"
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
		holdLV.PlaneVelocity = Vector2.new(target.X, target.Z)
		holdLV.Enabled = true
	elseif holdLV then
		holdLV.Enabled = false
	end
end

-- hitbox parts of every latchable / pinnable dino right now (v1.1: smaller ones too, as pin targets)
local function findTargets()
	local list = {}
	local mySize = char:GetExtentsSize().Magnitude
	local ratio = get("PounceSizeRatio")
	local found = 0
	kinds = {}
	pinTargets = {} -- v1.2
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Folder") and d.Name == "Hitboxes" then
			local m = d.Parent
			if m and m:IsA("Model") and m ~= char and m:GetAttribute("Bitable") == true and m:GetAttribute("Species") ~= nil
				and m:GetAttribute("DummyState") ~= "ko" and m:GetAttribute("PinnedAt") == nil then
				found += 1
				kinds[m] = m:GetExtentsSize().Magnitude >= mySize * ratio and "latch" or "pin"
				for _, p in ipairs(d:GetChildren()) do
					if p:IsA("BasePart") then
						table.insert(list, p)
						if kinds[m] == "pin" then table.insert(pinTargets, p) end -- v1.2
					end
				end
			end
		end
	end
	show("PounceTargets", found)
	return list
end

local function setLocalState(s)
	state = s
	show("PounceTestState", s)
	show("PounceLocalState", s)
end

local function tryPress()
	local result
	if hum.Health <= 0 then
		result = "dead"
	elseif state == "latched" then
		result = "latched"
	elseif state ~= "ready" or not grounded() then
		result = "air"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get("StaminaEnabled") ~= false and staminaNow() < get("PounceStaminaCost") then
		result = "stamina"
	elseif os.clock() - lastPounce < get("PounceCooldown") then
		result = "cooldown"
	end
	if result then
		show("PounceInputResult", result)
		return
	end
	stamp = workspace:GetServerTimeNow()
	windupAt = os.clock()
	lastPounce = windupAt
	char:SetAttribute("PouncePredictedAt", stamp)
	if requestRemote then requestRemote:FireServer(stamp) end
	show("PounceInputResult", "sent")
	setLocalState("windup")
end

local function launch()
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	lungeDir = look.Magnitude > 1e-3 and look.Unit or Vector3.new(1, 0, 0)
	local vy = get("PounceUpSpeed")
	local flight = 2 * vy / math.max(1, workspace.Gravity)
	lungeSpeed = get("PounceDistance") / flight
	targets = findTargets()
	savedJumpPower = hum.JumpPower
	hum.UseJumpPower = true
	hum.JumpPower = vy -- the Jumping state lifts with JumpPower
	hum:SetStateEnabled(JUMPING, true)
	hum:ChangeState(JUMPING)
	hrp.AssemblyLinearVelocity = lungeDir * lungeSpeed + Vector3.new(0, vy, 0)
	hold(lungeDir * lungeSpeed)
	launchAt = os.clock()
	leftGround = false
	show("PounceLungeSpeed", math.floor(lungeSpeed * 2 + 0.5) / 2)
	setLocalState("lunge")
end

-- latch frame from a contact on a hitbox part
local function latchFrame(pos, normal)
	local U = normal.Magnitude > 1e-3 and normal.Unit or Vector3.new(0, 1, 0)
	local want = (U.Y > 0.7) and lungeDir or Vector3.new(0, 1, 0)
	local F = want - U * want:Dot(U)
	if F.Magnitude < 1e-3 then F = lungeDir - U * lungeDir:Dot(U) end
	if F.Magnitude < 1e-3 then F = Vector3.new(1, 0, 0) end
	F = F.Unit
	local R = F:Cross(U).Unit
	return CFrame.fromMatrix(pos + U * get("PounceLatchStandoff"), R, U, -F)
end

local function latchTo(part, pos, normal)
	hold(nil)
	if savedJumpPower then hum.JumpPower = savedJumpPower; savedJumpPower = nil end
	local model = part.Parent and part.Parent.Parent
	local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
	pinMode = model ~= nil and kinds[model] == "pin" and targetRoot ~= nil -- v1.1
	show("PounceKind", pinMode and "pin" or "latch")
	if pinMode then
		-- stand on top of the downed target: ground under it + ride height, facing the lunge direction
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {char, model}
		local hit = workspace:Raycast(targetRoot.Position, Vector3.new(0, -60, 0), params)
		local th = model:FindFirstChildOfClass("Humanoid")
		pinGroundY = hit and hit.Position.Y or (targetRoot.Position.Y - targetRoot.Size.Y / 2 - (th and th.HipHeight or 0))
		local ext = model:GetExtentsSize()
		local thickness = math.min(ext.X, ext.Y, ext.Z)
		pinHeight = char:GetAttribute("PouncePinRideHeight") or (hrp.Size.Y / 2 + hum.HipHeight + thickness * 0.9)
		pinRot = CFrame.lookAt(Vector3.zero, lungeDir).Rotation
		latchPart, latchOffset = targetRoot, CFrame.identity
		latchSource, claimAt = "predicted", os.clock()
		if claimRemote then claimRemote:FireServer(stamp, part, CFrame.identity) end
		hum.PlatformStand = true
		jumpWasHeld = jumpHeld()
		show("PounceContact", "hit")
		show("PounceContactSegment", part:GetAttribute("HitboxSegment") or part.Name)
		show("PounceLatchSource", "predicted")
		setLocalState("latched")
		return
	end
	local cf = latchFrame(pos, normal)
	latchPart, latchOffset = part, part.CFrame:ToObjectSpace(cf)
	latchSource, claimAt = "predicted", os.clock()
	if claimRemote then claimRemote:FireServer(stamp, part, latchOffset) end
	hum.PlatformStand = true
	jumpWasHeld = jumpHeld()
	show("PounceContact", "hit")
	show("PounceContactSegment", part:GetAttribute("HitboxSegment") or part.Name)
	show("PounceLatchSource", "predicted")
	setLocalState("latched")
end

local function letGo(reason, leapOff)
	local cf = latchPart and latchPart.Parent and (latchPart.CFrame * latchOffset) or hrp.CFrame
	latchPart, latchOffset = nil, nil
	hum.PlatformStand = false
	-- stand upright, facing the way the body pointed (or away from the surface if it pointed straight up)
	local U = cf.UpVector
	local f = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if f.Magnitude < 0.2 then f = Vector3.new(U.X, 0, U.Z) end
	if f.Magnitude < 1e-3 then f = Vector3.new(1, 0, 0) end
	local pos = cf.Position
	hrp.CFrame = CFrame.lookAt(pos, pos + f.Unit)
	local away = Vector3.new(U.X, 0, U.Z)
	away = away.Magnitude > 1e-3 and away.Unit or -f.Unit
	if leapOff then
		hrp.AssemblyLinearVelocity = away * get("PounceLeapOffSpeed") + Vector3.new(0, get("PounceLeapOffUp"), 0)
	else
		hrp.AssemblyLinearVelocity = away * 12 + Vector3.new(0, 10, 0)
	end
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	show("PounceLetGo", reason)
	letGoAt = os.clock()
	setLocalState("ready")
end

local function restoreJumpPower()
	if savedJumpPower then
		hum.JumpPower = savedJumpPower
		savedJumpPower = nil
	end
end

local function endLunge(result)
	hold(nil)
	restoreJumpPower()
	hum:SetStateEnabled(JUMPING, char:GetAttribute("JumpEnabled") ~= true) -- back to what JumpTest expects
	show("PounceContact", result)
	setLocalState("ready")
end

-- sweep a sphere from the raptor's front along this frame's motion; returns part, position, normal
local function sweep(dt)
	if #targets == 0 then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	local v = hrp.AssemblyLinearVelocity
	local front = hrp.Position + lungeDir * (char:GetExtentsSize().Z * FRONT) -- extents Z = body length (HRP faces -Z)
	local reach = get("PounceReach")
	-- already touching?
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = targets
	local touching = workspace:GetPartBoundsInRadius(front, reach, op)
	if #touching > 0 then
		local part = touching[1]
		local lp = part.CFrame:PointToObjectSpace(front)
		local h = part.Size / 2
		local cp = part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
		local n = front - cp
		if n.Magnitude < 1e-3 then n = -lungeDir end
		show("PounceContactProbe", "front") -- v1.2
		return part, cp, n.Unit
	end
	local dist = math.max(v.Magnitude * dt, 0.1) + 1
	local dir = v.Magnitude > 1e-3 and v.Unit or lungeDir
	local r = workspace:Spherecast(front, reach, dir * dist, params)
	if r then
		show("PounceContactProbe", "front") -- v1.2
		return r.Instance, r.Position, r.Normal
	end
	-- v1.2: pin targets sit under the arc; sweep straight down from the front point to feet level
	if #pinTargets > 0 then
		local cparams = RaycastParams.new()
		cparams.FilterType = Enum.RaycastFilterType.Include
		cparams.FilterDescendantsInstances = pinTargets
		local depth = hrp.Size.Y / 2 + hum.HipHeight
		local c = workspace:Spherecast(front, reach, Vector3.new(0, -depth, 0), cparams)
		if c then
			show("PounceContactProbe", "column")
			return c.Instance, c.Position, c.Normal
		end
	end
	return nil
end

local function followLatch()
	if state == "latched" and latchPart and latchPart.Parent then
		if pinMode then -- v1.1: on top of the pinned target (it rolls; the raptor stays upright)
			local tp = latchPart.Position
			hrp.CFrame = CFrame.new(tp.X, pinGroundY + pinHeight, tp.Z) * pinRot
		else
			hrp.CFrame = latchPart.CFrame * latchOffset
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local stepConn = RunService.PreSimulation:Connect(function(dt)
	if get("PounceEnabled") ~= true then
		if state ~= "ready" and state ~= "off" then
			if state == "latched" then letGo("disabled", false) else hold(nil) end
		end
		show("PounceTestState", "off")
		return
	end
	if hum.Health <= 0 then
		if state == "latched" then letGo("dead", false) end
		hold(nil)
		show("PounceTestState", "dead")
		return
	end
	if state == "windup" then
		if char:GetAttribute("PounceDeniedAt") == stamp then
			show("PounceInputResult", "denied")
			setLocalState("ready")
		elseif os.clock() - windupAt >= get("PounceWindup") then
			launch()
		end
	elseif state == "lunge" then
		if not leftGround and not grounded() then
			leftGround = true
			hum:SetStateEnabled(JUMPING, char:GetAttribute("JumpEnabled") ~= true)
		end
		if savedJumpPower and (hum:GetState() == Enum.HumanoidStateType.Freefall or os.clock() - launchAt > JUMP_RESTORE) then
			restoreJumpPower()
		end
		local part, pos, normal = sweep(dt)
		if part then
			latchTo(part, pos, normal)
		elseif (leftGround and grounded()) then
			endLunge(#targets == 0 and "noTargets" or "miss")
		elseif os.clock() - launchAt > FLIGHT_MAX then
			endLunge("miss")
		end
	elseif state == "latched" then
		local serverLatched = char:GetAttribute("PounceLatched") == true
		if latchSource == "predicted" then
			if serverLatched and char:GetAttribute("PounceLatchedAt") and char:GetAttribute("PounceLatchedAt") >= stamp - 0.5 then
				latchSource = "server"
				show("PounceLatchSource", "server")
				local v = char:FindFirstChild("PounceLatchPart")
				if v and v.Value and v.Value:IsA("BasePart") then
					latchPart = v.Value
					if not pinMode then latchOffset = char:GetAttribute("PounceLatchOffset") or latchOffset end
				end
			elseif os.clock() - claimAt > CONFIRM_WAIT then
				letGo("rejected", false)
				return
			end
		elseif not serverLatched then
			letGo("server:" .. tostring(char:GetAttribute("PounceReleaseReason")), false)
			return
		end
		if not (latchPart and latchPart.Parent) then
			if releaseRemote then releaseRemote:FireServer() end
			letGo("gone", false)
			return
		end
		local held = jumpHeld()
		if held and not jumpWasHeld then
			if releaseRemote then releaseRemote:FireServer() end
			letGo("jump", true)
			jumpWasHeld = held
			return
		end
		jumpWasHeld = held
		followLatch()
	else
		-- the server holds a latch this client is not riding (late confirmation): let it go there too
		if char:GetAttribute("PounceLatched") == true and os.clock() - orphanSentAt > 0.3 and os.clock() - letGoAt > 0.5 then
			orphanSentAt = os.clock()
			if releaseRemote then releaseRemote:FireServer() end
			show("PounceLetGo", "orphan")
		end
		show("PounceTestState", state)
	end
end)

-- after TurnLimit (Input + 1), before the camera: keeps the latched body where it rides for this frame's render
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Input.Value + 2, followLatch)

local bound = false
local function onPounce(_, inputState)
	if inputState == Enum.UserInputState.Begin then tryPress() end
	return Enum.ContextActionResult.Sink
end
local function applyBinding()
	local on = get("PounceEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onPounce, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.F, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(ACTION, "Pounce")
		bound = true
	elseif not on then
		ContextActionService:UnbindAction(ACTION) -- also clears a binding left by a previous character
		bound = false
	end
	show("PounceTestState", on and state or "off")
end
char:GetAttributeChangedSignal("PounceEnabled"):Connect(applyBinding)
applyBinding()

local function cleanup()
	stepConn:Disconnect()
	RunService:UnbindFromRenderStep(BIND)
	if bound then ContextActionService:UnbindAction(ACTION) end
	if holdLV then holdLV.Enabled = false end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
