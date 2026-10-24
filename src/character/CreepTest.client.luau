-- CreepTest v1.0 (Dino Arcade) — TEST ONLY. Hold C (keyboard), B (gamepad) or the on-screen Creep button
-- (touch) to creep: low stance, slow steps (speed MoveCreepSpeed, set by SprintTest).
-- Run breaks creep: while Sprinting is true (SprintTest) the dino stands up and runs; releasing Shift
-- with C still held goes back to creeping.
-- State:
--   CreepInput (character attribute, this client only): the creep key is held. SprintTest uses it for speed.
--   Creeping (character attribute, set by CreepServer, replicated): CreepInput and not Sprinting. Every
--     client's IdleAnimation reads it for the pose.
-- Client -> server: ReplicatedStorage.DinoCreepRequest:FireServer(wanted: boolean), sent only on change.
-- Diagnostic: character attribute CreepRequested (last value sent).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("DinoCreepRequest")

local ACTION = "DinoCreepTest"

local held = false
local sent = nil
local function sync()
	char:SetAttribute("CreepInput", held)
	local wanted = held and char:GetAttribute("Sprinting") ~= true
	if wanted ~= sent then
		sent = wanted
		char:SetAttribute("CreepRequested", wanted)
		remote:FireServer(wanted)
	end
end

local function onCreep(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		held = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		held = false
	end
	sync()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(ACTION, onCreep, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.C, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle(ACTION, "Creep")
char:GetAttributeChangedSignal("Sprinting"):Connect(sync)
sync()

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
