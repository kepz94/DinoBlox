-- LevelUpFX v1.0 (Dino Arcade) — level-up / stage-up effect on the dino, on every player's client (RunContext Client).
-- User: "for growth leveling up we need an animation because when i was playing i was totally unaware that i leveled
--   up to level 6"; picked option C (mockup docs/mockups/levelup_options.html): an effect on the dino everyone sees +
--   the screen banner (GrowthBar 1.1) + the smooth grow (GrowthServer 1.1); sound: a level-up chime from the Creator Store.
-- Trigger: the character attributes GrowthServer sets on a level-up: GrowthLevelUpAt (server time) and, when the level
--   is a new stage, GrowthStageUpAt (the same time). A stamp older than STALE s is ignored (a client that loads the
--   character later does not replay it). Stage-up = GrowthStageUpAt equal to GrowthLevelUpAt.
-- Effect (all client-side, sized by GrowthBodyLength = L, else the model's largest extent):
--   * glow: a gold Highlight on the model, fill 0.35 -> 1 and outline 0 -> 1 transparent over GLOW_TIME (stage 1.3 s);
--   * ring: RING_PARTS neon gold segments in a circle on the ground under the dino, radius 0.15 L -> 0.8 L (stage
--     1.3 L) over RING_TIME (stage 1.3 s), fading out;
--   * light column: a neon gold cylinder from the ground, 0.3 L wide (stage 0.45 L), rising to 2 L high (stage 3.2 L)
--     in the first 35 % of COLUMN_TIME (stage 1.8 s) and fading, following the dino;
--   * sparkles: 30 (stage 60) gold sparkles out of the HumanoidRootPart, upward;
--   * sound: LevelUpSoundId (character attribute; default the Creator Store "UI - Level Up" by SodaBreadle) from the
--     HumanoidRootPart, volume 0.7 (stage 1.0, pitch 0.85), heard within 150 studs.
-- Toggle: character attribute LevelUpFXEnabled (default true). The copy in StarterCharacterScripts (template) does
--   nothing (it also runs with RunContext Client; see IdleAnimation 1.25).
-- Diagnostics (client-side character attributes): LevelUpFXVersion, LevelUpFXCount, LevelUpFXLast ("level" / "stage"),
--   LevelUpFXLastAt (server time of the stamp shown), LevelUpSoundLoaded.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local char = script.Parent
if not char:IsA("Model") then return end

local DEFAULT_SOUND = "rbxassetid://112485797063762"
local GOLD = Color3.fromRGB(255, 226, 122)
local STALE = 2
local RING_PARTS = 20
local SPEC = {
	level = {glow = 0.9, ring = 0.9, ringR = 0.8, column = 1.2, colW = 0.3, colH = 2, sparks = 30, vol = 0.7, pitch = 1},
	stage = {glow = 1.3, ring = 1.3, ringR = 1.3, column = 1.8, colW = 0.45, colH = 3.2, sparks = 60, vol = 1, pitch = 0.85},
}

char:SetAttribute("LevelUpFXVersion", VERSION)

local function bodyLength()
	local l = char:GetAttribute("GrowthBodyLength")
	if type(l) == "number" and l > 0 then return l end
	local s = char:GetExtentsSize()
	return math.max(s.X, s.Y, s.Z)
end

local function groundY(hrp)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
	if hit then return hit.Position.Y end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hrp.Position.Y - hrp.Size.Y / 2 - (hum and hum.HipHeight or 0)
end

local function fxPart(size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	return p
end

local sound
local function ensureSound(hrp)
	local id = char:GetAttribute("LevelUpSoundId")
	if type(id) ~= "string" then id = DEFAULT_SOUND end
	if id == "" then return nil end
	if not sound or sound.Parent ~= hrp then
		sound = Instance.new("Sound")
		sound.Name = "LevelUpSound"
		sound.RollOffMaxDistance = 150
		sound.Parent = hrp
	end
	if sound.SoundId ~= id then sound.SoundId = id end
	return sound
end

local function play(kind, stamp)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local sp = SPEC[kind]
	local L = bodyLength()
	local folder = Instance.new("Folder")
	folder.Name = "LevelUpFX"
	folder.Parent = workspace
	-- glow
	local hl = Instance.new("Highlight")
	hl.Name = "LevelUpGlow"
	hl.FillColor = GOLD
	hl.OutlineColor = GOLD
	hl.FillTransparency = 0.35
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = char
	hl.Parent = char
	TweenService:Create(hl, TweenInfo.new(sp.glow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FillTransparency = 1, OutlineTransparency = 1}):Play()
	-- ring segments + column
	local y0 = groundY(hrp)
	local centre = Vector3.new(hrp.Position.X, y0, hrp.Position.Z)
	local segs = {}
	local thick = math.max(0.15, 0.03 * L)
	for i = 1, RING_PARTS do
		local p = fxPart(Vector3.new(thick, thick, 1))
		p.Parent = folder
		segs[i] = p
	end
	local column = Instance.new("Part")
	column.Shape = Enum.PartType.Cylinder
	column.Anchored, column.CanCollide, column.CanQuery, column.CanTouch, column.CastShadow = true, false, false, false, false
	column.Material = Enum.Material.Neon
	column.Color = GOLD
	column.Transparency = 0.45
	column.Size = Vector3.new(0.1, sp.colW * L, sp.colW * L)
	column.Parent = folder
	-- sparkles
	local att = Instance.new("Attachment")
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(GOLD)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.12 * L), NumberSequenceKeypoint.new(1, 0)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	pe.Lifetime = NumberRange.new(0.8, 1.2)
	pe.Speed = NumberRange.new(0.4 * L, 0.8 * L)
	pe.SpreadAngle = Vector2.new(50, 50)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, -0.2 * L, 0)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(sp.sparks)
	-- sound
	local s = ensureSound(hrp)
	if s then
		s.Volume = sp.vol
		s.PlaybackSpeed = sp.pitch
		s.TimePosition = 0
		s:Play()
		task.delay(1, function()
			if s.Parent then char:SetAttribute("LevelUpSoundLoaded", s.IsLoaded) end
		end)
	end
	-- animate ring + column
	local t0 = os.clock()
	local total = math.max(sp.ring, sp.column)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= total or not char.Parent then
			conn:Disconnect()
			folder:Destroy()
			if hl.Parent then hl:Destroy() end
			task.delay(1.3, function() att:Destroy() end)
			return
		end
		-- ring
		local a = math.min(1, t / sp.ring)
		local e = 1 - (1 - a) ^ 2
		local r = L * (0.15 + (sp.ringR - 0.15) * e)
		local segLen = 2 * math.pi * r / RING_PARTS * 0.7
		for i, p in ipairs(segs) do
			local ang = (i - 1) / RING_PARTS * 2 * math.pi
			local pos = centre + Vector3.new(math.cos(ang) * r, thick / 2 + 0.05, math.sin(ang) * r)
			p.Size = Vector3.new(thick, thick, math.max(0.05, segLen))
			p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(ang), 0, math.cos(ang)))
			p.Transparency = a >= 1 and 1 or 0.1 + 0.9 * a
		end
		-- column: grows in the first 35 %, fades over the whole time, follows the dino
		local c = math.min(1, t / sp.column)
		local h = sp.colH * L * math.min(1, c / 0.35)
		local root = hrp.Parent and hrp.Position or centre
		column.Size = Vector3.new(math.max(0.1, h), sp.colW * L, sp.colW * L)
		column.CFrame = CFrame.new(root.X, y0 + h / 2, root.Z) * CFrame.Angles(0, 0, math.rad(90))
		column.Transparency = 0.45 + 0.55 * c
	end)
	local n = (char:GetAttribute("LevelUpFXCount") or 0) + 1
	char:SetAttribute("LevelUpFXCount", n)
	char:SetAttribute("LevelUpFXLast", kind)
	char:SetAttribute("LevelUpFXLastAt", stamp)
end

local handled = char:GetAttribute("GrowthLevelUpAt") -- a stamp already there when this client loads is old
local pending = false
local function check()
	if pending then return end
	pending = true
	task.delay(0.05, function() -- both stamps of one stage-up arrive together; read them once
		pending = false
		if char:GetAttribute("LevelUpFXEnabled") == false then return end
		local lv = char:GetAttribute("GrowthLevelUpAt")
		if type(lv) ~= "number" or lv == handled then return end
		handled = lv
		if math.abs(workspace:GetServerTimeNow() - lv) > STALE then return end
		local kind = char:GetAttribute("GrowthStageUpAt") == lv and "stage" or "level"
		play(kind, lv)
	end)
end
char:GetAttributeChangedSignal("GrowthLevelUpAt"):Connect(check)
char:GetAttributeChangedSignal("GrowthStageUpAt"):Connect(check)
local hrp0 = char:FindFirstChild("HumanoidRootPart")
if hrp0 then ensureSound(hrp0) end
