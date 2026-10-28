-- GoalTracker v1.0 (Dino Arcade) — the goal list on the right side of the screen + "GOAL DONE!" pop (LocalScript).
-- DINO-21, plan docs/plans/GOALS_v1.0.md Task 4, approved prototype docs/mockups/goals_options.html (option A), ADR-003.
-- Reads only the player attributes GoalServer 1.0 publishes (GoalState, GoalStageName, Goal<i>Id / Text / Have / Need / Xp /
--   Size / Done / DoneAt, GoalLastDone, GoalLastDoneAt); writes nothing the server reads.
-- Layout (plan + red-team answer: below Roblox's player list):
--   holder AnchorPoint (1, 0), Position (1, -16, 0.30, 0), width 260 (200 when the viewport is narrower than 900).
--   Header 20 px: "GOALS" (FredokaOne 15, white) left, stage name (13, rgb(159,176,166)) right.
--   3 rows, 46 px, 6 px apart: back rgb(20,20,26) at 0.2, 10 px corners, white 2 px stroke at 0.55.
--     line 1: goal text left (FredokaOne, up to 13, shrinks to 9 to fit), "+n XP" right (13; purple rgb(196,140,255),
--             big goals yellow rgb(255,210,60));
--     line 2: "have / need" (12; hide goal "have / need s");
--     strip 5 px: white track at 0.85, gold fill rgb(255,226,122), width have / need.
--   Done: stroke gold rgb(255,226,122) 3 px, "✓ " + text in gold. New goal in a slot: slides in from +20 px, fading in
--   over SLIDE_TIME 0.3 s.
-- Pop: GoalLastDoneAt newer than the last one shown and at most POP_FRESH 2 s old: "GOAL DONE!" (FredokaOne 40, gold,
--   purple stroke rgb(74,42,138) 2 px) + "<text> · +n XP" (18, white), centred at 20% from the top (the level-up banner
--   is at 34%); pop 0.3 -> 1.1 (first 15%) -> 1 (to 25%), fade the last 20% of POP_TIME 1.8 s.
--   Character attribute GoalPopEnabled = false: no pop.
-- Hidden when GoalState is missing or "disabled"; rows without a goal are hidden.
-- Diagnostics (this client, character): GoalTrackerVersion, GoalTrackerState ("shown" / "hidden"), GoalPopShownAt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local char = script.Parent
if not char:IsA("Model") then return end
local player = Players.LocalPlayer
local SLOTS = 3
local SLIDE_TIME, POP_TIME, POP_FRESH = 0.3, 1.8, 2
local ROW_H, GAP, HEAD_H = 46, 6, 20
local C = {
	back = Color3.fromRGB(20, 20, 26),
	muted = Color3.fromRGB(159, 176, 166),
	xp = Color3.fromRGB(196, 140, 255),
	big = Color3.fromRGB(255, 210, 60),
	gold = Color3.fromRGB(255, 226, 122),
	stroke = Color3.fromRGB(74, 42, 138),
}

char:SetAttribute("GoalTrackerVersion", VERSION)

local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("GoalTracker")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "GoalTracker"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local function label(parent, name, text, pos, size, align, color, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = textSize or 13
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -16, 0.30, 0)
holder.Size = UDim2.fromOffset(260, HEAD_H + SLOTS * (ROW_H + GAP))
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui

local head = Instance.new("Frame")
head.Name = "Header"
head.BackgroundTransparency = 1
head.Size = UDim2.new(1, 0, 0, HEAD_H)
head.Parent = holder
label(head, "Title", "GOALS", UDim2.fromOffset(4, 0), UDim2.new(0.5, -4, 1, 0), Enum.TextXAlignment.Left, nil, 15)
local stageLabel = label(head, "Stage", "", UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -4, 1, 0), Enum.TextXAlignment.Right, C.muted, 13)

local rows = {}
for i = 1, SLOTS do
	local y = HEAD_H + GAP + (i - 1) * (ROW_H + GAP)
	local f = Instance.new("Frame")
	f.Name = "Goal" .. i
	f.Position = UDim2.fromOffset(0, y)
	f.Size = UDim2.new(1, 0, 0, ROW_H)
	f.BackgroundColor3 = C.back
	f.BackgroundTransparency = 0.2
	f.Visible = false
	f.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.55
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local text = label(f, "Text", "", UDim2.fromOffset(8, 3), UDim2.new(1, -66, 0, 18), Enum.TextXAlignment.Left, nil, 13)
	text.TextScaled = true
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 13
	tc.MinTextSize = 9
	tc.Parent = text
	local xp = label(f, "Xp", "", UDim2.new(1, -60, 0, 3), UDim2.fromOffset(52, 18), Enum.TextXAlignment.Right, C.xp, 13)
	local count = label(f, "Count", "", UDim2.fromOffset(8, 21), UDim2.new(1, -16, 0, 14), Enum.TextXAlignment.Left, nil, 12)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 8, 1, -9)
	track.Size = UDim2.new(1, -16, 0, 5)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.85
	track.BorderSizePixel = 0
	track.Parent = f
	local tcorner = Instance.new("UICorner")
	tcorner.CornerRadius = UDim.new(0, 3)
	tcorner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.gold
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fcorner = tcorner:Clone()
	fcorner.Parent = fill
	rows[i] = {frame = f, y = y, stroke = stroke, text = text, xp = xp, count = count, fill = fill, id = nil, slideAt = nil}
end

