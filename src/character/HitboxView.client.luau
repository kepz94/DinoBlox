-- HitboxView v1.0 (Dino Arcade) — TEST. Press H to show / hide every dino's hitboxes on this client.
-- Shown (this client only): body-part boxes from DinoHitboxes — red = blocks movement, blue = bite-only —
-- plus each dino's HumanoidRootPart (yellow, the movement collider), all see-through.
-- New hitboxes (respawns, other players) are shown while the view is on.
-- Diagnostic: player attribute HitboxViewOn (true/false), kept across respawns.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local player = Players.LocalPlayer

local ACTION = "DinoHitboxView"
local SHOW_ALPHA = 0.55
local HRP_COLOR = Color3.fromRGB(240, 200, 60)

local saved = {} -- [part] = {Transparency, Color}

local function show(part, color)
	if saved[part] then return end
	saved[part] = {part.Transparency, part.Color}
	part.Transparency = SHOW_ALPHA
	if color then part.Color = color end
end

local function showModel(folder)
	for _, box in ipairs(folder:GetChildren()) do
		if box:IsA("BasePart") then show(box) end
	end
	local hrp = folder.Parent and folder.Parent:FindFirstChild("HumanoidRootPart")
	if hrp then show(hrp, HRP_COLOR) end
end

local function hideAll()
	for part, v in pairs(saved) do
		if part.Parent then part.Transparency, part.Color = v[1], v[2] end
	end
	table.clear(saved)
end

local addedConn
local function apply(on)
	player:SetAttribute("HitboxViewOn", on)
	if addedConn then addedConn:Disconnect(); addedConn = nil end
	hideAll()
	if not on then return end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Folder") and d.Name == "Hitboxes" then showModel(d) end
	end
	addedConn = workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Hitboxes" then
			task.defer(function() show(d); showModel(d.Parent) end)
		end
	end)
end

ContextActionService:BindAction(ACTION, function(_, state)
	if state == Enum.UserInputState.Begin then apply(not player:GetAttribute("HitboxViewOn")) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.H)

task.defer(apply, player:GetAttribute("HitboxViewOn") == true)

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
	if addedConn then addedConn:Disconnect(); addedConn = nil end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
