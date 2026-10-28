-- GrowthBar v1.1 (Dino Arcade) — the player's growth bar + level-up / stage-up / death-drop messages (LocalScript).
-- DINO-8, plan docs/plans/GROWTH_v1.0.md Task 4, approved prototype docs/mockups/growth_options.html (option C).
-- Reads only the character / player attributes GrowthServer 1.0 publishes; writes nothing the server reads.
-- Layout: same holder as HealthBar / SurvivalBars (0.42 width, 260-560 px, 44 px tall, FredokaOne 16, dark back
--   rgb(20,20,26) at 0.2, 11 px corners, white 2 px stroke at 0.55). Position UDim2.new(0.5, 0, 1, -198): the plan's
--   -176 (50 px above SurvivalBars at -126) would sit on SurvivalBars' "[E] Hold to eat / drink" hint, which is drawn
--   22 px above its holder (-192 ... -174 px from the bottom); -198 keeps 6 px clear of it (plan acceptance: no overlap).
--   Left: "LV {GrowthLevel} · {STAGE NAME}"; right: "{xp} / {next} XP" (or "MAX") + chip "{n} skill pt(s)".
--   Fill: purple gradient rgb(196,140,255) -> rgb(140,90,230), width = GrowthXP / GrowthXPNext (full at MAX).
-- Messages centred at 14% from the top (title 36, line 18):
--   * level-up (GrowthLevelUpAt changes): "Level n" purple + "+k skill point(s)", 1.8 s
--   * stage-up (GrowthStageUpAt changes; wins over level-up): "You grew into a juvenile!" yellow rgb(255,210,60) +
--     "Bigger body · {MaxHealth} max health · bite {BiteDamage}", 2.5 s
--   * death drop (player GrowthDeathDropAt newer than the last one shown, within DROP_WINDOW s, on the new spawn):
--     "Dropped to Lv n · {stage}" red rgb(255,80,60) + the GrowthDeathDrop text ("Lv a -> Lv b"), 2.5 s
-- Hidden while GrowthState ~= "ready" (growth off, waiting for the base values).
-- Compact text: when the full-size row (title 16 + value 16 + chip 13, measured with TextService) is wider than the
--   holder minus 12 px (narrow screens; worst case "LV 15 · SUB-ADULT" + "289 / 295 XP" + "19 skill pts" = 301 px vs the
--   260 px minimum), title / value drop to 13 and the chip to 11 (worst case at 260 px: ~8 px between title and value).
-- Diagnostics (this client): character GrowthBarState ("hidden" / "shown"), GrowthBarMessage, GrowthBarMessageAt,
--   GrowthBarVersion, GrowthBarCompact; player GrowthBarDropShownAt (the death drop already announced, so a respawn shows it once).
-- v1.1 (user: "when i was playing i was totally unaware that i leveled up to level 6"; picked option C of
--   docs/mockups/levelup_options.html; LevelUpFX 1.0 does the effect on the dino):
--   * banner instead of the small level / stage line: centred at 34 % from the top, FredokaOne, title 64 with a purple
--     stroke rgb(74,42,138) 3 px, line 22 white. Level-up: "LEVEL UP!" gold rgb(255,226,122) + "LV n · +k skill
--     point(s) · {MaxHealth} max health", BANNER_TIME 1.9 s. Stage-up: "{STAGE}!" yellow rgb(255,210,60) + "Bigger body ·
--     {MaxHealth} max health · bite {BiteDamage}", BANNER_STAGE_TIME 2.6 s. Motion: pop 0.2 -> 1.12 (first 15 %) -> 1
--     (to 25 %), hold, then fade and rise (last 20 %).
--   * the growth bar bursts: its outline turns gold and glows back to white over BURST_TIME 1.2 s; the "LV n" text and
--     the skill-point chip pop to 1.45x their size and back (0.9 s).
--   * stage-up only: a gold flash on the four screen edges (EDGE 90 px deep, fades over 1.1 s).
--   * death-drop message unchanged (small red line). Character attribute GrowthBarBanner = false: v1.0 messages.
--   Diagnostics: GrowthBarBannerShown ("level" / "stage"), GrowthBarBannerAt (server time); GrowthBarMessage as v1.0.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local VERSION = "1.1"
local char = script.Parent
local player = Players.LocalPlayer
local LEVEL_TIME = 1.8
local STAGE_TIME = 2.5
local DROP_TIME = 2.5
local DROP_WINDOW = 30

