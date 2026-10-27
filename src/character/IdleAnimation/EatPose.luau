-- EatPose v1.0 (Dino Arcade) — eating (carcass) and drinking (lake) loops for SurvivalServer 1.0's SurvivalAction.
-- User: "currently there is no drinking or eating animation".
-- Full-body pose (replaces the idle / walk pose by the eat weight, like JumpPose): the body crouches and pitches
-- nose-down with the feet kept planted (WalkPose.stance knee IK, with EatCrouch / EatLean in place of the creep
-- values), the neck and head swing down to the ground / water, the tail lifts as a counterweight.
--   eat   (SurvivalAction "eating"):  EatTugRate cycles per second. Each cycle: the jaw opens as the head goes down
--         (lowest at the jaw's widest), clamps shut, then the neck tugs up by EatTug degrees while the head shakes
--         side to side by EatShake degrees (tearing meat), and drops again.
--   drink (SurvivalAction "drinking"): head held lower and level at the water, small quick laps: the head bobs by
--         DrinkLap degrees at DrinkLapRate per second with the jaw opening DrinkJawOpen degrees on each lap.
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front), about Y = yaw;
-- Jaw: negative Z opens; Tail: positive pitch = lower (PouncePose / RamPose convention).
-- Reach: the animator (IdleAnimation 1.20) adds `reach` degrees of neck dip on top of EatNeckDip / DrinkNeckDip so the
-- mouth's lowest point settles on the target (drink: the lake surface minus DRINK_SINK; eat: the top of the carcass),
-- whatever the dino's size or where it stands; EatPose.REACH_MIN / REACH_MAX bound it.
-- Settings (model attributes, defaults below; read by EatPose.settings, not written to the model).

local EatPose = {}

EatPose.Version = "1.0"
EatPose.Defaults = {
	EatPoseEnabled = true,
	EatBlendRate   = 6,    -- how fast the pose blends in / out (per second)
	EatCrouch      = 0.8,  -- studs the body lowers (x model scale), feet planted
	EatLean        = 8,    -- degrees the body pitches nose-down
	EatNeckDip     = 20,   -- degrees the neck swings down (eating; the reach adds the rest)
	EatHeadDip     = 20,   -- degrees the head tips down (eating)
	EatTugRate     = 1.2,  -- tear cycles per second
	EatTug         = 14,   -- degrees the neck pulls up on each tear
	EatShake       = 10,   -- degrees of head shake while tearing
	EatJawOpen     = 35,   -- degrees the jaw opens before each bite
	DrinkNeckDip   = 18,   -- degrees the neck swings down (drinking; the reach adds the rest)
	DrinkHeadDip   = 14,   -- degrees the head tips down (drinking)
	DrinkLapRate   = 2.4,  -- laps per second
	DrinkLap       = 5,    -- degrees the head bobs per lap
	DrinkJawOpen   = 14,   -- degrees the jaw opens per lap
	EatTailLift    = 10,   -- degrees the tail lifts (counterweight)
}

EatPose.DRINK_SINK = 0.3 -- studs the mouth dips under the water surface
EatPose.REACH_MIN, EatPose.REACH_MAX = -35, 40 -- degrees of extra neck dip the reach may add

local rad, sin, pi = math.rad, math.sin, math.pi

-- kind: "eat" / "drink"; t: seconds since the loop started (local clock); s: settings; ws: WalkPose settings;
-- geo: WalkPose geometry; stance: WalkPose.stance; reach: extra degrees of neck dip (positive = lower; default 0)
function EatPose.get(kind, t, s, ws, geo, stance, reach)
	reach = reach or 0
	local st = table.clone(ws)
	st.CreepCrouch = s.EatCrouch
	st.CreepLean = s.EatLean
	st.CreepNeckDrop = 0
	st.CreepTailDrop = -s.EatTailLift
	local out = stance(st, geo)
	local neck, head, jaw, yaw = 0, 0, 0, 0
	if kind == "eat" then
		local c = sin(2 * pi * s.EatTugRate * t) -- > 0: tug up (jaws shut), < 0: head down (jaw opening)
		local tug = math.max(0, c)
		local down = math.max(0, -c)
		neck = -s.EatNeckDip - reach + s.EatTug * tug
		head = -s.EatHeadDip + 0.5 * s.EatTug * tug - 4 * down
		jaw = -s.EatJawOpen * down + 6 * tug
		yaw = s.EatShake * tug * sin(2 * pi * s.EatTugRate * 4 * t)
	else
		local l = sin(2 * pi * s.DrinkLapRate * t)
		neck = -s.DrinkNeckDip - reach + 0.5 * s.DrinkLap * l
		head = -s.DrinkHeadDip - s.DrinkLap * l
		jaw = -s.DrinkJawOpen * (0.5 + 0.5 * l)
	end
	out.Neck = (out.Neck or CFrame.identity) * CFrame.Angles(0, rad(yaw * 0.4), rad(neck))
	out.Head = (out.Head or CFrame.identity) * CFrame.Angles(rad(yaw * 0.3), rad(yaw * 0.6), rad(head))
	out.Jaw = CFrame.Angles(0, 0, rad(jaw))
	out.Tail2 = CFrame.Angles(0, 0, rad(-0.5 * s.EatTailLift))
	return out
end

function EatPose.settings(model)
	local s = {}
	for k, v in pairs(EatPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return EatPose
