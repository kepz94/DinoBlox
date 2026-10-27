-- EatPose v1.1 (Dino Arcade) — eating (carcass) and drinking (lake) loops for SurvivalServer 1.0's SurvivalAction.
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
-- v1.1 (user: "it should take you a little longer to stick your head in the water", "the meter shouldnt start
--   refilling til the mouth is submerged", eating "takes time to get into rendering the player vulnerable"):
--   phases from SurvivalServer 1.1 (SurvivalPhase lowering -> eating / drinking -> rising), timed on the server, and
--   built from three new functions (EatPose.get is kept for IdleAnimation 1.20):
--   EatPose.pose(kind, s, ws, geo, stance, reach, m): the base pose (crouch, lean, neck dip + reach) plus motion
--     offsets m = {neck, head, jaw, yaw} (degrees); m = nil -> no motion (the pose the reach is solved for).
--   EatPose.loop(kind, t, s): the motion while eating / drinking (the v1.0 tear and lap cycles).
--   EatPose.enter(kind, u, s): u = 0..1 through the lowering -> weight w, mix (0 = mouth at the hover height above the
--     target, 1 = mouth in), motion m.
--       drink: 0 .. 0.7  head lowers to DRINK_HOVER above the water (w eases 0 -> 1)
--              0.7 .. 1  the snout dips in (mix 0 -> 1), jaw half open = the first lap's start
--       eat:   0 .. 0.55 head lowers to EAT_HOVER above the carcass
--              0.55 .. 0.8 wind-up: jaw gapes (1.2 x EatJawOpen), neck rears 6, head 4
--              0.8 .. 1  strike: mouth drives in (mix accelerates 0 -> 1), jaw clamps shut = the tear loop's start
--   EatPose.pose takes an optional 8th argument aim (degrees, Neck yaw, positive = left): the animator turns the neck
--   toward the carcass (within AIM_MAX) so the mouth goes into it, not beside it.
--   The animator solves the reach for the "in" target (drink: water top - DRINK_SINK_IN; eat: carcass top - EAT_SINK)
--   the hover target (+ DRINK_HOVER / EAT_HOVER) and uses reach = lerp(hover, in, mix).
-- Settings (model attributes, defaults below; read by EatPose.settings, not written to the model).

local EatPose = {}

EatPose.Version = "1.1"
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
EatPose.DRINK_SINK_IN = 1.0 -- v1.1: studs the mouth's lowest point goes under the water surface (snout submerged)
EatPose.EAT_SINK = 0.6      -- v1.1: studs the mouth's lowest point goes into the carcass (below its top)
EatPose.DRINK_HOVER = 1.5   -- v1.1: studs above the "in" height the head first lowers to
EatPose.EAT_HOVER = 2.5     -- v1.1
EatPose.AIM_MAX = 35        -- v1.1: most degrees the neck turns toward the carcass

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

-- v1.1 ------------------------------------------------------------------------------------------------------------
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function EatPose.pose(kind, s, ws, geo, stance, reach, m, aim)
	local st = table.clone(ws)
	st.CreepCrouch = s.EatCrouch
	st.CreepLean = s.EatLean
	st.CreepNeckDrop = 0
	st.CreepTailDrop = -s.EatTailLift
	local out = stance(st, geo)
	local eat = kind == "eat"
	local neck = -(eat and s.EatNeckDip or s.DrinkNeckDip) - (reach or 0) + (m and m.neck or 0)
	local head = -(eat and s.EatHeadDip or s.DrinkHeadDip) + (m and m.head or 0)
	local jaw = m and m.jaw or 0
	local yaw = m and m.yaw or 0
	out.Neck = (out.Neck or CFrame.identity) * CFrame.Angles(0, rad(yaw * 0.4 + (aim or 0)), rad(neck))
	out.Head = (out.Head or CFrame.identity) * CFrame.Angles(rad(yaw * 0.3), rad(yaw * 0.6), rad(head))
	out.Jaw = CFrame.Angles(0, 0, rad(jaw))
	out.Tail2 = CFrame.Angles(0, 0, rad(-0.5 * s.EatTailLift))
	return out
end

function EatPose.loop(kind, t, s)
	if kind == "eat" then
		local c = sin(2 * pi * s.EatTugRate * t) -- > 0: tug up (jaws shut), < 0: head down (jaw opening)
		local tug = math.max(0, c)
		local down = math.max(0, -c)
		return {neck = s.EatTug * tug, head = 0.5 * s.EatTug * tug - 4 * down, jaw = -s.EatJawOpen * down + 6 * tug,
			yaw = s.EatShake * tug * sin(2 * pi * s.EatTugRate * 4 * t)}
	end
	local l = sin(2 * pi * s.DrinkLapRate * t)
	return {neck = 0.5 * s.DrinkLap * l, head = -s.DrinkLap * l, jaw = -s.DrinkJawOpen * (0.5 + 0.5 * l), yaw = 0}
end

-- returns w (pose weight), mix (0 hover .. 1 in), m (motion)
function EatPose.enter(kind, u, s)
	u = math.clamp(u, 0, 1)
	if kind == "drink" then
		if u < 0.7 then return smooth(u / 0.7), 0, {neck = 0, head = 0, jaw = 0, yaw = 0} end
		local k = smooth((u - 0.7) / 0.3)
		return 1, k, {neck = 0, head = 0, jaw = -s.DrinkJawOpen * 0.5 * k, yaw = 0}
	end
	local gape = 1.2 * s.EatJawOpen
	if u < 0.55 then return smooth(u / 0.55), 0, {neck = 0, head = 0, jaw = 0, yaw = 0} end
	if u < 0.8 then
		local v = smooth((u - 0.55) / 0.25)
		return 1, 0, {neck = 6 * v, head = 4 * v, jaw = -gape * v, yaw = 0}
	end
	local k = ((u - 0.8) / 0.2) ^ 2
	return 1, k, {neck = 6 * (1 - k), head = 4 * (1 - k), jaw = -gape * (1 - k), yaw = 0}
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
