-- SprintTest v1.1 (Dino Arcade) — TEST ONLY. Hold Shift (keyboard), L3 (gamepad) or the on-screen
-- Run button (touch) to run. No stamina yet; to be replaced by the real sprint/stamina system.
-- Speeds come from the character's attributes: MoveWalkSpeed (default 16), MoveRunSpeed (default 28).
-- Shift is taken at high priority, so Roblox's Shift-Lock camera toggle does not fire while this runs.
-- v1.1: while the character attribute Roaring is true (set by RoarTest), speed is MoveRoarSpeed (default 4).
-- Diagnostic: character attribute Sprinting (true/false).
local ContextActionService = game:GetService("ContextActionService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")

local DEFAULTS = {MoveWalkSpeed = 16, MoveRunSpeed = 28, MoveRoarSpeed = 4}
local ACTION = "DinoRunTest"

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local sprinting = false
local function apply()
	if char:GetAttribute("Roaring") then
		hum.WalkSpeed = get("MoveRoarSpeed")
	else
		hum.WalkSpeed = sprinting and get("MoveRunSpeed") or get("MoveWalkSpeed")
	end
	char:SetAttribute("Sprinting", sprinting)
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
apply()

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
