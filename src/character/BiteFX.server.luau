-- BiteFX v1.1 (Dino Arcade) — bite effects on every player's client (RunContext = Client).
-- Triggered by this character's server attributes (set by BiteServer):
--   BiteStartedAt -> at the contact moment (BiteWindup + BiteStrike later) the chomp sound plays
--                    (BiteSoundId; empty = silent), whether or not the bite lands
--   BiteHitAt     -> at BiteHitPos: a white flash, brick chunks flying out, a popping damage number
--                    (BiteHitDamage), a short wobble of the bitten model (BiteHitTarget, this client only),
--                    and a camera punch for the attacker's own player
-- v1.1: the wobble stops (without snapping back) as soon as the server moves the model itself, e.g. the
--   dummy tipping over at 0 health, so this client never keeps showing an old position; no wobble while
--   the target's DummyState is not "ready".
-- Diagnostics (client-side character attributes): BiteFXHits (hit effects shown), BiteSoundLoaded.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local char = script.Parent

local DEFAULTS = {BiteWindup = 0.15, BiteStrike = 0.10, BiteSoundId = ""}
local CHUNKS = 8
local CHUNK_TIME = 0.55
local NUMBER_TIME = 0.8
local FLASH_TIME = 0.12
local WOBBLE_TIME = 0.4
local WOBBLE_DEG = 7
local PUNCH_TIME = 0.18
local PUNCH_STRENGTH = 0.8
local CHUNK_COLORS = {Color3.fromRGB(245, 245, 240), Color3.fromRGB(178, 162, 120), Color3.fromRGB(110, 52, 46)}
local NUMBER_COLOR = Color3.fromRGB(255, 214, 64)

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

local function flash(pos)
	local p = fxPart("BiteFlash", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(pos))
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	animate(FLASH_TIME, function(u)
		local d = 2 + 6 * u
		p.Size = Vector3.new(d, d, d)
		p.Transparency = 0.2 + 0.8 * u
	end, function() p:Destroy() end)
end

local function chunks(pos)
	for i = 1, CHUNKS do
		local s = 0.5 + math.random() * 0.6
		local p = fxPart("BiteChunk", Vector3.new(s, s, s), CHUNK_COLORS[(i % #CHUNK_COLORS) + 1],
			CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6))
		local a = (i / CHUNKS) * 2 * math.pi + math.random() * 0.5
		local v = Vector3.new(math.cos(a) * 14, 12 + math.random() * 10, math.sin(a) * 14)
		local spin = CFrame.Angles(math.random() * 0.4, math.random() * 0.4, math.random() * 0.4)
		local start = p.CFrame
		animate(CHUNK_TIME, function(u)
			local t = u * CHUNK_TIME
			local offset = v * t + Vector3.new(0, -0.5 * 60 * t * t, 0)
			p.CFrame = CFrame.new(start.Position + offset) * start.Rotation * spin:Lerp(CFrame.identity, 1 - u)
			p.Transparency = u > 0.6 and (u - 0.6) / 0.4 or 0
		end, function() p:Destroy() end)
	end
end

local function damageNumber(pos, dmg)
	local holder = fxPart("BiteNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 3)
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
	label.TextColor3 = NUMBER_COLOR
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 10)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	animate(NUMBER_TIME, function(u)
		-- pop: 0.5 -> 1.3 -> 1.0 in the first 25%, then rise and fade
		local scale = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(scale, scale)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 4 * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end, function() holder:Destroy() end)
end

local wobbling = {}
local function wobble(model)
	if not model or wobbling[model] then return end
	local state = model:GetAttribute("DummyState")
	if state ~= nil and state ~= "ready" then return end
	wobbling[model] = true
	local home = model:GetPivot()
	local base = home * CFrame.new(0, -model:GetExtentsSize().Y / 2, 0) -- tilt about the bottom
	local axis = math.random() < 0.5 and 1 or -1
	local lastSet = home
	local aborted = false
	animate(WOBBLE_TIME, function(u)
		if aborted then return end
		-- the server moved the model (e.g. knocked over): stop here and keep the server's position
		if (model:GetPivot().Position - lastSet.Position).Magnitude > 0.01
			or model:GetPivot().UpVector:Dot(lastSet.UpVector) < 0.9999 then
			aborted = true
			return
		end
		local a = math.rad(WOBBLE_DEG) * math.sin(u * 3 * math.pi) * (1 - u) * axis
		lastSet = base * CFrame.Angles(a, 0, a * 0.5) * base:ToObjectSpace(home)
		model:PivotTo(lastSet)
	end, function()
		if not aborted then model:PivotTo(home) end
		wobbling[model] = nil
	end)
end

local function cameraPunch()
	local lp = Players.LocalPlayer
	if not (lp and lp.Character == char) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	animate(PUNCH_TIME, function(u)
		local k = PUNCH_STRENGTH * (1 - u)
		hum.CameraOffset = u >= 1 and Vector3.zero
			or Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k - 0.3 * k, 0)
	end)
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
		sound.Name = "BiteSound"
		sound.RollOffMaxDistance = 200
		sound.Volume = 1
		sound.Parent = anchor
	end
	if sound.SoundId ~= id then sound.SoundId = id end
	return sound
end

char:GetAttributeChangedSignal("BiteStartedAt"):Connect(function()
	local started = char:GetAttribute("BiteStartedAt")
	if not started then return end
	local wait = started + get("BiteWindup") + get("BiteStrike") - workspace:GetServerTimeNow()
	if wait < -0.5 then return end -- stale (e.g. joined late)
	task.delay(math.max(0, wait), function()
		local s = ensureSound()
		if s then
			s:Play()
			char:SetAttribute("BiteSoundLoaded", s.IsLoaded)
		end
	end)
end)

local hits = 0
char:GetAttributeChangedSignal("BiteHitAt"):Connect(function()
	local at = char:GetAttribute("BiteHitAt")
	local pos = char:GetAttribute("BiteHitPos")
	if not (at and pos) or workspace:GetServerTimeNow() - at > 1 then return end
	flash(pos)
	chunks(pos)
	damageNumber(pos + Vector3.new(0, 2, 0), char:GetAttribute("BiteHitDamage") or 0)
	wobble(workspace:FindFirstChild(char:GetAttribute("BiteHitTarget") or "", true))
	cameraPunch()
	hits += 1
	char:SetAttribute("BiteFXHits", hits)
end)
ensureSound()
