-- RoarTest v1.0 (Dino Arcade) — TEST ONLY. Press R (keyboard), Y (gamepad) or the on-screen Roar button
-- (touch) to roar. Sends the request to RoarServer; while this character is roaring it sets the
-- character attribute Roaring = true, which SprintTest uses to slow movement to MoveRoarSpeed.
-- Diagnostic: character attribute Roaring (true/false).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("DinoRoarRequest")

local ACTION = "DinoRoarTest"
local DEFAULT_DURATION = 1.4

local function onRoar(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		remote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(ACTION, onRoar, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle(ACTION, "Roar")

-- slow while roaring: driven by the server's start stamp so it matches what everyone sees
char:GetAttributeChangedSignal("RoarStartedAt"):Connect(function()
	local started = char:GetAttribute("RoarStartedAt")
	if not started then return end
	char:SetAttribute("Roaring", true)
	local duration = char:GetAttribute("RoarDuration") or DEFAULT_DURATION
	local remaining = started + duration - workspace:GetServerTimeNow()
	task.delay(math.max(0, remaining), function()
		-- only end if no newer roar started meanwhile
		if char:GetAttribute("RoarStartedAt") == started then
			char:SetAttribute("Roaring", false)
		end
	end)
end)
char:SetAttribute("Roaring", false)

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
