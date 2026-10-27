-- DeadPose v1.0 (Dino Arcade) — a dino that is clearly dead (user: "dead dinos should also be clearly dead so maybe make
-- a dead animation for the ones laying down"; answers: dead pose only; carcasses + KO'd bots + dead players).
-- Static per-joint offsets (C0 = restC0 * offset) for every rig joint: body root left as it is (the body itself lies
-- on its side: BotServer's KO roll / the Humanoid's death fall), legs stiff and sticking out (hips swung forward, knees
-- straightened, toes pointed), arms stiff, neck and head drooped, jaw hanging open, tail limp. No breathing or motion.
-- Used by IdleAnimation 1.21 (every client: Humanoid dead or DummyState "ko", blended in at DeadBlendRate) and by
-- SurvivalServer 1.1 (carcasses: the same offsets written once to the carcass's Motor6D C0, server side, replicated).
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front / swings a leg
-- forward), about Y = yaw, about X = roll; Jaw: negative Z opens; Tail: positive pitch = lower.
-- Settings (model attributes, defaults below; read by DeadPose.settings).

local DeadPose = {}

DeadPose.Version = "1.0"
DeadPose.Defaults = {
	DeadPoseEnabled = true,
	DeadBlendRate   = 4,   -- how fast the pose blends in (per second)
	DeadLegSwing    = 38,  -- degrees the legs swing forward (stiff, sticking out)
	DeadKnee        = -18, -- degrees added at the knees (straightens the rest bend)
	DeadAnkle       = 25,  -- degrees the feet point
	DeadArm         = 45,  -- degrees the arms stick forward
	DeadNeck        = -18, -- degrees the neck droops
	DeadHead        = -12, -- degrees the head droops
	DeadHeadRoll    = 10,  -- degrees the head lolls to the side
	DeadJaw         = -32, -- degrees the jaw hangs open
	DeadTail        = 6,   -- degrees each tail segment goes limp (lower)
}

local rad = math.rad

function DeadPose.get(s)
	s = s or DeadPose.Defaults
	local out = {}
	out.RootJoint = CFrame.identity
	out.LegL = CFrame.Angles(0, 0, rad(s.DeadLegSwing))
	out.LegR = CFrame.Angles(0, 0, rad(s.DeadLegSwing * 0.85))
	out.KneeL = CFrame.Angles(0, 0, rad(s.DeadKnee))
	out.KneeR = CFrame.Angles(0, 0, rad(s.DeadKnee))
	out.AnkleL = CFrame.Angles(0, 0, rad(s.DeadAnkle))
	out.AnkleR = CFrame.Angles(0, 0, rad(s.DeadAnkle))
	out.ArmL = CFrame.Angles(0, 0, rad(s.DeadArm))
	out.ArmR = CFrame.Angles(0, 0, rad(s.DeadArm * 0.8))
	out.Neck = CFrame.Angles(0, 0, rad(s.DeadNeck))
	out.Head = CFrame.Angles(rad(s.DeadHeadRoll), 0, rad(s.DeadHead))
	out.Jaw = CFrame.Angles(0, 0, rad(s.DeadJaw))
	for i = 1, 5 do
		out["Tail" .. i] = CFrame.Angles(0, 0, rad(s.DeadTail))
	end
	return out
end

function DeadPose.settings(model)
	local s = {}
	for k, v in pairs(DeadPose.Defaults) do
		local a = model and model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return DeadPose
