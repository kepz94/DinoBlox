-- RoarFX v1.1 (Dino Arcade) — sound + sound-wave rings for a roar, on every player's client.
-- Runs for every dino character (RunContext = Client). Triggered by the character attribute
-- RoarStartedAt (server time, set by RoarServer). From the burst moment (RoarPose.BURST of RoarDuration):
--   * plays the roar sound from the head (RoarSoundId attribute; placeholder until replaced)
--   * a stream of upright rings shoots out of the mouth: each starts small at the mouth opening,
--     flies forward along where the head is pointing out to RoarRadius studs, widening to
--     RoarWaveSize studs across and fading (one ring every RING_GAP s until the roar ends)
--   * a short camera shake for the local player if they are within RoarRadius
-- v1.1: rings shoot forward from the mouth (were flat circles around the whole body); ground ring removed.
-- Diagnostics (client-side character attributes): RoarFXCount, RoarRingsShot, RoarSoundLoaded.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local char = script.Parent

local DEFAULTS = {RoarDuration = 1.4, RoarRadius = 30, RoarWaveSize = 18, RoarSoundId = "", RoarShakeCamera = 0.35}
local BURST = 0.2            -- matches RoarPose.BURST (roar starts)
local BURST_END = 0.8        -- matches RoarPose (roar ends, recovery begins)
local RING_GAP = 0.14        -- seconds between rings
local RING_TIME = 0.75       -- seconds for a ring to fly out to RoarRadius
local RING_START_SIZE = 3    -- studs across at the mouth
local RING_THICKNESS = 0.7   -- studs
local RING_DEPTH = 0.5       -- studs along the flight direction
local RING_COLOR = Color3.fromRGB(255, 244, 214)

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- sound lives on the head segment so it is heard from the dino's position
local sound
local function ensureSound()
	local id = get("RoarSoundId")
	if id == "" then return nil end
	local head = char:FindFirstChild("Head")
	local anchor = head and head:FindFirstChild("Root")
	if not anchor then return nil end
	if not sound or sound.Parent ~= anchor then
		sound = Instance.new("Sound")
		sound.Name = "RoarSound"
		sound.RollOffMaxDistance = 250
		sound.Volume = 1
		sound.Parent = anchor
	end
	if sound.SoundId ~= id then sound.SoundId = id end
	return sound
end

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

-- Mouth opening + forward direction, from the mouth-interior block of the head (follows the head pose).
local function mouthFrame()
	local head = char:FindFirstChild("Head")
	local mouthPart = head and head:FindFirstChild("Head_mouth")
	if not mouthPart then return nil end
	local origin = mouthPart.CFrame * Vector3.new(mouthPart.Size.X / 2, 0, 0) -- front face of the mouth
	return origin, mouthPart.CFrame.RightVector                                -- head +X = forward
end

-- One upright ring: starts at the mouth, flies along dir to `reach` studs, widens to `size` across, fades.
local function shootRing(origin, dir, reach, size, alpha0)
	local holder = Instance.new("Part")
	holder.Name = "RoarRing"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(origin, origin + dir) -- holder's Z axis runs along the flight path
	holder.Parent = fxFolder
	local a = Instance.new("CylinderHandleAdornment")
	a.Adornee = holder
	a.CFrame = CFrame.identity -- cylinder axis = holder Z = flight direction, so the ring faces forward
	a.Height = RING_DEPTH
	a.Color3 = RING_COLOR
	a.Radius = RING_START_SIZE / 2
	a.InnerRadius = math.max(0, RING_START_SIZE / 2 - RING_THICKNESS)
	a.Transparency = alpha0
	a.ZIndex = 1
	a.Parent = holder
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / RING_TIME)
		local e = 1 - (1 - u) ^ 2 -- fast launch, eases out
		holder.CFrame = CFrame.lookAt(origin + dir * (reach * e), origin + dir * (reach * e + 1))
		local r = (RING_START_SIZE + (size - RING_START_SIZE) * e) / 2
		a.Radius = r
		a.InnerRadius = math.max(0, r - RING_THICKNESS)
		a.Transparency = alpha0 + (1 - alpha0) * u ^ 1.6
		if u >= 1 then
			conn:Disconnect()
			holder:Destroy()
		end
	end)
end

local function shakeCamera(strength, duration)
	local lp = Players.LocalPlayer
	local myChar = lp and lp.Character
	local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / duration
		if u >= 1 then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local k = strength * (1 - u)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

local fxCount = 0
local function onRoar()
	local started = char:GetAttribute("RoarStartedAt")
	if not started then return end
	local duration = get("RoarDuration")
	local wait = started + duration * BURST - workspace:GetServerTimeNow()
	if wait < -duration then return end -- stale (e.g. joined late)
	task.delay(math.max(0, wait), function()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not (hrp and mouthFrame()) then return end
		local reach, size = get("RoarRadius"), get("RoarWaveSize")
		-- stream of rings from the mouth for the loud part of the roar, each aimed where the head points now
		local endTime = started + duration * BURST_END
		local i = 0
		task.spawn(function()
			while workspace:GetServerTimeNow() < endTime and char.Parent do
				local origin, dir = mouthFrame()
				if not origin then break end
				shootRing(origin, dir, reach, size, 0.1 + 0.05 * (i % 2))
				i += 1
				task.wait(RING_GAP)
			end
			char:SetAttribute("RoarRingsShot", i)
		end)
		local s = ensureSound()
		if s then
			s:Play()
			char:SetAttribute("RoarSoundLoaded", s.IsLoaded)
		end
		-- shake the local player's camera if they are inside the radius
		local lp = Players.LocalPlayer
		local myRoot = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and (myRoot.Position - hrp.Position).Magnitude <= reach then
			shakeCamera(get("RoarShakeCamera"), 0.6)
		end
		fxCount += 1
		char:SetAttribute("RoarFXCount", fxCount)
	end)
end

char:GetAttributeChangedSignal("RoarStartedAt"):Connect(onRoar)
ensureSound()
