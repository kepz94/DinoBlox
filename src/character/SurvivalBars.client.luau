-- SurvivalBars v1.0 (Dino Arcade) — the player's own Hunger and Thirst bars + hold-E eat / drink (LocalScript).
-- Layout: one holder the same size as HealthBar 1.1 / StaminaBar 1.1 (42% wide, min 260 / max 560 px, 44 px tall),
--   50 px above the health bar (bottom -126; HealthBar -76, StaminaBar -26 unchanged). Inside: HUNGER on the left
--   half, THIRST on the right half (10 px gap), each "label + current / max" over a rounded 22 px bar in the HealthBar
--   style. Hunger fill orange, Thirst fill blue; below SurvivalWarnFraction (default 0.2) the fill turns red and the
--   outline pulses red (2 Hz); at 0 the value reads STARVING / DEHYDRATED in red. A hint line above the bars shows
--   "[E] Hold to eat" / "[E] Hold to drink" while food / fresh water is in reach, "Eating..." / "Drinking..." while
--   the server runs the action. The whole HUD is hidden while SurvivalEnabled = false.
-- Input: E is bound (ContextActionService, priority High + 1 = above RamTest's E) ONLY while SurvivalCanEat or
--   SurvivalCanDrink is true (server attributes, SurvivalServer 1.0) or the key is held; otherwise unbound, so E is
--   Ram everywhere else. Key down: "eat" if SurvivalCanEat, else "drink" -> DinoSurvivalAction; key up / cancel ->
--   "stop". Touch: the binding's on-screen button (Eat / Drink). Server validates everything.
-- Values read (character attributes, SurvivalServer 1.0): Hunger, Thirst, HungerMax, ThirstMax, SurvivalWarnFraction,
--   SurvivalEnabled, SurvivalCanEat, SurvivalCanDrink, SurvivalAction.
-- Diagnostics (character attributes, this client): SurvivalBarsVersion, SurvivalBarsState ("normal" / "warning" /
--   "empty" / "disabled"), SurvivalHint (hint text shown), SurvivalInputBound, SurvivalHolding ("eat" / "drink" / "").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.0"
local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("DinoSurvivalAction", 10)

local ACTION = "DinoSurvivalEatDrink"
local KEYS = {Enum.KeyCode.E}
local PRIORITY = Enum.ContextActionPriority.High.Value + 1
local DEFAULTS = {HungerMax = 100, ThirstMax = 100, SurvivalWarnFraction = 0.2, SurvivalEnabled = true}
local PULSE_HZ = 2

local COLORS = {
	back = Color3.fromRGB(20, 20, 26),
	hungerA = Color3.fromRGB(255, 176, 66), hungerB = Color3.fromRGB(222, 128, 38),
	thirstA = Color3.fromRGB(92, 190, 255), thirstB = Color3.fromRGB(46, 138, 222),
	low = Color3.fromRGB(235, 55, 45), lowB = Color3.fromRGB(190, 35, 30),
}

char:SetAttribute("SurvivalBarsVersion", VERSION)

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local old = player:WaitForChild("PlayerGui"):FindFirstChild("SurvivalHUD")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "SurvivalHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -126) -- 50 px above the health bar (HealthBar: -76)
holder.Size = UDim2.new(0.42, 0, 0, 44)
holder.BackgroundTransparency = 1
holder.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(260, 44)
limit.MaxSize = Vector2.new(560, 44)
limit.Parent = holder

local function label(parent, name, text, pos, size, align, color)
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
	l.Parent = parent
	return l
end

local function makeBar(name, title, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Position = pos
	f.Size = UDim2.new(0.5, -5, 1, 0)
	f.Parent = holder
	label(f, "Title", title, UDim2.fromOffset(6, 0), UDim2.new(0.5, 0, 0, 18), Enum.TextXAlignment.Left)
	local value = label(f, "Value", "", UDim2.new(0.4, -6, 0, 0), UDim2.new(0.6, 0, 0, 18), Enum.TextXAlignment.Right)
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 22)
	back.BackgroundColor3 = COLORS.back
	back.BackgroundTransparency = 0.2
	back.ClipsDescendants = true
	back.Parent = f
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
	return {value = value, stroke = stroke, fill = fill, gradient = gradient}
end

local hungerBar = makeBar("Hunger", "HUNGER", UDim2.fromScale(0, 0))
local thirstBar = makeBar("Thirst", "THIRST", UDim2.new(0.5, 5, 0, 0))
local hint = label(holder, "Hint", "", UDim2.new(0, 0, 0, -22), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center)

gui.Parent = player.PlayerGui

local shown = {}
local function show(attr, v)
	if shown[attr] ~= v then
		shown[attr] = v
		char:SetAttribute(attr, v)
	end
end

-- returns "normal" / "warning" / "empty"
local function drawBar(bar, v, max, warn, colA, colB, emptyText, pulse)
	max = math.max(1, max)
	v = math.clamp(v, 0, max)
	local frac = v / max
	bar.fill.Size = UDim2.fromScale(frac, 1)
	local state = v <= 0 and "empty" or (frac < warn and "warning" or "normal")
	if state == "empty" then
		bar.value.Text = emptyText
		bar.value.TextColor3 = COLORS.low
	else
		bar.value.Text = ("%d / %d"):format(math.ceil(v), math.floor(max + 0.5))
		bar.value.TextColor3 = Color3.new(1, 1, 1)
	end
	if state == "normal" then
		bar.gradient.Color = ColorSequence.new(colA, colB)
		bar.stroke.Color = Color3.new(1, 1, 1)
		bar.stroke.Transparency = 0.55
	else
		bar.gradient.Color = ColorSequence.new(COLORS.low, COLORS.lowB)
		bar.stroke.Color = COLORS.low
		bar.stroke.Transparency = pulse
	end
	return state
end

-- input ---------------------------------------------------------------
local holding = ""
local bound = false

local function onAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		local what = char:GetAttribute("SurvivalCanEat") == true and "eat"
			or (char:GetAttribute("SurvivalCanDrink") == true and "drink" or nil)
		if not what then return Enum.ContextActionResult.Pass end
		holding = what
		if remote then remote:FireServer(what) end
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if holding == "" then return Enum.ContextActionResult.Pass end
		holding = ""
		if remote then remote:FireServer("stop") end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function applyBinding(want, title)
	if want and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, PRIORITY, table.unpack(KEYS))
		bound = true
	elseif not want and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	if bound and title then ContextActionService:SetTitle(ACTION, title) end
