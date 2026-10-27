-- RamPose v1.0 (Dino Arcade) — the T-Rex tree charge (RamTest 1.0 / RamServer 1.0 / BotServer 1.3) and the stunned
-- dino's dizzy flailing (StunnedUntil, ShakeOffServer 1.1), as per-joint offsets multiplied onto the current pose.
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front), about Y = yaw,
-- about X = roll; Jaw: negative Z opens.
-- Ram phases (seconds since the start, attributes below):
--   windup  0 .. RamWindup       head drops low and forward, jaw opens, tail lifts, body dips its nose and the right
--                                foot stomps once (a clear "about to charge" tell for raptors)
--   charge  RamWindup .. end     head low and level like a battering ram, body leaning in, tail straight up behind
--   impact  end .. +RAM_RECOIL   the head snaps up and back from the hit and shakes, then everything eases out
-- Stun (lying on its side; the toss / roll of the body itself is done by StunClient 1.1 / BotServer 1.3): legs kick
-- out of step, head wobbles side to side, jaw hangs open, tail flops. Knees swing symmetrically about rest (no fixed
-- bend, so the sign of the knee joint does not matter).

local RamPose = {}

RamPose.Version = "1.0"
RamPose.Defaults = {
	RamEnabled     = false, -- T-Rex data sets true
	RamWindup      = 0.4,   -- seconds of wind-up before the charge
	RamRange       = 60,    -- studs: nearest tree trunk the charge can target
	RamStaminaCost = 20,    -- stamina per charge (StaminaServer 1.3)
	RamCooldown    = 6,     -- seconds between charges
	RamSpeedMul    = 1.15,  -- charge speed = MoveRunSpeed x this
	RamMaxCharge   = 3.5,   -- seconds a charge may run without reaching the tree
}
RamPose.RECOIL = 0.45

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- phase: "windup" / "charge" / "impact" / "fade"; u: 0..1 progress inside the phase; k: overall weight 0..1
function RamPose.get(phase, u, k, now)
	local out = {}
	local w = phase == "windup" and smoothstep(u) or 0
	local c = (phase == "charge") and 1 or (phase == "windup" and smoothstep(u) * 0.6 or 0)
	local hit = phase == "impact" and (1 - u) or 0
	local fade = phase == "fade" and (1 - u) or 0
	local lowered = math.max(w, c, fade)
	local shake = rad(10 * hit * sin(now * 2 * pi * 9))
	out.RootJoint = CFrame.Angles(0, 0, rad((-7 * lowered + 4 * hit) * k))
	out.Neck = CFrame.Angles(0, shake * 0.5, rad((-28 * lowered + 26 * hit) * k))
	out.Head = CFrame.Angles(shake * 0.4, shake, rad((-6 * lowered + 10 * hit) * k))
	out.Jaw  = CFrame.Angles(0, 0, rad((-18 * w - 10 * c - 25 * hit) * k))
	out.ArmL = CFrame.Angles(0, 0, rad(-25 * lowered * k))
	out.ArmR = CFrame.Angles(0, 0, rad(-25 * lowered * k))
	-- tail positive pitch = lower (PouncePose convention): it lifts as the head drops
	out.Tail1 = CFrame.Angles(0, 0, rad(-12 * lowered * k))
	out.Tail2 = CFrame.Angles(0, 0, rad(-5 * lowered * k))
	-- wind-up stomp: the right foot lifts and slams down once (peak at mid wind-up)
	if phase == "windup" then
		local e = sin(pi * math.clamp(u, 0, 1))
		out.LegR = CFrame.Angles(0, 0, rad(20 * e * k))
		out.KneeR = CFrame.Angles(0, 0, rad(-30 * e * k))
		out.AnkleR = CFrame.Angles(0, 0, rad(10 * e * k))
	end
	return out
end

-- stunned flailing; k: weight (0..1), now: clock seconds
function RamPose.stun(k, now)
	local out = {}
	local kick = sin(now * 2 * pi * 2.6)
	local kick2 = sin(now * 2 * pi * 2.6 + 1.9)
	local wob = sin(now * 2 * pi * 1.3)
	out.LegL = CFrame.Angles(0, 0, rad(30 * kick * k))
	out.LegR = CFrame.Angles(0, 0, rad(30 * kick2 * k))
	out.KneeL = CFrame.Angles(0, 0, rad(20 * kick2 * k))
	out.KneeR = CFrame.Angles(0, 0, rad(20 * kick * k))
	out.ArmL = CFrame.Angles(0, 0, rad(35 * kick2 * k))
	out.ArmR = CFrame.Angles(0, 0, rad(35 * kick * k))
	out.Neck = CFrame.Angles(rad(12 * wob * k), rad(18 * wob * k), rad(-10 * k))
	out.Head = CFrame.Angles(rad(10 * wob * k), rad(-14 * wob * k), 0)
	out.Jaw  = CFrame.Angles(0, 0, rad(-22 * k))
	out.Tail1 = CFrame.Angles(0, rad(10 * kick * k), rad(-8 * k))
	out.Tail2 = CFrame.Angles(0, rad(8 * kick2 * k), 0)
	return out
end

function RamPose.settings(model)
	local s = {}
	for k, v in pairs(RamPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return RamPose