local COLORS = {
	back = Color3.fromRGB(20, 20, 26),
	fillA = Color3.fromRGB(196, 140, 255), fillB = Color3.fromRGB(140, 90, 230),
	stage = Color3.fromRGB(255, 210, 60),
	drop = Color3.fromRGB(255, 80, 60),
}

char:SetAttribute("GrowthBarVersion", VERSION)

local old = player:WaitForChild("PlayerGui"):FindFirstChild("GrowthHUD")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "GrowthHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -198) -- above SurvivalBars (-126) and its hint row (-192 ... -174)
holder.Size = UDim2.new(0.42, 0, 0, 44)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(260, 44)
limit.MaxSize = Vector2.new(560, 44)
limit.Parent = holder

local function label(parent, name, text, pos, size, align, color, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = textSize or 16
	l.TextXAlignment = align
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Parent = parent
	return l
end
local title = label(holder, "Title", "", UDim2.fromOffset(6, 0), UDim2.new(0.5, 0, 0, 18), Enum.TextXAlignment.Left)

-- right side: value text + skill-point chip, laid out right to left
local right = Instance.new("Frame")
right.Name = "Right"
right.BackgroundTransparency = 1
right.Position = UDim2.new(0.5, 0, 0, 0)
right.Size = UDim2.new(0.5, -6, 0, 18)
right.Parent = holder
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = right
local value = label(right, "Value", "", UDim2.new(), UDim2.fromOffset(0, 18), Enum.TextXAlignment.Right)
value.AutomaticSize = Enum.AutomaticSize.X
value.LayoutOrder = 1
local chip = Instance.new("TextLabel")
chip.Name = "SkillPoints"
chip.LayoutOrder = 2
chip.AutomaticSize = Enum.AutomaticSize.X
chip.Size = UDim2.fromOffset(0, 16)
chip.BackgroundColor3 = COLORS.back
chip.BackgroundTransparency = 0.2
chip.Font = Enum.Font.FredokaOne
chip.TextSize = 13
chip.TextColor3 = Color3.new(1, 1, 1)
chip.TextStrokeTransparency = 0.6
chip.Text = ""
chip.Parent = right
local chipPad = Instance.new("UIPadding")
chipPad.PaddingLeft = UDim.new(0, 7)
chipPad.PaddingRight = UDim.new(0, 7)
chipPad.Parent = chip
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0, 9)
chipCorner.Parent = chip
local chipStroke = Instance.new("UIStroke")
chipStroke.Color = Color3.new(1, 1, 1)
chipStroke.Transparency = 0.55
chipStroke.Thickness = 2
chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
chipStroke.Parent = chip

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
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = back
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 11)
fillCorner.Parent = fill
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(COLORS.fillA, COLORS.fillB)
gradient.Parent = fill

-- message (toast)
local toast = Instance.new("Frame")
toast.Name = "Message"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.14)
toast.Size = UDim2.new(0.8, 0, 0, 64)
toast.BackgroundTransparency = 1
toast.Visible = false
toast.Parent = gui
local toastTitle = label(toast, "Title", "", UDim2.new(), UDim2.new(1, 0, 0, 40), Enum.TextXAlignment.Center, COLORS.fillA, 36)
toastTitle.TextStrokeTransparency = 0.2
local toastLine = label(toast, "Line", "", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 22), Enum.TextXAlignment.Center, nil, 18)
toastLine.TextStrokeTransparency = 0.3

-- v1.1: banner, edge flash, bar burst
local BANNER_TIME, BANNER_STAGE_TIME, BURST_TIME, POP_TIME, EDGE_TIME, EDGE = 1.9, 2.6, 1.2, 0.9, 1.1, 90
local GOLD = Color3.fromRGB(255, 226, 122)
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.34)
banner.Size = UDim2.new(0.9, 0, 0, 104)
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local bannerTitle = label(banner, "Title", "", UDim2.new(), UDim2.new(1, 0, 0, 70), Enum.TextXAlignment.Center, GOLD, 64)
bannerTitle.TextStrokeTransparency = 1
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(74, 42, 138)
bannerStroke.Thickness = 3
bannerStroke.Parent = bannerTitle
local bannerLine = label(banner, "Line", "", UDim2.fromOffset(0, 74), UDim2.new(1, 0, 0, 26), Enum.TextXAlignment.Center, nil, 22)
bannerLine.TextStrokeTransparency = 0.3
local edges = {}
for _, e in ipairs({
	{UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, EDGE), 90},
	{UDim2.new(0, 0, 1, -EDGE), UDim2.new(1, 0, 0, EDGE), -90},
	{UDim2.new(0, 0, 0, 0), UDim2.new(0, EDGE, 1, 0), 0},
	{UDim2.new(1, -EDGE, 0, 0), UDim2.new(0, EDGE, 1, 0), 180},
}) do
	local f = Instance.new("Frame")
	f.Name = "EdgeFlash"
	f.Position, f.Size = e[1], e[2]
	f.BackgroundColor3 = GOLD
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = e[3]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	table.insert(edges, f)
end
local fx = {bannerAt = nil, bannerDur = 0, burstAt = nil, edgeAt = nil}