-- pop
local pop = Instance.new("Frame")
pop.Name = "Pop"
pop.AnchorPoint = Vector2.new(0.5, 0.5)
pop.Position = UDim2.fromScale(0.5, 0.20)
pop.Size = UDim2.new(0.9, 0, 0, 68)
pop.BackgroundTransparency = 1
pop.Visible = false
pop.Parent = gui
local popScale = Instance.new("UIScale")
popScale.Parent = pop
local popTitle = label(pop, "Title", "GOAL DONE!", UDim2.new(), UDim2.new(1, 0, 0, 44), Enum.TextXAlignment.Center, C.gold, 40)
popTitle.TextStrokeTransparency = 1
local popStroke = Instance.new("UIStroke")
popStroke.Color = C.stroke
popStroke.Thickness = 2
popStroke.Parent = popTitle
local popLine = label(pop, "Line", "", UDim2.fromOffset(0, 46), UDim2.new(1, 0, 0, 22), Enum.TextXAlignment.Center, nil, 18)
popLine.TextStrokeTransparency = 0.3

gui.Parent = pg

local shownState
local function showState(v)
	if shownState ~= v then
		shownState = v
		char:SetAttribute("GoalTrackerState", v)
	end
end

local popAt
local lastPopSeen = player:GetAttribute("GoalLastDoneAt") -- a goal finished before this spawn is not popped again

local function refresh()
	local state = player:GetAttribute("GoalState")
	local visible = state ~= nil and state ~= "disabled"
	holder.Visible = visible
	showState(visible and "shown" or "hidden")
	if not visible then return end
	local cam = workspace.CurrentCamera
	local w = (cam and cam.ViewportSize.X < 900) and 200 or 260
	if holder.Size.X.Offset ~= w then holder.Size = UDim2.fromOffset(w, HEAD_H + SLOTS * (ROW_H + GAP)) end
	stageLabel.Text = player:GetAttribute("GoalStageName") or ""
	for i, r in ipairs(rows) do
		local p = "Goal" .. i
		local id = player:GetAttribute(p .. "Id")
		if not id then
			r.frame.Visible = false
			r.id = nil
		else
			if r.id ~= nil and r.id ~= id then r.slideAt = os.clock() end -- a new goal took this slot
			r.id = id
			r.frame.Visible = true
			local done = player:GetAttribute(p .. "Done") == true
			local have = player:GetAttribute(p .. "Have") or 0
			local need = math.max(1, player:GetAttribute(p .. "Need") or 1)
			r.text.Text = (done and "✓ " or "") .. (player:GetAttribute(p .. "Text") or "")
			r.text.TextColor3 = done and C.gold or Color3.new(1, 1, 1)
			r.xp.Text = ("+%d XP"):format(player:GetAttribute(p .. "Xp") or 0)
			r.xp.TextColor3 = player:GetAttribute(p .. "Size") == "b" and C.big or C.xp
			r.count.Text = ("%d / %d%s"):format(have, need, id == "h_hide" and " s" or "")
			r.fill.Size = UDim2.fromScale(math.clamp(have / need, 0, 1), 1)
			r.stroke.Color = done and C.gold or Color3.new(1, 1, 1)
			r.stroke.Transparency = done and 0 or 0.55
			r.stroke.Thickness = done and 3 or 2
		end
	end
	local at = player:GetAttribute("GoalLastDoneAt")
	if type(at) == "number" and at ~= lastPopSeen then
		lastPopSeen = at
		if math.abs(workspace:GetServerTimeNow() - at) <= POP_FRESH and char:GetAttribute("GoalPopEnabled") ~= false then
			local text, xp = tostring(player:GetAttribute("GoalLastDone") or ""):match("^(.*) %+(%d+)$")
			popLine.Text = text and ("%s · +%s XP"):format(text, xp) or ""
			popAt = os.clock()
			char:SetAttribute("GoalPopShownAt", at)
		end
	end
end

player.AttributeChanged:Connect(function(name)
	if name:sub(1, 4) == "Goal" then refresh() end
end)
refresh()

local function easeOut(t) return 1 - (1 - t) ^ 3 end
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, r in ipairs(rows) do
		if r.slideAt then
			local t = math.clamp((now - r.slideAt) / SLIDE_TIME, 0, 1)
			local e = easeOut(t)
			r.frame.Position = UDim2.fromOffset(20 * (1 - e), r.y)
			r.frame.BackgroundTransparency = 0.2 + 0.8 * (1 - e)
			for _, l in ipairs({r.text, r.xp, r.count}) do l.TextTransparency = 1 - e end
			if t >= 1 then
				r.slideAt = nil
				r.frame.Position = UDim2.fromOffset(0, r.y)
			end
		end
	end
	if popAt then
		local t = (now - popAt) / POP_TIME
		if t >= 1 then
			pop.Visible = false
			popAt = nil
		else
			pop.Visible = true
			local s
			if t < 0.15 then s = 0.3 + (1.1 - 0.3) * (t / 0.15)
			elseif t < 0.25 then s = 1.1 - 0.1 * ((t - 0.15) / 0.1)
			else s = 1 end
			popScale.Scale = s
			local fade = t > 0.8 and (t - 0.8) / 0.2 or 0
			popTitle.TextTransparency = fade
			popStroke.Transparency = fade
			popLine.TextTransparency = fade
			popLine.TextStrokeTransparency = 0.3 + 0.7 * fade
		end
	end
end)
