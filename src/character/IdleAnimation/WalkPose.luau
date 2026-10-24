-- WalkPose v3.0 (Dino Arcade) — distance-driven walk + run cycle for the TRex rig (rig v1.2: hip, knee, ankle)
-- Pure function: gait phase (radians) -> per-joint offset, applied on top of each joint's rest C0.
-- Joint frames are world-aligned at build time: +X forward, +Y up, Z = side.
--   Rotation about Z = pitch (positive lifts the front / swings a limb forward), about Y = yaw, about X = roll.
-- v1.1: body height from real foot geometry | v1.2: bounce, body rock, head bob, tail whip, arm swing
-- v2.0: knee + ankle IK. Each foot follows a stance/swing path: in stance it stays flat and planted
--       while the body moves over it; in swing it lifts, folds at the knee, swings forward toes-down,
--       and plants again. Hip + knee angles come from 2-joint IK; the ankle sets the foot angle.
--       WalkLegSwing is no longer used (stride comes from WalkStepLength / WalkDuty).
-- v2.1: foot targets include how the body roll/yaw/rock moves each hip joint.
-- v3.0: run gait. Every Walk* setting has a Run* twin; gait blend g (0 = walk, 1 = run) mixes them.
--       Run adds a flight phase (RunDuty < 0.5: both feet up), body highest between steps instead of at
--       mid-stance, forward lean (RunLean) with neck/tail counter-lean, and arms tucked (RunArmTuck).
--
-- geo (from WalkPose.buildGeo): rest knee/ankle positions in the hip frame plus foot size at the ankle.

local WalkPose = {}

WalkPose.Version = "3.0"
WalkPose.Defaults = {
	WalkEnabled     = true,
	-- walk (g = 0)
	WalkStepLength  = 6,    -- studs a planted foot travels under the body per step (scales with model)
	WalkDuty        = 0.6,  -- share of the cycle each foot is planted
	WalkLift        = 1.6,  -- studs the swinging foot lifts (scales with model)
	WalkCrouch      = 0.5,  -- studs the body lowers (bends the knees; scales with model)
	WalkFootForward = 1.2,  -- studs the foot path is shifted forward of the rest ankle (scales with model)
	WalkToeDrop     = 25,   -- degrees the toes point down early in the swing
	WalkSway        = 1.0,  -- multiplier on body side roll/yaw
	WalkBounce      = 0.35, -- studs the body springs up at mid-stance (scales with model)
	WalkBodyRock    = 4,    -- degrees the body pitches forward/back each step
	WalkHeadBob     = 6,    -- degrees the neck/head nod each step
	WalkTailWhip    = 1.0,  -- multiplier on tail side swing + vertical whip
	WalkArmSwing    = 25,   -- degrees the arms swing
	-- run (g = 1)
	RunStepLength   = 6.5,
	RunDuty         = 0.4,  -- below 0.5 = a moment with both feet off the ground
	RunLift         = 2.4,
	RunCrouch       = 1.0,
	RunFootForward  = 1.6,
	RunToeDrop      = 35,
	RunSway         = 0.6,
	RunBounce       = 0.6,  -- studs the body rises between steps (flight)
	RunBodyRock     = 6,
	RunHeadBob      = 8,
	RunTailWhip     = 0.7,
	RunArmSwing     = 10,
	RunLean         = 8,    -- degrees the body pitches nose-down while running
	RunArmTuck      = 35,   -- degrees the arms fold back while running
}

local rad, sin, cos, max, min, pi = math.rad, math.sin, math.cos, math.max, math.min, math.pi
local atan2, acos, asin = math.atan2, math.acos, math.asin

local function clamp(x, a, b) return max(a, min(b, x)) end
local function smoothstep(s) return s * s * (3 - 2 * s) end

local GAIT_KEYS = {"StepLength", "Duty", "Lift", "Crouch", "FootForward", "ToeDrop", "Sway",
	"Bounce", "BodyRock", "HeadBob", "TailWhip", "ArmSwing"}

