-- PouncePose v1.0 (Dino Arcade) — raptor pounce: claws-first lunge, then gripping and biting while latched.
-- Pure functions: phase values -> per-joint offset, applied on top of each joint's rest C0 (same joint frames as
-- WalkPose / JumpPose: +X forward, +Y up, Z = side; rotation about Z = pitch, positive lifts the front / swings a
-- limb forward; Neck positive = head up; Jaw negative = open; Tail positive pitch = tail lower).
-- Phases (driven by the animator, IdleAnimation 1.16; the wind-up before the lunge uses JumpPose.crouch):
--   lunge   (a = seconds since launch): body pitched nose-up PounceLungePitch, both feet thrown forward (sickle claws
--           first: foot target PounceLungeLegFwd / PounceLungeLegDown of the leg reach, toes up PounceLungeToe), arms
--           reaching forward PounceLungeArms, head forward, jaws wide open PounceLungeJaw, tail straight back.
--   latched (t = seconds since the latch, chomp = seconds since the last bite, nil = none yet): the body clings to
--           the target surface (the latch frame's down is the surface): deep crouch PounceLatchCrouch with feet planted
--           (knee IK), nose-down PounceLatchLean, neck down into the target PounceLatchNeck, head pitched further
--           into it PounceLatchHead (negative = snout down, so the jaws dig into the body instead of facing up the
--           surface), arms gripping forward PounceLatchArms, jaws open PounceLatchJawOpen and snapping shut over
--           PounceChompTime after each bite with a head thrash PounceThrash, tail swishing for balance.
-- geo: WalkPose.buildGeo result.

local PouncePose = {}

PouncePose.Version = "1.0"
PouncePose.Defaults = {
	PouncePoseEnabled  = true,
	-- lunge
	PounceLungePitch   = 18,   -- degrees nose-up
	PounceLungeLegFwd  = 0.55, -- foot target forward of the hip (share of leg reach)
	PounceLungeLegDown = 0.45, -- foot target below the hip (share of leg reach)
	PounceLungeToe     = -20,  -- degrees toes down (negative = toes up, claws forward)
	PounceLungeArms    = 45,   -- degrees the arms reach forward
	PounceLungeJaw     = 28,   -- degrees the jaws open
	-- latched
	PounceLatchCrouch  = 2.6,  -- studs the body drops toward the surface (x geo.scale; raptor 0.31 -> 0.8)
	PounceLatchLean    = 22,   -- degrees nose-down (toward the surface)
	PounceLatchNeck    = 60,   -- degrees the neck lowers into the target
	PounceLatchHead    = -20,  -- degrees head pitch (negative = snout down into the target)
	PounceLatchArms    = 55,   -- degrees the arms grip forward
	PounceLatchJawOpen = 22,   -- degrees the jaws stay open between bites
	PounceChompTime    = 0.22, -- seconds a bite snaps shut and reopens
	PounceThrash       = 10,   -- degrees of head shake on each bite
}

local rad, sin, cos, max, min = math.rad, math.sin, math.cos, math.max, math.min
local atan2, acos = math.atan2, math.acos

local function clamp(x, a, b) return max(a, min(b, x)) end
local function smoothstep(s) s = clamp(s, 0, 1); return s * s * (3 - 2 * s) end

-- Two-joint IK in the hip's X/Y plane (same solution as WalkPose 3.3 / JumpPose 1.0, kept local).
local function solveLeg(geo, T)
	local d = T.Magnitude
	local dMin, dMax = math.abs(geo.l1 - geo.l2) + 0.01, (geo.l1 + geo.l2) * 0.999
	d = clamp(d, dMin, dMax)
	local cosA = clamp((geo.l1 * geo.l1 + d * d - geo.l2 * geo.l2) / (2 * geo.l1 * d), -1, 1)
	local phi1 = atan2(T.Y, T.X) + geo.bend * acos(cosA)
	local K = Vector2.new(cos(phi1), sin(phi1)) * geo.l1
	local Tc = T.Unit * d
	local phi2 = atan2(Tc.Y - K.Y, Tc.X - K.X)
	local dHip = phi1 - geo.phi1
	local dShin = phi2 - geo.phi2
	return dHip, dShin - dHip, dShin
end

local function tailStraight(out, pitch, swish)
	out.Tail1 = CFrame.Angles(0, rad(swish), pitch)
	for k = 2, 5 do out["Tail" .. k] = CFrame.Angles(0, rad(swish * 0.5), 0) end
end

-- lunge: a = seconds since launch (the pose is reached within ~0.08 s)
function PouncePose.lunge(a, s, geo)
	local out = {}
	local k = smoothstep(a / 0.08)
	local L = geo.l1 + geo.l2
	local rz = rad(s.PounceLungePitch * k)
	out.RootJoint = CFrame.Angles(0, 0, rz)
	local T = Vector2.new(geo.A0.X, geo.A0.Y):Lerp(Vector2.new(s.PounceLungeLegFwd * L, -s.PounceLungeLegDown * L), k)
	local dHip, dKnee, dShin = solveLeg(geo, T)
	local toe = rad(-s.PounceLungeToe) * k
	for _, S in ipairs({"L", "R"}) do
		out["Leg" .. S] = CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, toe - dShin)
	end
	out.ArmL = CFrame.Angles(0, 0, rad(s.PounceLungeArms * k))
	out.ArmR = CFrame.Angles(0, 0, rad(s.PounceLungeArms * k))
	out.Neck = CFrame.Angles(0, 0, -rz * 0.6)          -- head stays level, aimed at the target
	out.Head = CFrame.Angles(0, 0, -rz * 0.3)
	out.Jaw = CFrame.Angles(0, 0, rad(-s.PounceLungeJaw * k))
	tailStraight(out, -rz * 0.8, 0)
	return out
