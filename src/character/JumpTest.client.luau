-- JumpTest v1.0 (Dino Arcade) — TEST input for the leap (owner's client only). Jump key / gamepad A / touch jump
-- button. Only active while the character attribute JumpEnabled is true (default false: the T-Rex keeps the
-- default Roblox jump untouched).
-- While enabled, the Humanoid's built-in Jumping state is turned off, so a press never jumps straight away. Instead:
--   1. Press (when allowed): JumpPredictedAt = server time (this client only, so the crouch shows at once) and
--      DinoJumpRequest:FireServer(that time) (JumpServer 1.0 validates and sets the replicated JumpStartedAt).
--   2. Crouch: JumpWindup seconds (default 0.12). Movement continues as normal. If JumpServer denies this stamp
--      (JumpDeniedAt == the stamp) before the crouch ends, the leap is cancelled ("denied").
--   3. Launch: Jumping state on for this one jump, JumpPower = JumpLaunchPower (default 59: measured 11.0 studs
--      high, 0.67 s in the air at gravity 196.2 — the Humanoid's floor push adds speed during liftoff, so the
--      height is above JumpPower^2 / 2g), Humanoid:ChangeState(Jumping).
--      Forward boost: if the horizontal speed at takeoff is
--      above JumpBoostMinSpeed (default 2 studs/s), JumpBoost (default 10) studs/s is added along the body's
--      forward. Leap speed = the horizontal speed after the boost.
--   4. Air (JumpAirHold, default true): while move input is held, a LinearVelocity constraint (Plane mode, X/Z only,
--      this client's own instance "JumpAirHold" on the HumanoidRootPart) holds the horizontal velocity at the move
--      direction x leap speed (at least Humanoid.WalkSpeed) x input strength, so the boosted speed is kept and the
--      leap steers at the body's turn rate (TurnLimit 1.0 sets the move direction). Vertical motion is left to
--      gravity. Force limit = assembly mass x JUMP_HOLD_ACCEL. No input -> constraint off, Roblox air control
--      (slows down). Humanoid.WalkSpeed is not changed (Roblox air control pulls toward it inside each physics
--      step, and raising it also pulled the body down faster than gravity: peak 8.5 instead of 11 studs).
--      Jumping is turned off again once the body is airborne.
--   5. Landed (floor under the feet again after leaving the ground) -> ready. Holding the key re-leaps on landing
--      (each leap costs stamina).
-- Allowed only when: JumpEnabled, alive, standing on a floor, not Exhausted, stamina >= JumpStaminaCost
--   (when StaminaEnabled ~= false; read from StaminaServer's curve), JumpCooldown since the last local leap.
-- Input: StarterPlayer.PlayerModule.InputContexts.CharacterContext.JumpAction (Input Action System, boolean
--   state) when present; otherwise Humanoid.Jump (set by the control scripts while the key is held) and
--   UserInputService.JumpRequest.
-- Settings (character attributes): JumpEnabled, JumpWindup, JumpLaunchPower, JumpBoost, JumpBoostMinSpeed,
--   JumpAirHold, JumpStaminaCost, JumpCooldown.
-- Diagnostics (character attributes, this client): JumpTestState ("disabled" / "ready" / "crouch" / "air" /
--   "dead"), JumpInputResult ("sent" / "air" / "exhausted" / "stamina" / "cooldown" / "dead" / "denied" /
--   "noLiftoff"), JumpInputSource ("inputAction" / "humanoid"), JumpLaunchCount, JumpTakeoffSpeed,
--   JumpBoostApplied, JumpLeapSpeed, JumpAirSpeed (horizontal, 0.5 steps), JumpPeakHeight (studs above the
--   takeoff point, 0.1 steps), JumpAirTime (s, 0.01 steps), JumpAirHoldState ("off" / "holding" / "released"),
--   JumpAirDistance (horizontal studs from launch to landing, 0.1 steps).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local remote = ReplicatedStorage:WaitForChild("DinoJumpRequest", 10)

local DEFAULTS = {JumpEnabled = false, JumpWindup = 0.12, JumpLaunchPower = 59, JumpBoost = 10,
	JumpBoostMinSpeed = 2, JumpAirHold = true, JumpStaminaCost = 15, JumpCooldown = 0.5,
	StaminaEnabled = true, StaminaMax = 100}
local LIFTOFF_WAIT = 0.3   -- seconds after launch to leave the ground before giving up ("noLiftoff")
local REQUEST_FRESH = 0.1  -- seconds a JumpRequest event counts as "key pressed"
local JUMP_HOLD_ACCEL = 1000 -- studs/s^2 the air-hold constraint may use (force limit = mass x this)
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

-- jump input: Input Action System JumpAction when present, else Humanoid.Jump / JumpRequest
local jumpAction
do
	local pm = game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
	local ok, a = pcall(function()
		return pm and pm:WaitForChild("InputContexts", 5):WaitForChild("CharacterContext", 5):WaitForChild("JumpAction", 5)
	end)
	if ok and a and a:IsA("InputAction") then jumpAction = a end
end
show("JumpInputSource", jumpAction and "inputAction" or "humanoid")
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
local stamp, crouchAt, launchAt, leftGround
local takeoffY, peakY, leapSpeed = 0, 0, 0
local launchPos -- HumanoidRootPart position at the launch
local airLV -- LinearVelocity holding the leap speed in the air (created on first use)

-- air hold on (with the horizontal target velocity) or off
local function airHold(target)
	if target then
		if not airLV then
			local att = Instance.new("Attachment")
			att.Name = "JumpAirAttachment"
			att.Parent = hrp
			airLV = Instance.new("LinearVelocity")
			airLV.Name = "JumpAirHold"
			airLV.Attachment0 = att
			airLV.RelativeTo = Enum.ActuatorRelativeTo.World
			airLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			airLV.PrimaryTangentAxis = Vector3.new(1, 0, 0)
			airLV.SecondaryTangentAxis = Vector3.new(0, 0, 1)
			airLV.ForceLimitsEnabled = true
			airLV.Enabled = false
			airLV.Parent = hrp
		end
		airLV.MaxForce = hrp.AssemblyMass * JUMP_HOLD_ACCEL
		airLV.PlaneVelocity = Vector2.new(target.X, target.Z)
		airLV.Enabled = true
		show("JumpAirHoldState", "holding")
	elseif airLV and airLV.Enabled then
		airLV.Enabled = false
		show("JumpAirHoldState", "released")
	end
end
local lastLeap = -math.huge
local enabledApplied -- last JumpEnabled value applied to the Humanoid

local function applyEnabled()
	local on = get("JumpEnabled") == true
	if on == enabledApplied then return end
	local first = enabledApplied == nil
	enabledApplied = on
	if first and not on then
		state = "disabled" -- never enabled: the Humanoid is left exactly as it is
		return
	end
	if on then
		hum:SetStateEnabled(JUMPING, false)
		hum.UseJumpPower = true
		hum.JumpPower = get("JumpLaunchPower")
		state = "ready"
	else
		hum:SetStateEnabled(JUMPING, true)
		state = "disabled"
	end
end

local function tryPress()
	local result
	if hum.Health <= 0 then
		result = "dead"
	elseif not grounded() then
		result = "air"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get("StaminaEnabled") ~= false and staminaNow() < get("JumpStaminaCost") then
		result = "stamina"
	elseif os.clock() - lastLeap < get("JumpCooldown") then
		result = "cooldown"
	end
	if result then
		show("JumpInputResult", result)
		return
	end
	stamp = workspace:GetServerTimeNow()
	crouchAt = os.clock()
	lastLeap = crouchAt
	state = "crouch"
	char:SetAttribute("JumpPredictedAt", stamp)
	if remote then remote:FireServer(stamp) end
	show("JumpInputResult", "sent")
end

local function launch()
	local v = hrp.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	local takeoff = hv.Magnitude
	local boosted = takeoff > get("JumpBoostMinSpeed")
	if boosted then
		local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if fwd.Magnitude > 1e-3 then hv += fwd.Unit * get("JumpBoost") end
	end
	leapSpeed = hv.Magnitude
	local power = get("JumpLaunchPower")
	hum.UseJumpPower = true
	hum.JumpPower = power
	hum:SetStateEnabled(JUMPING, true)
	hum:ChangeState(JUMPING)
	hrp.AssemblyLinearVelocity = Vector3.new(hv.X, power, hv.Z)
	launchAt = os.clock()
	leftGround = false
	takeoffY, peakY = hrp.Position.Y, hrp.Position.Y
	launchPos = hrp.Position
	state = "air"
	show("JumpLaunchCount", (char:GetAttribute("JumpLaunchCount") or 0) + 1)
	show("JumpTakeoffSpeed", math.floor(takeoff * 2 + 0.5) / 2)
	show("JumpBoostApplied", boosted)
	show("JumpLeapSpeed", math.floor(leapSpeed * 2 + 0.5) / 2)
end

local function land(result)
	hum:SetStateEnabled(JUMPING, false)
	airHold(nil)
	show("JumpAirHoldState", "off")
	state = "ready"
	if result then show("JumpInputResult", result) end
end

local conn = RunService.PreSimulation:Connect(function()
	applyEnabled()
	if not enabledApplied then
		show("JumpTestState", "disabled")
		return
	end
	if hum.Health <= 0 then
		show("JumpTestState", "dead")
		return
	end
	local now = os.clock()
	if state == "ready" then
		if jumpHeld() then tryPress() end
	elseif state == "crouch" then
		if char:GetAttribute("JumpDeniedAt") == stamp then
			state = "ready"
			show("JumpInputResult", "denied")
		elseif now - crouchAt >= get("JumpWindup") then
			launch()
		end
	elseif state == "air" then
		local y = hrp.Position.Y
		if y > peakY then peakY = y end
		if not leftGround then
			if not grounded() then
				leftGround = true
				hum:SetStateEnabled(JUMPING, false) -- off again: only this one jump
			elseif now - launchAt > LIFTOFF_WAIT then
				land("noLiftoff")
			end
		else
			if grounded() then
				show("JumpAirTime", math.floor((now - launchAt) * 100 + 0.5) / 100)
				show("JumpPeakHeight", math.floor((peakY - takeoffY) * 10 + 0.5) / 10)
				local d = hrp.Position - launchPos
				show("JumpAirDistance", math.floor(Vector3.new(d.X, 0, d.Z).Magnitude * 10 + 0.5) / 10)
				land(nil)
			elseif get("JumpAirHold") then
				-- keep the boosted leap speed while steering with input held
				local md = hum.MoveDirection
				local m = md.Magnitude
				if m > 0.05 then
					airHold(md.Unit * (math.max(leapSpeed, hum.WalkSpeed) * math.min(1, m)))
				else
					airHold(nil)
				end
			end
		end
		local v = hrp.AssemblyLinearVelocity
		show("JumpAirSpeed", math.floor(Vector3.new(v.X, 0, v.Z).Magnitude * 2 + 0.5) / 2)
	end
	show("JumpTestState", state)
end)

local function cleanup()
	conn:Disconnect()
	if airLV then airLV.Enabled = false end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
