-- HealthBar v1.1 (Dino Arcade) — the player's own health bar, just above the stamina bar (LocalScript).
-- Same arcade look as StaminaBar 1.0: "HEALTH" label + "current / max" on the right, rounded bar with a green
-- fill that turns red below LOW_FRACTION; a short red flash when health drops (bot bite).
-- "HIDDEN" badge next to the label while the character attribute Hidden is true (inside a bush, BotServer 1.0).
-- On death: "YOU DIED" across the screen with a respawn countdown (character attributes DiedAt + RespawnTime,
-- DinoHealthServer 1.0).
-- Diagnostics (character attributes, this client): HealthBarState ("normal" / "low" / "dead"), HealthShown.
-- v1.1: the death text is two labels — a big red "YOU DIED" and a smaller white "respawning in N" under it (one scaled
--   rich-text label drew the countdown larger than the title).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid")
local LOW_FRACTION = 0.3
local FLASH_TIME = 0.25

local COLORS = {
	back = Color3.fromRGB(20, 20, 26),
	fillA = Color3.fromRGB(130, 225, 90), fillB = Color3.fromRGB(70, 180, 60),
	low = Color3.fromRGB(235, 55, 45), lowB = Color3.fromRGB(190, 35, 30),
	hidden = Color3.fromRGB(120, 220, 110),
}

local old = player:WaitForChild("PlayerGui"):FindFirstChild("HealthHUD")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "HealthHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -76) -- 50 px above the stamina bar (StaminaBar: -26)
holder.Size = UDim2.new(0.42, 0, 0, 44)
holder.BackgroundTransparency = 1
holder.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(260, 44)
limit.MaxSize = Vector2.new(560, 44)
limit.Parent = holder

local function label(name, text, pos, size, align, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = 16
	l.TextXAlignment = align
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Parent = holder
	return l
end
label("Title", "HEALTH", UDim2.fromOffset(6, 0), UDim2.new(0.3, 0, 0, 18), Enum.TextXAlignment.Left)
local hiddenTag = label("Hidden", "HIDDEN", UDim2.new(0.3, 0, 0, 0), UDim2.new(0.4, 0, 0, 18), Enum.TextXAlignment.Center, COLORS.hidden)
hiddenTag.Visible = false
local value = label("Value", "", UDim2.new(0.6, -6, 0, 0), UDim2.new(0.4, 0, 0, 18), Enum.TextXAlignment.Right)

local back = Instance.new("Frame")
back.Name = "Back"
back.Position = UDim2.fromOffset(0, 20)
back.Size = UDim2.new(1, 0, 0, 22)
back.BackgroundColor3 = COLORS.back
back.BackgroundTransparency = 0.2
back.ClipsDescendants = true
back.Parent = holder
local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(0, 11)
backCorner.Parent = back
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = 0.55
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = back
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = back
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 11)
fillCorner.Parent = fill
local gradient = Instance.new("UIGradient")
gradient.Parent = fill

-- death overlay
local deathText = Instance.new("TextLabel")
deathText.Name = "Died"
deathText.AnchorPoint = Vector2.new(0.5, 0.5)
deathText.Position = UDim2.fromScale(0.5, 0.4)
deathText.Size = UDim2.new(0.6, 0, 0, 90)
deathText.BackgroundTransparency = 1
deathText.Font = Enum.Font.FredokaOne
deathText.TextScaled = true
deathText.Text = "YOU DIED"
deathText.TextColor3 = Color3.fromRGB(255, 80, 60)
deathText.TextStrokeTransparency = 0.2
deathText.Visible = false
deathText.Parent = gui
local deathSub = Instance.new("TextLabel") -- v1.1
deathSub.Name = "Respawn"
deathSub.AnchorPoint = Vector2.new(0.5, 0)
deathSub.Position = UDim2.new(0.5, 0, 0.4, 50)
deathSub.Size = UDim2.new(0.4, 0, 0, 34)
deathSub.BackgroundTransparency = 1
deathSub.Font = Enum.Font.FredokaOne
deathSub.TextScaled = true
deathSub.TextColor3 = Color3.new(1, 1, 1)
deathSub.TextStrokeTransparency = 0.3
deathSub.Visible = false
deathSub.Parent = gui

gui.Parent = player.PlayerGui

local shown = {}
local function show(attr, v)
	if shown[attr] ~= v then
		shown[attr] = v
		char:SetAttribute(attr, v)
	end
end

local lastHealth = hum.Health
local flashUntil = 0

local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		gui:Destroy()
		return
	end
	local max = math.max(1, hum.MaxHealth)
	local hp = math.max(0, hum.Health)
	if hp < lastHealth - 0.01 then flashUntil = os.clock() + FLASH_TIME end
	lastHealth = hp
	local frac = math.clamp(hp / max, 0, 1)
	fill.Size = UDim2.fromScale(frac, 1)
	value.Text = ("%d / %d"):format(math.ceil(hp), math.floor(max + 0.5))
	local low = frac < LOW_FRACTION
	gradient.Color = low and ColorSequence.new(COLORS.low, COLORS.lowB) or ColorSequence.new(COLORS.fillA, COLORS.fillB)
	if os.clock() < flashUntil then
		stroke.Color = COLORS.low
		stroke.Transparency = 0
		fill.BackgroundTransparency = 0.4
	else
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.55
		fill.BackgroundTransparency = 0
	end
	hiddenTag.Visible = char:GetAttribute("Hidden") == true and hp > 0
	local state
	if hp <= 0 then
		state = "dead"
		local diedAt = char:GetAttribute("DiedAt")
		local wait = char:GetAttribute("RespawnTime") or Players.RespawnTime
		local left = diedAt and math.max(0, math.ceil(wait - (workspace:GetServerTimeNow() - diedAt))) or nil
		deathSub.Text = left and ("respawning in " .. left) or "" -- v1.1
		deathText.Visible = true
		deathSub.Visible = left ~= nil
	else
		state = low and "low" or "normal"
		deathText.Visible = false
		deathSub.Visible = false
	end
	show("HealthBarState", state)
	show("HealthShown", math.ceil(hp))
end)