gui.Parent = player.PlayerGui

local shown = {}
local function show(attr, v)
	if shown[attr] ~= v then
		shown[attr] = v
		char:SetAttribute(attr, v)
	end
end

local toastUntil = 0
local function message(text, line, color, time)
	toastTitle.Text = text
	toastTitle.TextColor3 = color
	toastLine.Text = line
	toast.Visible = true
	toastUntil = os.clock() + time
	char:SetAttribute("GrowthBarMessage", text .. " | " .. line)
	char:SetAttribute("GrowthBarMessageAt", workspace:GetServerTimeNow())
end

local BIG = Vector2.new(2000, 100)
local function textWidth(text, size)
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, BIG).X
end
local function fitRow()
	local need = 6 + textWidth(title.Text, 16) + 12 + textWidth(value.Text, 16) + 6 + textWidth(chip.Text, 13) + 14 + 6
	local compact = need > holder.AbsoluteSize.X
	title.TextSize = compact and 13 or 16
	value.TextSize = compact and 13 or 16
	chip.TextSize = compact and 11 or 13
	chip.Size = UDim2.fromOffset(0, compact and 14 or 16)
	show("GrowthBarCompact", compact)
end

local function article(word)
	return word:match("^[AEIOUaeiou]") and "an" or "a"
end

-- v1.1
local function showBanner(kind, text, line, color)
	bannerTitle.Text = text
	bannerTitle.TextColor3 = color
	bannerLine.Text = line
	fx.bannerAt = os.clock()
	fx.bannerDur = kind == "stage" and BANNER_STAGE_TIME or BANNER_TIME
	fx.burstAt = os.clock()
	if kind == "stage" then fx.edgeAt = os.clock() end
	toast.Visible = false
	char:SetAttribute("GrowthBarMessage", text .. " | " .. line)
	char:SetAttribute("GrowthBarMessageAt", workspace:GetServerTimeNow())
	char:SetAttribute("GrowthBarBannerShown", kind)
	char:SetAttribute("GrowthBarBannerAt", workspace:GetServerTimeNow())
end
local function stepFx()
	local now = os.clock()
	-- banner
	local t = fx.bannerAt and (now - fx.bannerAt) / fx.bannerDur
	if t and t < 1 then
		banner.Visible = true
		local sc, tr, rise = 1, 0, 0
		if t < 0.15 then
			local a = t / 0.15
			sc, tr = 0.2 + 0.92 * a, 1 - a
		elseif t < 0.25 then
			sc = 1.12 - 0.12 * (t - 0.15) / 0.1
		elseif t > 0.8 then
			local a = (t - 0.8) / 0.2
			tr, rise = a, a
		end
		bannerScale.Scale = sc
		bannerTitle.TextTransparency = tr
		bannerStroke.Transparency = tr
		bannerLine.TextTransparency = tr
		bannerLine.TextStrokeTransparency = 0.3 + 0.7 * tr
		banner.Position = UDim2.new(0.5, 0, 0.34 - 0.04 * rise, 0)
	else
		banner.Visible = false
		fx.bannerAt = nil
	end
	-- bar burst
	local b = fx.burstAt and (now - fx.burstAt)
	if b and b < BURST_TIME then
		local a = math.clamp((b / BURST_TIME - 0.3) / 0.7, 0, 1)
		stroke.Color = GOLD:Lerp(Color3.new(1, 1, 1), a)
		stroke.Transparency = 0.55 * a
		stroke.Thickness = 4 - 2 * a
	elseif fx.burstAt then
		fx.burstAt = nil
		stroke.Color, stroke.Transparency, stroke.Thickness = Color3.new(1, 1, 1), 0.55, 2
	end
	local pop = 1
	if b and b < POP_TIME then
		local a = b / POP_TIME
		pop = a < 0.3 and 1 + 0.45 * a / 0.3 or 1.45 - 0.45 * (a - 0.3) / 0.7
	end
	title.TextSize = math.floor(title.TextSize * pop + 0.5)
	chip.TextSize = math.floor(chip.TextSize * pop + 0.5)
	-- edge flash
	local e = fx.edgeAt and (now - fx.edgeAt) / EDGE_TIME
	for _, f in ipairs(edges) do
		f.BackgroundTransparency = (e and e < 1) and (0.25 + 0.75 * e) or 1
	end
	if e and e >= 1 then fx.edgeAt = nil end
