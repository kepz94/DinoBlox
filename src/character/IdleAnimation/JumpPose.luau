-- JumpPose v1.0 (Dino Arcade) — intentional leap: crouch-and-spring, airborne tuck, landing reach, landing squash.
-- Pure functions: phase values -> per-joint offset, applied on top of each joint's rest C0 (same joint frames as
-- WalkPose: +X forward, +Y up, Z = side; rotation about Z = pitch, positive lifts the front / swings a limb forward;
-- Tail positive pitch = tail lower; Neck positive = head up).
-- Phases (driven by the animator, IdleAnimation 1.15):
--   crouch  (0 .. JumpWindup after the press, c = 0..1): body drops JumpCrouch, nose-down JumpCrouchLean, feet
--           planted (knee IK), head low (JumpCrouchNeck), tail low (JumpCrouchTail), arms tucked.
--   air     (after the windup until landed): a = seconds since launch, fall = 0 (rising) .. 1 (falling fast).
--           push (a = 0): legs driven down-back (JumpPushBack degrees behind vertical, JumpPushExtend of full
--           reach), toes pointed (JumpPushToe), body nose-up (JumpLaunchPitch), head up, tail up.
--           -> tuck over JumpPushTime: feet folded up under the body (JumpTuckFwd / JumpTuckDown of leg reach),
--           toes down (JumpTuckToe), tail up as a counterweight (JumpAirTail), arms tucked.
--           -> reach as it falls (fall): feet forward-down ready to land (JumpReachFwd / JumpReachDown),
--           toes up (JumpReachToe), head up to look at the landing.
--           Body pitch follows the vertical speed: up to JumpAirPitch nose-up rising, nose-down falling.
--   land    (u = 0..1 over JumpLandTime after touching down): squash — body drops JumpLandCrouch at u = 0.25 and
--           springs back, feet planted, head and tail dip; the animator fades it back into idle/walk.
-- Lengths in studs scale with geo.scale (thigh / 4.03); foot targets in the air are fractions of the leg reach.
-- geo: WalkPose.buildGeo result.

local JumpPose = {}

JumpPose.Version = "1.0"
JumpPose.Defaults = {
	JumpPoseEnabled  = true,
	-- crouch (load-up before the spring)
	JumpCrouch       = 3.0,  -- studs the body drops (x geo.scale; raptor 0.31 -> 0.93)
	JumpCrouchLean   = 12,   -- degrees nose-down
	JumpCrouchNeck   = 18,   -- degrees the neck lowers
	JumpCrouchTail   = 10,   -- degrees the tail lowers
	JumpCrouchArms   = 25,   -- degrees the arms fold back
	-- push-off
	JumpPushBack     = 22,   -- degrees behind vertical the legs drive
	JumpPushExtend   = 0.97, -- share of the full leg reach
	JumpPushToe      = 45,   -- degrees the toes point down
	JumpLaunchPitch  = 14,   -- degrees nose-up at the push
	JumpPushTime     = 0.15, -- seconds from push to full tuck
	-- tuck (rising)
	JumpTuckFwd      = 0.14, -- foot target forward of the hip (share of leg reach)
	JumpTuckDown     = 0.50, -- foot target below the hip (share of leg reach)
	JumpTuckToe      = 30,   -- degrees toes down
	JumpAirTail      = 10,   -- degrees the tail lifts (counterweight)
	JumpAirArms      = 35,   -- degrees the arms tuck
	JumpAirPitch     = 10,   -- degrees body pitch at full vertical speed (nose-up rising, nose-down falling)
	JumpAirNeck      = 10,   -- degrees the neck lifts (head up, looking ahead)
	-- reach (falling, ready to land)
	JumpReachFwd     = 0.24, -- foot target forward of the hip (share of leg reach)
	JumpReachDown    = 0.84, -- foot target below the hip (share of leg reach)
	JumpReachToe     = -10,  -- degrees toes down (negative = toes up)
	-- landing squash
	JumpLandTime     = 0.22, -- seconds
	JumpLandCrouch   = 2.5,  -- studs the body drops at the deepest point (x geo.scale)
	JumpLandLean     = 8,    -- degrees nose-down at the deepest point
	JumpLandNeck     = 12,   -- degrees the neck dips
	JumpLandTail     = 8,    -- degrees the tail dips
}

local rad, sin, cos, max, min, pi = math.rad, math.sin, math.cos, math.max, math.min, math.pi
local atan2, acos = math.atan2, math.acos

local function clamp(x, a, b) return max(a, min(b, x)) end
local function smoothstep(s) s = clamp(s, 0, 1); return s * s * (3 - 2 * s) end

-- Two-joint IK in the hip's X/Y plane (same solution as WalkPose 3.3, kept local so WalkPose is not changed).
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

