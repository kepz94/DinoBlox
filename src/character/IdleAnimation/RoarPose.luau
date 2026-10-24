-- RoarPose v1.0 (Dino Arcade) — upper-body roar layered on top of idle / walk / run.
-- Pure function: roar progress f (0..1 over RoarDuration) -> per-joint offsets, multiplied onto the
-- current pose. Only neck, head, jaw, arms and the first tail segments move, so the legs keep
-- walking (the slowed-roar design); the body root is untouched so planted feet stay planted.
-- Beats: wind-up 0-20% (head rears back) -> roar 20-80% (head thrusts forward, jaw wide, shake)
--        -> recovery 80-100%.
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front),
-- about Y = yaw.

local RoarPose = {}

RoarPose.Version = "1.0"
RoarPose.Defaults = {
	RoarEnabled    = true,
	RoarDuration   = 1.4,  -- seconds, whole roar
	RoarJawOpen    = 40,   -- degrees the jaw opens at full roar
	RoarShake      = 2.5,  -- degrees of head shake during the roar
	RoarCooldown   = 3,    -- seconds between roars (checked by RoarServer)
	RoarRadius     = 30,   -- studs the sound-wave rings reach (RoarFX)
}

RoarPose.BURST = 0.2 -- fraction of the roar when the sound / waves start

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- wind-up weight (rises 0-20%, falls 20-30%) and roar weight (rises 20-30%, holds, falls 80-100%)
function RoarPose.envelope(f)
	local windup, roar
	if f < 0.2 then windup = smoothstep(f / 0.2)
	elseif f < 0.3 then windup = 1 - smoothstep((f - 0.2) / 0.1)
	else windup = 0 end
	if f < 0.2 then roar = 0
	elseif f < 0.3 then roar = smoothstep((f - 0.2) / 0.1)
	elseif f < 0.8 then roar = 1
	elseif f < 1 then roar = 1 - smoothstep((f - 0.8) / 0.2)
	else roar = 0 end
	return windup, roar
end

-- f: 0..1 roar progress; s: settings; now: clock seconds (drives the head shake)
function RoarPose.get(f, s, now)
	local w, r = RoarPose.envelope(f)
	local shake = rad(s.RoarShake * r * sin(now * 2 * pi * 18))
	local out = {}
	-- wind-up: neck rears up and back; roar: neck drops forward, skull tips up as the jaw drops
	out.Neck = CFrame.Angles(0, 0, rad(15 * w - 10 * r))
	out.Head = CFrame.Angles(0, shake, rad(8 * w + 12 * r))
	out.Jaw  = CFrame.Angles(0, 0, rad(-s.RoarJawOpen * r + 4 * w))
	-- arms flare forward/up, tail lifts
	out.ArmL = CFrame.Angles(0, 0, rad(30 * r))
	out.ArmR = CFrame.Angles(0, 0, rad(30 * r))
	out.Tail1 = CFrame.Angles(0, 0, rad(8 * r - 4 * w))
	out.Tail2 = CFrame.Angles(0, 0, rad(5 * r))
	return out, w, r
end

function RoarPose.settings(model)
	local s = {}
	for k, v in pairs(RoarPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return RoarPose