end

local lastLevelUpAt = char:GetAttribute("GrowthLevelUpAt")
local lastStageUpAt = char:GetAttribute("GrowthStageUpAt")
local lastLevel = nil
local dropChecked = false

local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		gui:Destroy()
		return
	end
	local ready = char:GetAttribute("GrowthState") == "ready"
	holder.Visible = ready
	show("GrowthBarState", ready and "shown" or "hidden")
	if toast.Visible and os.clock() >= toastUntil then toast.Visible = false end
	if not ready then
		toast.Visible = false
		banner.Visible = false -- v1.1
		fx.bannerAt, fx.edgeAt = nil, nil
		for _, f in ipairs(edges) do f.BackgroundTransparency = 1 end
		return
	end

	local level = char:GetAttribute("GrowthLevel") or 1
	local stageName = tostring(char:GetAttribute("GrowthStageName") or "")
	local xp = char:GetAttribute("GrowthXP") or 0
	local nextXp = char:GetAttribute("GrowthXPNext") or 0
	local points = char:GetAttribute("GrowthSkillPoints") or 0
	title.Text = ("LV %d · %s"):format(level, stageName:upper())
	if nextXp > 0 then
		value.Text = ("%d / %d XP"):format(math.floor(xp), nextXp)
		fill.Size = UDim2.fromScale(math.clamp(xp / nextXp, 0, 1), 1)
	else
		value.Text = "MAX"
		fill.Size = UDim2.fromScale(1, 1)
	end
	chip.Text = ("%d skill pt%s"):format(points, points == 1 and "" or "s")
	fitRow()
	stepFx() -- v1.1 (after fitRow: the pop scales the fitted text size)

	-- death drop: once, on the first ready frame of the new character
	if not dropChecked then
		dropChecked = true
		local at = player:GetAttribute("GrowthDeathDropAt")
		if type(at) == "number" and at ~= player:GetAttribute("GrowthBarDropShownAt")
			and workspace:GetServerTimeNow() - at < DROP_WINDOW then
			player:SetAttribute("GrowthBarDropShownAt", at)
			message(("Dropped to Lv %d · %s"):format(level, stageName:lower()), tostring(player:GetAttribute("GrowthDeathDrop") or ""), COLORS.drop, DROP_TIME)
		end
	end

	local stageUpAt = char:GetAttribute("GrowthStageUpAt")
	local levelUpAt = char:GetAttribute("GrowthLevelUpAt")
	if stageUpAt ~= nil and stageUpAt ~= lastStageUpAt then
		lastStageUpAt = stageUpAt
		lastLevelUpAt = levelUpAt
		local name = stageName:lower()
		if char:GetAttribute("GrowthBarBanner") ~= false then -- v1.1
			showBanner("stage", stageName:upper() .. "!",
				("Bigger body · %d max health · bite %d"):format(math.floor(char.Humanoid.MaxHealth + 0.5), char:GetAttribute("BiteDamage") or 0),
				COLORS.stage)
		else
		message(("You grew into %s %s!"):format(article(name), name),
			("Bigger body · %d max health · bite %d"):format(math.floor(char.Humanoid.MaxHealth + 0.5), char:GetAttribute("BiteDamage") or 0),
			COLORS.stage, STAGE_TIME)
		end
	elseif levelUpAt ~= nil and levelUpAt ~= lastLevelUpAt then
		lastLevelUpAt = levelUpAt
		local gained = lastLevel and math.max(1, level - lastLevel) or 1
		if char:GetAttribute("GrowthBarBanner") ~= false then -- v1.1
			showBanner("level", "LEVEL UP!", ("LV %d · +%d skill point%s · %d max health"):format(level, gained, gained == 1 and "" or "s",
				math.floor(char.Humanoid.MaxHealth + 0.5)), GOLD)
		else
		message(("Level %d"):format(level), ("+%d skill point%s"):format(gained, gained == 1 and "" or "s"), COLORS.fillA, LEVEL_TIME)
		end
	end
	lastLevel = level
end)