-- Blended gait values: walk (g = 0) to run (g = 1).
local function gait(s, g)
	local q = {}
	for _, k in ipairs(GAIT_KEYS) do
		q[k] = s["Walk" .. k] * (1 - g) + s["Run" .. k] * g
	end
	q.Duty = clamp(q.Duty, 0.3, 0.8)
	q.Lean = s.RunLean * g
	q.ArmTuck = s.RunArmTuck * g
	return q
end

-- kneeC0 / ankleC0: rest C0 of the Knee and Ankle motors (positions are in the parent joint frame).
-- foot: {toe = sole front X from ankle, ankleHeight = ankle height above sole} (studs).
-- hipL / hipR: rest hip joint positions in the body frame (LegL / LegR motor C0 positions).
function WalkPose.buildGeo(kneeC0, ankleC0, foot, hipL, hipR)
	local K = Vector2.new(kneeC0.Position.X, kneeC0.Position.Y)
	local A = K + Vector2.new(ankleC0.Position.X, ankleC0.Position.Y)
	local l1, l2 = K.Magnitude, (A - K).Magnitude
	-- which side of the hip->ankle line the knee bends to (+1 = counter-clockwise in the X/Y plane)
	local cross = A.X * K.Y - A.Y * K.X
	return {
		K0 = K, A0 = A, l1 = l1, l2 = l2,
		phi1 = atan2(K.Y, K.X), phi2 = atan2(A.Y - K.Y, A.X - K.X),
		bend = cross >= 0 and 1 or -1,
		toe = foot.toe, ankleHeight = foot.ankleHeight,
		hipL = hipL or Vector3.zero, hipR = hipR or Vector3.zero,
		scale = l1 / 4.03, -- 4.03 = TRex v1.1 thigh length at scale 1
	}
end

-- Distance the body moves in one full cycle (two steps) at gait blend g.
-- A planted foot slides back StepLength under the body during Duty of the cycle,
-- so in a whole cycle the body moves StepLength / Duty.
function WalkPose.stride(s, geo, g)
	local q = gait(s, g or 0)
	return q.StepLength * geo.scale / q.Duty
end

-- Two-joint IK in the hip's X/Y plane. Returns hip, knee rotation offsets (radians) from rest,
-- the absolute shin direction change, and the clamped reach flag.
local function solveLeg(geo, T)
	local d = T.Magnitude
	local dMin, dMax = math.abs(geo.l1 - geo.l2) + 0.01, (geo.l1 + geo.l2) * 0.999
	local reached = d >= dMin and d <= dMax
	d = clamp(d, dMin, dMax)
	local cosA = clamp((geo.l1 * geo.l1 + d * d - geo.l2 * geo.l2) / (2 * geo.l1 * d), -1, 1)
	local phi1 = atan2(T.Y, T.X) + geo.bend * acos(cosA)
	local K = Vector2.new(cos(phi1), sin(phi1)) * geo.l1
	local Tc = T.Unit * d
	local phi2 = atan2(Tc.Y - K.Y, Tc.X - K.X)
	local dHip = phi1 - geo.phi1
	local dShin = phi2 - geo.phi2          -- absolute shin rotation vs rest
	return dHip, dShin - dHip, dShin, reached
end

-- Foot path for one leg. u: 0..1 through this leg's cycle. Returns ankle offset (x, y) from its
-- rest position and the desired absolute foot pitch (radians, negative = toes down).
local function footPath(u, q, geo)
	local beta = q.Duty
	local H = q.StepLength * geo.scale / 2
	if u < beta then
		local t = u / beta
		return H - 2 * H * t, 0, 0, "stance"
	end
	local t = (u - beta) / (1 - beta)
	local x = -H + 2 * H * smoothstep(t)
	local y = q.Lift * geo.scale * sin(pi * t)
	local pitch = rad(-q.ToeDrop * sin(pi * t) * (1 - t))
	return x, y, pitch, "swing"
end

