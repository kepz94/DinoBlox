-- SprintTest v1.4 (Dino Arcade) — TEST ONLY. Hold Shift (keyboard), L3 (gamepad) or the on-screen
-- Run button (touch) to run. No stamina yet; to be replaced by the real sprint/stamina system.
-- Speeds come from the character's attributes: MoveWalkSpeed (default 16), MoveRunSpeed (default 28).
-- Shift is taken at high priority, so Roblox's Shift-Lock camera toggle does not fire while this runs.
-- v1.1: while the character attribute Roaring is true (set by RoarTest), speed is MoveRoarSpeed (default 4).
-- v1.2: while the character attribute CreepInput is true (C held, set by CreepTest), speed is MoveCreepSpeed
--       (default 10). Priority: Roaring (MoveRoarSpeed) > Sprinting (MoveRunSpeed) > CreepInput
--       (MoveCreepSpeed) > walk (MoveWalkSpeed). Run breaks creep: CreepTest stands up while Sprinting.
-- v1.3: roar debuff speed. While DebuffUntil (server time, set by RoarServer 1.1) is in the future, the speed
--       chosen above is multiplied by DebuffSpeedMul (e.g. 1.1 = +10%). Re-applied when the debuff starts,
--       is refreshed, and when it runs out.
-- v1.4: stamina (StaminaServer 1.0). The run key state is sent as DinoRunRequest:FireServer(held) on every change
--       (the server drains stamina only while the dino really runs). While Exhausted (replicated, set by
--       StaminaServer) running is blocked: speed is MoveCreepSpeed, source "exhausted", Sprinting = false (so
--       CreepTest does not treat the held key as running). Priority: roar > exhausted > run > creep > walk.
-- Diagnostics: character attributes Sprinting (true/false), MoveSpeedSource ("roar"/"exhausted"/"run"/"creep"/"walk"),
--   MoveSpeedMul (1 = no debuff; v1.3).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")

local DEFAULTS = {MoveWalkSpeed = 16, MoveRunSpeed = 28, MoveRoarSpeed = 4, MoveCreepSpeed = 10}
local ACTION = "DinoRunTest"

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- v1.3: speed multiplier from an active roar debuff (1 when none or expired), and its end time
local function debuffSpeed()
	local untilT, mul = char:GetAttribute("DebuffUntil"), char:GetAttribute("DebuffSpeedMul")
	if typeof(untilT) == "number" and typeof(mul) == "number" and workspace:GetServerTimeNow() < untilT then
		return mul, untilT
	end
	return 1, nil
end

local sprinting = false
local runRemote = ReplicatedStorage:WaitForChild("DinoRunRequest", 10) -- v1.4
local runSent -- v1.4: last run key state sent to the server
local scheduledUntil -- v1.3: debuff end time an expiry re-apply is already scheduled for
local apply
function apply()
	local source
	if char:GetAttribute("Roaring") then
		source = "roar"
		hum.WalkSpeed = get("MoveRoarSpeed")
	elseif char:GetAttribute("Exhausted") == true then -- v1.4: out of stamina: crouch-walk, no running
		source = "exhausted"
		hum.WalkSpeed = get("MoveCreepSpeed")
	elseif sprinting then
		source = "run"
		hum.WalkSpeed = get("MoveRunSpeed")
	elseif char:GetAttribute("CreepInput") then
		source = "creep"
		hum.WalkSpeed = get("MoveCreepSpeed")
	else
		source = "walk"
		hum.WalkSpeed = get("MoveWalkSpeed")
	end
	-- v1.3: roar debuff speed on top of the chosen speed
	local mul, untilT = debuffSpeed()
	if mul ~= 1 then hum.WalkSpeed = hum.WalkSpeed * mul end
	char:SetAttribute("MoveSpeedMul", mul)
	if untilT and scheduledUntil ~= untilT then
		scheduledUntil = untilT
		task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.02, function()
			if char.Parent then apply() end
		end)
	end
	char:SetAttribute("Sprinting", sprinting and char:GetAttribute("Exhausted") ~= true) -- v1.4: not while exhausted
	if runRemote and runSent ~= sprinting then -- v1.4
		runSent = sprinting
		runRemote:FireServer(sprinting)
	end
	char:SetAttribute("MoveSpeedSource", source)
end

local function onRun(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprinting = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprinting = false
	end
	apply()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(ACTION, onRun, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(ACTION, "Run")
char:GetAttributeChangedSignal("MoveWalkSpeed"):Connect(apply)
char:GetAttributeChangedSignal("MoveRunSpeed"):Connect(apply)
char:GetAttributeChangedSignal("MoveRoarSpeed"):Connect(apply)
char:GetAttributeChangedSignal("Roaring"):Connect(apply)
char:GetAttributeChangedSignal("MoveCreepSpeed"):Connect(apply)
char:GetAttributeChangedSignal("CreepInput"):Connect(apply)
char:GetAttributeChangedSignal("DebuffUntil"):Connect(apply)    -- v1.3
char:GetAttributeChangedSignal("DebuffSpeedMul"):Connect(apply) -- v1.3
char:GetAttributeChangedSignal("Exhausted"):Connect(apply)      -- v1.4
apply()

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
