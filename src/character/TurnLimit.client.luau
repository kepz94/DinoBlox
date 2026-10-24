-- TurnLimit v1.0 (Dino Arcade) — heavy turning for the player's own dino (runs on the owner's client only).
-- Replaces the Humanoid's built-in turning (AutoRotate, about 580 deg/s) with a capped turn rate:
--   * the body yaws toward the move input at most TurnLimitRate degrees per second (default 180, so a
--     90 deg turn takes 0.5 s);
--   * movement follows the BODY, not the input: the dino moves where it faces, so sharp turns swing
--     wide in an arc (radius = speed / turn rate, e.g. run 44 -> about 14 studs);
--   * speed is not changed here (SprintTest still sets Humanoid.WalkSpeed).
-- How: bound to RenderStep right after Roblox's ControlModule (Enum.RenderPriority.Input + 1). Reads the
-- raw move input (camera-relative) from the Input Action System action
-- StarterPlayer.PlayerModule.InputContexts.CharacterContext.MoveAction (Vector2, x = right, y = forward;
-- keyboard, gamepad and touch thumbsticks all feed it); if that is missing, from the legacy
-- PlayerScripts.PlayerModule:GetControls():GetMoveVector(). Turns the HumanoidRootPart (CFrame yaw only,
-- position kept, upright), then calls Humanoid:Move(bodyForward * input magnitude), which overrides the
-- ControlModule's Move for this frame. No input -> no turn, no override.
-- Head lead: the turn still to go (target yaw - body yaw, degrees, positive = left) is written to the
-- local attribute TurnErrorLocal (read by this client's IdleAnimation) and sent to TurnServer, which sets
-- the replicated TurnError for everyone else's IdleAnimation (HeadLeadPose 1.0).
-- Toggle: character attribute TurnLimitEnabled = false restores Humanoid.AutoRotate = true and stops all
-- overrides. Tuning: TurnLimitRate (deg/s).
-- Diagnostics (character attributes, this client only):
--   TurnLimitState = "disabled" / "noControls" / "dead" / "holding" (no input) / "turning" / "aligned",
--   TurnBodyYaw (deg, whole), TurnTargetYaw (deg, whole; nil while holding), TurnErrorLocal (deg, whole),
--   TurnErrorSent (last value sent to the server), TurnRemote = "ok" / "missing",
--   TurnInputSource = "inputAction" / "controlModule" / "none".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local player = Players.LocalPlayer

local DEFAULTS = {TurnLimitEnabled = true, TurnLimitRate = 180}
local BIND = "DinoTurnLimit"
local ALIGNED_DEG = 0.5   -- remaining turn below this counts as aligned
local SEND_MIN_GAP = 0.05 -- seconds between sends to the server (at most 20 per second)
local SEND_STEP = 2       -- degrees of change before a new non-zero value is sent

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local shown = {}
local NIL = {} -- stands for an attribute that has been cleared
local function show(attr, value)
	local key = value == nil and NIL or value
	if shown[attr] ~= key then
		shown[attr] = key
		char:SetAttribute(attr, value)
	end
end

-- move input reader: returns Vector2 (x = right, y = forward, camera-relative), or nil when none is found
local controls
do
	local moveAction
	local pm = game:GetService("StarterPlayer"):WaitForChild("PlayerModule", 10)
	if pm then
		local ok, a = pcall(function()
			return pm:WaitForChild("InputContexts", 10):WaitForChild("CharacterContext", 10):WaitForChild("MoveAction", 10)
		end)
		if ok and a and a:IsA("InputAction") then moveAction = a end
	end
	if moveAction then
		controls = function() return moveAction:GetState() end
		show("TurnInputSource", "inputAction")
	else
		local ps = player:FindFirstChild("PlayerScripts")
		local legacy = ps and ps:FindFirstChild("PlayerModule")
		local ok, cm = pcall(function() return require(legacy):GetControls() end)
		if legacy and ok and cm then
			controls = function()
				local v = cm:GetMoveVector()
				return Vector2.new(v.X, -v.Z)
			end
			show("TurnInputSource", "controlModule")
		else
			show("TurnInputSource", "none")
		end
	end
end

local remote = ReplicatedStorage:WaitForChild("DinoTurnError", 10)
show("TurnRemote", remote and "ok" or "missing")

local function yawOf(v) -- positive = left (rotation about +Y), 0 = +X
	return math.atan2(-v.Z, v.X)
end

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- move input as a world direction on the ground plane (length = input strength, at most 1)
local function inputWorld()
	local mv = controls()
	if typeof(mv) ~= "Vector2" or mv.Magnitude < 1e-3 then return Vector3.zero end
	local cam = workspace.CurrentCamera
	local cf = cam and cam.CFrame or CFrame.identity
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then look = Vector3.new(cf.UpVector.X, 0, cf.UpVector.Z) end
	if look.Magnitude < 1e-3 then return Vector3.zero end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local w = right * mv.X + look * mv.Y
	if w.Magnitude > 1 then w = w.Unit end
	return w
end

local managed = false -- AutoRotate was turned off by this script
local lastSent, lastSentAt = 0, -math.huge

local function send(errDeg)
	local v = math.clamp(math.floor(errDeg + 0.5), -180, 180)
	if not remote or v == lastSent then return end
	if v ~= 0 and math.abs(v - lastSent) < SEND_STEP then return end
	local now = os.clock()
	if now - lastSentAt < SEND_MIN_GAP then return end -- retried next frame
	remote:FireServer(v)
	lastSent, lastSentAt = v, now
	show("TurnErrorSent", v)
end

local function release(state)
	if managed then
		hum.AutoRotate = true
		managed = false
	end
	show("TurnLimitState", state)
	show("TurnTargetYaw", nil)
	show("TurnErrorLocal", 0)
	send(0)
end

local function step(dt)
	if not get("TurnLimitEnabled") then return release("disabled") end
	if not controls then return release("noControls") end
	if hum.Health <= 0 then return release("dead") end

	if not managed or hum.AutoRotate then
		hum.AutoRotate = false
		managed = true
	end

	local bodyYaw = yawOf(hrp.CFrame.LookVector)
	local w = inputWorld()
	local strength = w.Magnitude
	if strength < 1e-3 then
		-- no input: body holds its heading, the ControlModule's Move(zero) stands
		show("TurnLimitState", "holding")
		show("TurnBodyYaw", math.floor(math.deg(bodyYaw) + 0.5))
		show("TurnTargetYaw", nil)
		show("TurnErrorLocal", 0)
		send(0)
		return
	end

	local targetYaw = yawOf(w)
	local err = wrapAngle(targetYaw - bodyYaw)
	local maxStep = math.rad(get("TurnLimitRate")) * dt
	local turn = math.clamp(err, -maxStep, maxStep)
	if math.abs(turn) > 1e-6 then
		bodyYaw += turn
		local pos = hrp.Position
		hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(math.cos(bodyYaw), 0, -math.sin(bodyYaw)))
	end
	local remaining = math.deg(wrapAngle(targetYaw - bodyYaw))
	local fwd = Vector3.new(math.cos(bodyYaw), 0, -math.sin(bodyYaw))
	hum:Move(fwd * strength, false)

	show("TurnLimitState", math.abs(remaining) < ALIGNED_DEG and "aligned" or "turning")
	show("TurnBodyYaw", math.floor(math.deg(bodyYaw) + 0.5))
	show("TurnTargetYaw", math.floor(math.deg(targetYaw) + 0.5))
	show("TurnErrorLocal", math.floor(remaining + 0.5))
	send(remaining)
end

RunService:BindToRenderStep(BIND, Enum.RenderPriority.Input.Value + 1, step)

local function cleanup()
	RunService:UnbindFromRenderStep(BIND)
end
hum.Died:Connect(function()
	cleanup()
	release("dead")
end)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
