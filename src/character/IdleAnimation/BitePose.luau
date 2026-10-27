-- BitePose v1.1 (Dino Arcade) — upper-body quick bite layered on top of idle / walk / run / creep.
-- Pure function: time since the bite started (seconds) -> per-joint offsets, multiplied onto the
-- current pose. Only neck, head, jaw, arms and the first tail segment move; the body root is untouched,
-- so planted feet stay planted (the forward lunge is real movement, done by BiteTest).
-- Beats (seconds, attributes):
--   wind-up  0 .. W           neck rears up and back, jaw gapes to BiteJawOpen
--   strike   W .. W+S         neck drives forward and down (+BiteReach studs), jaw slams shut (contact at W+S)
--   recover  W+S .. W+S+R     back to the base pose; on a hit, the head thrashes side to side (BiteShake)
-- Hit-stop (BiteHitStop) is applied by the animator by holding the clock at the hit moment.
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front),
-- about Y = yaw; Jaw: negative Z opens, positive closes (rest jaw is 10 degrees open).
-- v1.1: bite dip. BitePose.get takes an optional 4th argument dip (degrees, default 0 = the v1.0 pose): the total angle
--   the mouth must swing down about the neck to reach a low target (BiteTest 1.3 / BiteServer 1.5 / BotServer 1.2,
--   attribute BiteDip). The strike's own BiteLunge already covers part of it; the rest (dip - BiteLunge, at least 0)
--   is added to the neck: 30% during the wind-up (the head starts to lower), all of it at the strike.

local BitePose = {}

BitePose.Version = "1.1"
BitePose.Defaults = {
	BiteEnabled   = true,
	BiteWindup    = 0.15, -- seconds
	BiteStrike    = 0.10, -- seconds (jaws shut at the end = contact)
	BiteRecover   = 0.30, -- seconds
	BiteJawOpen   = 45,   -- degrees the jaw gapes in the wind-up
	BiteRear      = 14,   -- degrees the neck rears up in the wind-up
	BiteLunge     = 20,   -- degrees the neck drives down at the strike
	BiteReach     = 1.2,  -- studs the neck slides forward at the strike
	BiteShake     = 14,   -- degrees of head thrash after a hit
	BiteShakeTime = 0.30, -- seconds of thrash after a hit
	BiteHitStop   = 0.06, -- seconds the pose freezes on a hit
	BiteCooldown  = 0.8,  -- seconds between bites (checked by BiteServer)
	BiteDamage    = 25,   -- damage per bite (dummies only for now)
	BiteRange     = 5,    -- studs, radius of the hit sphere in front of the mouth
	BiteLungeDist = 3,    -- studs the body pushes forward during the strike (BiteTest)
	BiteSoundId   = "",   -- chomp sound (BiteFX); empty = no sound
	BiteDipMax    = 60,   -- v1.1: most degrees a bite swings down to reach a low target
}

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function BitePose.duration(s)
	return s.BiteWindup + s.BiteStrike + s.BiteRecover
end

-- wind-up weight w and strike weight k at time t (seconds since the bite started)
function BitePose.envelope(t, s)
	local W, S, R = s.BiteWindup, s.BiteStrike, s.BiteRecover
	local w, k
	if t < W then
		w, k = smoothstep(t / W), 0
	elseif t < W + S then
		local u = (t - W) / S
		w, k = 1 - u, u * u -- accelerates into the snap
	else
		w, k = 0, 1 - smoothstep((t - W - S) / R)
	end
	return w, k
end

-- phase name at time t: "windup" / "strike" / "recover" / "none"
function BitePose.phase(t, s)
	local W, S = s.BiteWindup, s.BiteStrike
	if t < 0 or t > BitePose.duration(s) then return "none" end
	if t < W then return "windup" end
	if t < W + S then return "strike" end
	return "recover"
end

-- t: seconds since the bite started (hit-stop already applied); hitT: seconds since start when the
-- bite landed (nil = no hit); s: settings
function BitePose.get(t, hitT, s, dip)
	local w, k = BitePose.envelope(t, s)
	local extra = math.max(0, math.min(dip or 0, s.BiteDipMax) - s.BiteLunge) -- v1.1
	local dipW = math.min(1, k + 0.3 * w)
	local thrash = 0
	if hitT and t >= hitT then
		local u = (t - hitT) / s.BiteShakeTime
		if u < 1 then thrash = rad(s.BiteShake) * sin(u * 3 * 2 * pi) * (1 - u) end
	end
	local out = {}
	out.Neck = CFrame.new(s.BiteReach * k, 0, 0)
		* CFrame.Angles(0, thrash * 0.4, rad(s.BiteRear * w * (extra > 0 and 0.4 or 1) - s.BiteLunge * k - extra * dipW))
	out.Head = CFrame.Angles(thrash * 0.3, thrash * 0.6, rad(8 * w + 8 * k))
	out.Jaw  = CFrame.Angles(0, 0, rad(-s.BiteJawOpen * w + 10 * k))
	out.ArmL = CFrame.Angles(0, 0, rad(25 * k))
	out.ArmR = CFrame.Angles(0, 0, rad(25 * k))
	out.Tail1 = CFrame.Angles(0, 0, rad(6 * k - 3 * w))
	return out, w, k
end

function BitePose.settings(model)
	local s = {}
	for k, v in pairs(BitePose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return BitePose
