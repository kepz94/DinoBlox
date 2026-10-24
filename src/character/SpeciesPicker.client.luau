-- SpeciesPicker v1.0 (Dino Arcade) — TEST species picker (LocalScript, runs on the player's own character).
-- Two buttons, top-left of the screen: T-REX and RAPTOR. The one matching the current body (character attribute
-- Species) is highlighted. Clicking the other sends ReplicatedStorage.DinoSpeciesRequest:FireServer(species)
-- ("TRex" / "Raptor"); SpeciesServer 1.0 respawns the player as that dino. Buttons rest for 2 s after a click.
-- Diagnostics (character attributes, this client): SpeciesPickerState ("ready" / "sent" / "noRemote"),
--   SpeciesPickerLast (last species sent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local char = script.Parent
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("DinoSpeciesRequest", 10)

local CHOICES = {
	{species = "TRex", label = "T-REX"},
	{species = "Raptor", label = "RAPTOR"},
}
local COLORS = {
	on = Color3.fromRGB(255, 200, 50), off = Color3.fromRGB(32, 32, 40),
	textOn = Color3.fromRGB(30, 26, 10), textOff = Color3.new(1, 1, 1),
}

local old = player:WaitForChild("PlayerGui"):FindFirstChild("SpeciesPicker")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "SpeciesPicker"
gui.ResetOnSpawn = true
gui.DisplayOrder = 6

local frame = Instance.new("Frame")
frame.Name = "Row"
frame.Position = UDim2.fromOffset(16, 64)
frame.Size = UDim2.fromOffset(240, 40)
frame.BackgroundTransparency = 1
frame.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame

local current = char:GetAttribute("Species") or "TRex"
local busy = false
local buttons = {}

local function refresh()
	for _, c in ipairs(CHOICES) do
		local b = buttons[c.species]
		local on = c.species == current
		b.BackgroundColor3 = on and COLORS.on or COLORS.off
		b.TextColor3 = on and COLORS.textOn or COLORS.textOff
		b.AutoButtonColor = not on and not busy
	end
end

for i, c in ipairs(CHOICES) do
	local b = Instance.new("TextButton")
	b.Name = c.species
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(110, 40)
	b.Font = Enum.Font.FredokaOne
	b.Text = c.label
	b.TextSize = 20
	b.BackgroundTransparency = 0.1
	b.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	buttons[c.species] = b
	b.Activated:Connect(function()
		if busy or c.species == current then return end
		if not remote then
			char:SetAttribute("SpeciesPickerState", "noRemote")
			return
		end
		busy = true
		refresh()
		remote:FireServer(c.species)
		char:SetAttribute("SpeciesPickerState", "sent")
		char:SetAttribute("SpeciesPickerLast", c.species)
		task.delay(2, function()
			busy = false
			if gui.Parent then refresh() end
		end)
	end)
end

refresh()
char:SetAttribute("SpeciesPickerState", remote and "ready" or "noRemote")
gui.Parent = player.PlayerGui
