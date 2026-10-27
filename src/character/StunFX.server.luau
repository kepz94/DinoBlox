-- StunFX v1.0 (Dino Arcade) — dizzy stars over a stunned dino's head, on every player's client (RunContext = Client).
-- Cloned into bots by BotServer 1.3 (like PounceFX). While this character's StunnedUntil (server time, set by
-- ShakeOffServer 1.1 on a tree ram) is in the future: STAR_COUNT yellow stars circle above the head (the Head model's
-- Root part; radius / height from the head's size), REV_PER_SEC turns a second, bobbing a little, in a flat world
-- circle (the dino itself lies on its side). They fade out over FADE_TIME s when the stun ends.
-- Diagnostics (client-side character attributes): StunFXState ("none" / "stars" / "fading"), StunFXShown (stuns shown).
local RunService = game:GetService("RunService")
local char = script.Parent

local STAR_COUNT = 3
local REV_PER_SEC = 1.1
local FADE_TIME = 0.3
local STAR_COLOR = Color3.fromRGB(255, 226, 70)

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local shown = {}
local function show(k, v)
	if shown[k] ~= v then
		shown[k] = v
		char:SetAttribute(k, v)
	end
end

local stars = {}
local function makeStars(size)
	for i = 1, STAR_COUNT do
		local p = Instance.new("Part")
		p.Name = "StunStar"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(size, 0, size, 0)
		gui.LightInfluence = 0
		gui.Adornee = p
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "★"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = STAR_COLOR
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(120, 80, 0)
		label.Parent = gui
		gui.Parent = p
		p.Parent = fxFolder
		stars[i] = {part = p, label = label}
	end
end

local function clearStars()
	for _, s in ipairs(stars) do s.part:Destroy() end
	stars = {}
end

local state, fadeAt = "none", nil
local function headFrame()
	local head = char:FindFirstChild("Head")
	if not head then return nil end
	local root = head:IsA("BasePart") and head or head:FindFirstChild("Root")
	if not root then return nil end
	local size = head:IsA("Model") and head:GetExtentsSize() or root.Size
	return root.Position, size
end

local conn = RunService.RenderStepped:Connect(function()
	local untilT = char:GetAttribute("StunnedUntil")
	local stunned = typeof(untilT) == "number" and untilT > workspace:GetServerTimeNow()
	local pos, size = headFrame()
	if stunned and pos then
		if state ~= "stars" then
			if #stars == 0 then
				makeStars(math.clamp(size.Magnitude * 0.35, 0.9, 2.2))
				show("StunFXShown", (char:GetAttribute("StunFXShown") or 0) + 1)
			end
			state = "stars"
		end
	elseif state == "stars" then
		state, fadeAt = "fading", os.clock()
	end
	if state == "none" then
		show("StunFXState", "none")
		return
	end
	local alpha = 0
	if state == "fading" then
		alpha = math.min(1, (os.clock() - fadeAt) / FADE_TIME)
		if alpha >= 1 or not pos then
			clearStars()
			state = "none"
			show("StunFXState", "none")
			return
		end
	end
	local radius = math.max(0.9, math.max(size.X, size.Z) * 0.55)
	local height = size.Y * 0.5 + 0.8
	local t = os.clock()
	for i, s in ipairs(stars) do
		local a = t * REV_PER_SEC * 2 * math.pi + (i - 1) * 2 * math.pi / STAR_COUNT
		local bob = math.sin(t * 6 + i) * 0.15
		s.part.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * radius, height + bob, math.sin(a) * radius))
		s.label.TextTransparency = alpha
		s.label.TextStrokeTransparency = 0.2 + 0.8 * alpha
	end
	show("StunFXState", state)
end)

local function cleanup()
	conn:Disconnect()
	clearStars()
end
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then hum.Died:Connect(cleanup) end