-- legs with both feet planted at their rest spots while the body is lowered by bodyY and pitched by rz
local function plantedLegs(out, geo, bodyY, rz)
	local bodyRot = CFrame.Angles(0, 0, rz)
	local counter = CFrame.Angles(0, 0, -rz)
	for _, S in ipairs({"L", "R"}) do
		local hip = geo["hip" .. S]
		local shift = bodyRot * hip - hip
		local T = Vector2.new(geo.A0.X - shift.X, geo.A0.Y - bodyY - shift.Y)
		local dHip, dKnee, dShin = solveLeg(geo, T)
		out["Leg" .. S] = counter * CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, -dShin) -- foot flat on the ground
	end
end

-- legs reaching for a foot target T (hip frame, studs) with an absolute foot pitch (radians, body frame)
local function airLegs(out, geo, T, footPitch)
	local dHip, dKnee, dShin = solveLeg(geo, T)
	for _, S in ipairs({"L", "R"}) do
		out["Leg" .. S] = CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, footPitch - dShin)
	end
end

local function upper(out, rz, neck, head, tail1, arms)
	out.Neck = CFrame.Angles(0, 0, rad(neck))
	out.Head = CFrame.Angles(0, 0, rad(head))
	out.ArmL = CFrame.Angles(0, 0, rad(-arms))
	out.ArmR = CFrame.Angles(0, 0, rad(-arms))
	out.Tail1 = CFrame.Angles(0, 0, rad(tail1) - rz * 0.5) -- tail partly counters the body pitch
	for k = 2, 5 do out["Tail" .. k] = CFrame.identity end
end

-- crouch at strength c (0..1)
function JumpPose.crouch(c, s, geo)
	local out = {}
	c = smoothstep(c)
	local bodyY = -s.JumpCrouch * geo.scale * c
	local rz = rad(-s.JumpCrouchLean * c)
	out.RootJoint = CFrame.new(0, bodyY, 0) * CFrame.Angles(0, 0, rz)
	plantedLegs(out, geo, bodyY, rz)
	upper(out, rz, s.JumpCrouchLean * 0.6 * c - s.JumpCrouchNeck * c, s.JumpCrouchNeck * 0.5 * c,
		s.JumpCrouchTail * c, s.JumpCrouchArms * c)
	return out
end

-- airborne: a = seconds since launch, fall = 0..1 (falling share), vyShare = vertical speed / launch speed (-1..1)
function JumpPose.air(a, fall, vyShare, s, geo)
	local out = {}
	local L = geo.l1 + geo.l2
	local k = smoothstep(a / max(0.01, s.JumpPushTime))     -- push -> tuck
	local r = smoothstep(fall)                                -- tuck -> reach
	-- foot targets (hip frame)
	local back = rad(s.JumpPushBack)
	local push = Vector2.new(-sin(back), -cos(back)) * (L * s.JumpPushExtend)
	local tuck = Vector2.new(s.JumpTuckFwd * L, -s.JumpTuckDown * L)
	local reach = Vector2.new(s.JumpReachFwd * L, -s.JumpReachDown * L)
	local T = push:Lerp(tuck, k):Lerp(reach, r)
	local toe = rad((-s.JumpPushToe) * (1 - k) + (-s.JumpTuckToe) * k)
	toe = toe * (1 - r) + rad(-s.JumpReachToe) * r
	airLegs(out, geo, T, toe)
	-- body pitch: launch pitch at the push, then follows the vertical speed
	local pitch = s.JumpLaunchPitch * (1 - k) + s.JumpAirPitch * clamp(vyShare, -1, 1) * k
	local rz = rad(pitch)
	out.RootJoint = CFrame.Angles(0, 0, rz)
	upper(out, rz, s.JumpAirNeck - pitch * 0.5 + 6 * r, -s.JumpAirNeck * 0.3,
		-s.JumpAirTail, s.JumpAirArms)
	return out
end

-- landing squash: u = 0..1 over JumpLandTime; returns the pose and the squash amount (0..1)
function JumpPose.land(u, s, geo)
	local out = {}
	u = clamp(u, 0, 1)
	local f = u < 0.25 and smoothstep(u / 0.25) or (1 - smoothstep((u - 0.25) / 0.75))
	local bodyY = -s.JumpLandCrouch * geo.scale * f
	local rz = rad(-s.JumpLandLean * f)
	out.RootJoint = CFrame.new(0, bodyY, 0) * CFrame.Angles(0, 0, rz)
	plantedLegs(out, geo, bodyY, rz)
	upper(out, rz, -s.JumpLandNeck * f, s.JumpLandNeck * 0.4 * f, s.JumpLandTail * f, s.JumpCrouchArms * f)
	return out, f
end

function JumpPose.settings(model)
	local s = {}
	for k, v in pairs(JumpPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return JumpPose