-- p: gait phase (radians); geo: from buildGeo; g: gait blend 0 (walk) .. 1 (run), default 0
function WalkPose.get(p, s, geo, g)
	g = clamp(g or 0, 0, 1)
	local q = gait(s, g)
	local sw = q.Sway
	local beta = q.Duty
	local out = {}

	-- body height: crouch; walk springs up at mid-stance, run rises between steps (flight)
	local c2 = cos(2 * (p - pi * beta))
	local bodyY = -q.Crouch * geo.scale
		+ s.WalkBounce * (1 - g) * geo.scale * (0.5 + 0.5 * c2)
		+ s.RunBounce * g * geo.scale * (0.5 - 0.5 * c2)
	local rx = rad(4.0 * sw * sin(p))
	local ry = rad(5.0 * sw * sin(p))
	local rz = rad(q.BodyRock * sin(2 * p + 0.6) - q.Lean)
	out.RootJoint = CFrame.new(0, bodyY, 0) * CFrame.Angles(rx, ry, rz)
	local bodyRot = CFrame.Angles(rx, ry, rz)
	local counter = CFrame.Angles(0, 0, -rz) * CFrame.Angles(0, -ry, 0) * CFrame.Angles(-rx, 0, 0)

	-- legs: L on phase p, R half a cycle later
	for _, side in ipairs({{"L", p}, {"R", p + pi}}) do
		local S, ph = side[1], side[2]
		local u = (ph / (2 * pi)) % 1
		local fx, fy, pitch = footPath(u, q, geo)
		-- ankle target in the hip frame; the hip moved by bodyY plus the shift caused by the body
		-- rotating about its centre (hip sits off-centre), while the ground did not move
		local hip = geo["hip" .. S]
		local shift = bodyRot * hip - hip
		local T = Vector2.new(geo.A0.X + q.FootForward * geo.scale + fx - shift.X,
			geo.A0.Y + fy - bodyY - shift.Y)
		local dHip, dKnee, dShin = solveLeg(geo, T)
		-- keep the toes above ground (toe height ~ ankle lift + toe * sin(pitch))
		local minPitch = asin(clamp((0.05 - fy) / geo.toe, -1, 1))
		pitch = max(pitch, minPitch)
		out["Leg" .. S] = counter * CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, pitch - dShin)
	end

	-- arms swing opposite to the legs on the same side; fold back while running
	local tuck = rad(-q.ArmTuck)
	out.ArmL = CFrame.Angles(0, 0, tuck + rad(-q.ArmSwing * sin(p)))
	out.ArmR = CFrame.Angles(0, 0, tuck + rad(q.ArmSwing * sin(p)))
	-- neck nods with each step and lifts against the lean so the head looks ahead;
	-- head nods back partly so the snout bobs
	local hb = q.HeadBob
	out.Neck = CFrame.Angles(0, -ry * 0.6, 0) * CFrame.Angles(-rx * 0.6, 0, rad(q.Lean * 0.6 - hb * sin(2 * p - 0.3)))
	out.Head = CFrame.Angles(0, -ry * 0.4, 0) * CFrame.Angles(-rx * 0.4, 0, rad(q.Lean * 0.3 + hb * 0.5 * sin(2 * p - 0.9)))
	out.Jaw  = CFrame.Angles(0, 0, rad(-(2.5 + 3 * g) * (0.5 + 0.5 * sin(2 * p - 1.2))))
	-- tail: side swing opposite to the body + vertical whip each step; tip lags most;
	-- the first segment lifts against the lean so the tail stays level while running
	local tw = q.TailWhip
	for k = 1, 5 do
		local yaw = rad(-(4 + 2.5 * k) * tw * sin(p - 0.5 * k))
		local tp = rad(-(2 + 1.5 * k) * tw * sin(2 * p - 0.5 * k))
		if k == 1 then tp += rad(q.Lean * 0.9) end
		out["Tail" .. k] = CFrame.Angles(0, yaw, tp)
	end
	return out
end

function WalkPose.settings(model)
	local s = {}
	for k, v in pairs(WalkPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return WalkPose
