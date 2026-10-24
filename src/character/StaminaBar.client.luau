-- StaminaBar v1.0 (Dino Arcade) — the player's own stamina bar, bottom centre of the screen (LocalScript).
-- Draws the server's stamina curve (StaminaServer 1.0) every frame from the replicated character attributes:
--   stamina = clamp(StaminaValue + StaminaRate * (serverNow - StaminaAt), 0, StaminaMax)
-- Look (arcade): wide rounded bar with a yellow-to-orange fill and a "STAMINA" label; a white tick at the
-- recovery mark (StaminaRecoverFraction, 25%). Below the mark the fill turns orange-red ("low").
-- Exhausted (Exhausted = true): the fill turns red and pulses, "EXHAUSTED" is written across the bar and the
-- recovery tick brightens, until the server clears Exhausted at the mark.
-- Diagnostics (character attributes, this client): StaminaBarState ("waiting" / "normal" / "low" / "exhausted"),
--   StaminaShown (whole number).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local char = script.Parent
local player = Players.LocalPlayer
local DEFAULT_MAX, DEFAULT_RECOVER = 100, 0.25

local COLORS = {
	back = Color3.fromRGB(20, 20, 26),
	fillA = Color3.fromRGB(255, 220, 60), fillB = Color3.fromRGB(255, 160, 30),
	low = Color3.fromRGB(255, 110, 35),
	exhausted = Color3.fromRGB(235, 55, 45),
}

local gui = player:WaitForChild("PlayerGui"):FindFirstChild("StaminaHUD")
if gui then gui:Destroy() end
gui = Instance.new("ScreenGui")
gui.Name = "StaminaHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -26)
holder.Size = UDim2.new(0.42, 0, 0, 44)
holder.BackgroundTransparency = 1
holder.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(260, 44)
limit.MaxSize = Vector2.new(560, 44)
limit.Parent = holder

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(6, 0)
title.Size = UDim2.new(0.5, 0, 0, 18)
title.Font = Enum.Font.FredokaOne
title.Text = "STAMINA"
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0.4
title.Parent = holder

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

local tick = Instance.new("Frame")
tick.Name = "RecoverTick"
tick.AnchorPoint = Vector2.new(0.5, 0)
tick.Size = UDim2.new(0, 2, 1, 0)
tick.BackgroundColor3 = Color3.new(1, 1, 1)
tick.BackgroundTransparency = 0.5
tick.BorderSizePixel = 0
tick.ZIndex = 3
tick.Parent = back

local warn = Instance.new("TextLabel")
warn.Name = "Exhausted"
warn.BackgroundTransparency = 1
warn.Size = UDim2.fromScale(1, 1)
warn.Font = Enum.Font.FredokaOne
warn.Text = "EXHAUSTED"
warn.TextSize = 16
warn.TextColor3 = Color3.new(1, 1, 1)
warn.TextStrokeTransparency = 0.3
warn.ZIndex = 4
warn.Visible = false
warn.Parent = back

gui.Parent = player.PlayerGui

local function setGradient(a, b)
	gradient.Color = ColorSequence.new(a, b)
end

local shown = {}
local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		char:SetAttribute(attr, value)
	end
end

local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		gui:Destroy()
		return
	end
	local value, at = char:GetAttribute("StaminaValue"), char:GetAttribute("StaminaAt")
	if typeof(value) ~= "number" or typeof(at) ~= "number" then
		show("StaminaBarState", "waiting")
		return
	end
	local max = char:GetAttribute("StaminaMax") or DEFAULT_MAX
	local recover = char:GetAttribute("StaminaRecoverFraction") or DEFAULT_RECOVER
	local rate = char:GetAttribute("StaminaRate") or 0
	local s = math.clamp(value + rate * (workspace:GetServerTimeNow() - at), 0, max)
	local frac = max > 0 and s / max or 0
	fill.Size = UDim2.fromScale(frac, 1)
	tick.Position = UDim2.fromScale(recover, 0)
	local state
	if char:GetAttribute("Exhausted") == true then
		state = "exhausted"
		setGradient(COLORS.exhausted, COLORS.exhausted)
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 4) -- 2 pulses per second
		fill.BackgroundTransparency = 0.35 * pulse
		stroke.Color = COLORS.exhausted
		stroke.Transparency = 0.2
		tick.BackgroundTransparency = 0
		warn.Visible = true
	else
		state = frac < recover and "low" or "normal"
		if state == "low" then setGradient(COLORS.low, COLORS.exhausted) else setGradient(COLORS.fillA, COLORS.fillB) end
		fill.BackgroundTransparency = 0
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.55
		tick.BackgroundTransparency = 0.5
		warn.Visible = false
	end
	show("StaminaBarState", state)
	show("StaminaShown", math.floor(s + 0.5))
end)
