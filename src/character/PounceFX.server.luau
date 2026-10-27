-- PounceFX v1.0 (Dino Arcade) — pounce bite effects on every player's client (RunContext = Client).
-- Triggered by this character's server attribute PounceBiteAt (set by PounceServer 1.0 on every latch hit):
--   * chomp sound on the head: BiteSoundId (the bite chomp; empty = silent) at PounceSoundPitch (default 1.35, a
--     smaller, higher chomp) and PounceSoundVolume (default 0.7), replayed from the start on every hit;
--   * a small flash at the jaws (front of Head_mouth as this client animates it);
--   * a popping damage number (PounceHitDamage) at the jaws: the landing hit (PounceBiteAt == PounceLatchedAt) is a
--     big yellow number like a bite's, each later bite while latched a smaller, quicker orange one.
-- No chunks, wobble or camera punch (two hits a second would be too busy).
-- Diagnostics (client-side character attributes): PounceFXHits (hit effects shown), PounceFXLast ("land" /
--   "bite"), PounceSoundLoaded.
local RunService = game:GetService("RunService")
local char = script.Parent

local DEFAULTS = {BiteSoundId = "", PounceSoundPitch = 1.35, PounceSoundVolume = 0.7}
local FLASH_TIME = 0.1
local LAND = {time = 0.8, scale = 1, rise = 4, color = Color3.fromRGB(255, 214, 64)}   -- same look as a bite number
local TICK = {time = 0.55, scale = 0.65, rise = 2.5, color = Color3.fromRGB(255, 160, 60)}
local STALE = 1 -- seconds after which a hit stamp is too old to show (e.g. joined late)

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local function fxPart(name, size, color, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

-- runs fn(u) every frame for `duration` seconds (u = 0..1), then done()
local function animate(duration, fn, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / duration)
		fn(u)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end

-- front of the jaws as this client shows them
local function jawPoint()
	local head = char:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	if mouth and mouth:IsA("BasePart") then
		return mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0)
	end
	local root = head and head:FindFirstChild("Root")
	return root and root.Position or nil
end

local function flash(pos)
	local p = fxPart("PounceFlash", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 235, 225), CFrame.new(pos))
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	animate(FLASH_TIME, function(u)
		local d = 0.6 + 2 * u
		p.Size = Vector3.new(d, d, d)
		p.Transparency = 0.2 + 0.8 * u
	end, function() p:Destroy() end)
end

local function damageNumber(pos, dmg, style)
	local holder = fxPart("PounceNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6 * style.scale, 3 * style.scale)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "-" .. tostring(dmg)
	label.TextColor3 = style.color
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 10)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local side = (math.random() - 0.5) * 1.5 -- small sideways scatter so quick numbers don't stack
	animate(style.time, function(u)
		-- pop: 0.5 -> 1.3 -> 1.0 in the first 25%, then rise and fade
		local scale = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(scale, scale)
		holder.CFrame = CFrame.new(pos + Vector3.new(side * u, style.rise * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end, function() holder:Destroy() end)
end

-- chomp sound on the head
local sound
local function ensureSound()
	local id = get("BiteSoundId")
	if id == "" then return nil end
	local head = char:FindFirstChild("Head")
	local anchor = head and head:FindFirstChild("Root")
	if not anchor then return nil end
	if not sound or sound.Parent ~= anchor then
		sound = Instance.new("Sound")
		sound.Name = "PounceSound"
		sound.RollOffMaxDistance = 200
		sound.Parent = anchor
	end
	if sound.SoundId ~= id then sound.SoundId = id end
	sound.PlaybackSpeed = get("PounceSoundPitch")
	sound.Volume = get("PounceSoundVolume")
	return sound
end

local hits = 0
char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
	local at = char:GetAttribute("PounceBiteAt")
	if not at or workspace:GetServerTimeNow() - at > STALE then return end
	local landing = math.abs(at - (char:GetAttribute("PounceLatchedAt") or -1)) < 0.01
	local s = ensureSound()
	if s then
		s.TimePosition = 0
		s:Play()
		char:SetAttribute("PounceSoundLoaded", s.IsLoaded)
	end
	local pos = jawPoint()
	if pos then
		flash(pos)
		damageNumber(pos + Vector3.new(0, 1, 0), char:GetAttribute("PounceHitDamage") or 0, landing and LAND or TICK)
	end
	hits += 1
	char:SetAttribute("PounceFXHits", hits)
	char:SetAttribute("PounceFXLast", landing and "land" or "bite")
end)
ensureSound()