end

local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		applyBinding(false)
		gui:Destroy()
		return
	end
	local enabled = get("SurvivalEnabled") == true
	holder.Visible = enabled
	local canEat = char:GetAttribute("SurvivalCanEat") == true
	local canDrink = char:GetAttribute("SurvivalCanDrink") == true
	local alive = hum.Health > 0
	if holding ~= "" and (not alive or not enabled) then
		holding = ""
		if remote then remote:FireServer("stop") end
	end
	applyBinding(enabled and alive and (canEat or canDrink or holding ~= ""), canEat and "Eat" or "Drink")
	show("SurvivalInputBound", bound)
	show("SurvivalHolding", holding)
	if not enabled then
		show("SurvivalBarsState", "disabled")
		show("SurvivalHint", "")
		return
	end
	local warn = get("SurvivalWarnFraction")
	local pulse = 0.5 - 0.5 * math.cos(os.clock() * PULSE_HZ * 2 * math.pi)
	local hs = drawBar(hungerBar, char:GetAttribute("Hunger") or get("HungerMax"), get("HungerMax"), warn,
		COLORS.hungerA, COLORS.hungerB, "STARVING", pulse)
	local ts = drawBar(thirstBar, char:GetAttribute("Thirst") or get("ThirstMax"), get("ThirstMax"), warn,
		COLORS.thirstA, COLORS.thirstB, "DEHYDRATED", pulse)
	show("SurvivalBarsState", (hs == "empty" or ts == "empty") and "empty"
		or ((hs == "warning" or ts == "warning") and "warning" or "normal"))
	local action = char:GetAttribute("SurvivalAction")
	local text = ""
	if alive then
		if action == "eating" then
			text = "Eating..."
		elseif action == "drinking" then
			text = "Drinking..."
		elseif canEat then
			text = "[E] Hold to eat"
		elseif canDrink then
			text = "[E] Hold to drink"
		end
	end
	hint.Text = text
	show("SurvivalHint", text)
end)