end

-- latched: t = seconds since the latch, chomp = seconds since the last bite (nil = none)
function PouncePose.latch(t, chomp, s, geo)
	local out = {}
	local k = smoothstep(t / 0.12)
	local bodyY = -s.PounceLatchCrouch * geo.scale * k
	local rz = rad(-s.PounceLatchLean * k)
	local bodyRot = CFrame.Angles(0, 0, rz)
	out.RootJoint = CFrame.new(0, bodyY, 0) * bodyRot
	-- feet gripping the surface at their rest spots
	local counter = CFrame.Angles(0, 0, -rz)
	for _, S in ipairs({"L", "R"}) do
		local hip = geo["hip" .. S]
		local shift = bodyRot * hip - hip
		local T = Vector2.new(geo.A0.X - shift.X, geo.A0.Y - bodyY - shift.Y)
		local dHip, dKnee, dShin = solveLeg(geo, T)
		out["Leg" .. S] = counter * CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, -dShin)
	end
	out.ArmL = CFrame.Angles(0, 0, rad(s.PounceLatchArms * k))
	out.ArmR = CFrame.Angles(0, 0, rad(s.PounceLatchArms * k))
	-- bite: jaws snap shut over the first 40% of PounceChompTime, reopen after; head thrashes
	local jaw = s.PounceLatchJawOpen * k
	local thrash = 0
	if chomp and chomp >= 0 and chomp < s.PounceChompTime then
		local u = chomp / s.PounceChompTime
		local shut = u < 0.4 and smoothstep(u / 0.4) or (1 - smoothstep((u - 0.4) / 0.6))
		jaw = jaw * (1 - shut)
		thrash = s.PounceThrash * sin(u * math.pi * 2) * (1 - u)
	end
	out.Neck = CFrame.Angles(0, rad(thrash * 0.5), rad(-s.PounceLatchNeck * k) - rz * 0.4)
	out.Head = CFrame.Angles(rad(thrash), rad(thrash * 0.5), rad(s.PounceLatchHead * k))
	out.Jaw = CFrame.Angles(0, 0, rad(-jaw))
	tailStraight(out, -rz * 0.6, 8 * sin(t * 5))
	return out
end

function PouncePose.settings(model)
	local s = {}
	for k, v in pairs(PouncePose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return PouncePose
