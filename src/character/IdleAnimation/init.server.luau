-- IdleAnimation v1.21 (Dino Arcade): idle + walk animation for this model, on each player's client.
-- v1.1: RunContext = Client (joint motion from the server is not shown to players).
-- v1.2: joints are picked up as they stream in; model uses Atomic streaming.
-- v1.3: occasional head turn to the side (IdleLook* attributes).
-- v1.4: walk cycle (WalkPose) blended in from measured movement; feet timed to distance travelled.
-- v1.5: leg geometry (hip height, heel, toe) measured from the model's LegL; speed smoothed so the
--       idle/walk blend does not flicker. RigHipHeight is now only a fallback before LegL loads.
-- v1.6: rig v1.2 (Knee/Ankle joints). Leg + foot geometry measured across LegL/ShinL/FootL and handed
--       to WalkPose v2.0 (knee IK). Walking needs the Knee/Ankle joints; without them WalkState = "noKnees".
-- v1.7: passes the rest hip positions to WalkPose v2.1 (body-sway compensation for planted feet).
-- v1.8: run gait (WalkPose v3.0). Gait blend = where the smoothed speed sits between the
--       MoveWalkSpeed and MoveRunSpeed attributes (defaults 16 / 28): 0 = walk, 1 = run.
-- v1.9: roar (RoarPose) layered on the upper body while RoarStartedAt (server time, set by RoarServer)
--       is within RoarDuration; the idle head-turn is suppressed during the roar.
-- v1.10: creep (WalkPose v3.1). Creep blend follows the character attribute Creeping (set by CreepServer,
--       replicated to every client): 0 = upright, 1 = creeping. Moving: creep gait mixed into the walk
--       cycle. Standing still: lower body (RootJoint, hips, knees, ankles) blends to the crouched stance
--       (WalkPose.stance); upper body (neck, head, arms, Tail1) adds the stance offset on top of idle motion.
-- v1.11: bite (BitePose) layered on the upper body after the roar layer. Start = BiteStartedAt (server time,
--       set by BiteServer); on the local player's own character a newer BitePredictedAt (set by BiteTest at
--       the click) is used until the server stamp arrives, so the attacker sees the wind-up at once.
--       Hit = BiteHitAt (server) at or after the start: the pose clock holds for BiteHitStop, then the head
--       thrashes. The idle head-turn is suppressed during the bite.
-- v1.12: (a) turning only counts as stepping when the body is (nearly) standing: the turn term fades out
--       between 0 and TURN_STEP_FADE studs/s of real movement, so the legs no longer speed up during
--       running turns. (b) TurnPose: neck + head lean into turns while moving (smoothed turn rate,
--       scaled by the walk blend), layered after the walk blend and before the roar / bite layers.
-- v1.13: tail phase advanced separately at WalkTailRate of the step rate (WalkPose 3.2), so the moving tail
--       swings at half speed; idle tail uses IdleTailPeriod (IdlePose 1.4).
-- v1.14: HeadLeadPose 1.0: neck + head turn toward where the dino is going before the body does (moving and
--       standing), layered after TurnPose and before the roar / bite layers. Input = the turn still to go:
--       TurnErrorLocal on the local player's own character (set by TurnLimit 1.0), otherwise TurnError
--       (replicated by TurnServer 1.0). Clamped to HeadLeadMax, smoothed by HeadLeadSmooth, faded to 0
--       during the roar and the bite.
--       Diagnostics: HeadLead (degrees, whole), HeadLeadSource = "local" / "server" / "none",
--       HeadLeadState = "off" / "none" / "leading" / "suppressed" (roar or bite).
-- v1.15: leap (JumpPose 1.0), only on models with JumpEnabled = true (the T-Rex is unchanged). Start = JumpStartedAt
--       (server time, set by JumpServer 1.0); on the local player's own character a newer JumpPredictedAt (set by
--       JumpTest 1.0 at the press) is used, and a start that JumpServer denied (JumpDeniedAt == start) is dropped.
--       Airborne = a ground raycast under the HumanoidRootPart (gap above HipHeight > 0.6 studs; grounded again
--       below 0.25), so every client sees the same phases. Vertical speed = smoothed HRP height change.
--       Phases: crouch (0 .. JumpWindup) -> push (launched, still touching) -> rise / fall (airborne) -> land
--       (JumpLandTime after touching down). The jump pose replaces the idle + walk pose by the jump weight
--       (1 in crouch / air, fading out through the landing) and is layered before TurnPose, HeadLeadPose, roar
--       and bite. Gives up JUMP_LIFTOFF_WAIT s after the windup without leaving the ground, or JUMP_MAX_TIME s
--       after the start.
--       Diagnostics: JumpState = "none" / "crouch" / "push" / "rise" / "fall" / "land", JumpBlend (0..1, 0.1 steps),
--       JumpSource = "server" / "predicted", JumpGroundDist (studs above the ground, 0.1 steps; while a jump runs).
-- v1.16: pounce (PouncePose 1.0), only on models with PounceEnabled = true (raptor). Start = PounceStartedAt (server,
--       PounceServer 1.0), or a newer PouncePredictedAt on the owner's client; a denied start is dropped.
--       Phases: wind-up (0 .. PounceWindup: JumpPose.crouch) -> lunge (PouncePose.lunge; on other clients until the
--       body is back on the ground, at most 1 s) -> latched (PouncePose.latch while PounceLatched; jaws snap at each
--       PounceBiteAt) -> release (the last latched pose fades out over 0.25 s). The owner's client uses its own
--       PounceLocalState (PounceTest 1.0) so the pose follows its prediction. Layered after the jump layer, before
--       TurnPose; the head lead is suppressed while it runs (like roar and bite).
--       Diagnostics: PounceState = "none" / "windup" / "lunge" / "latched" / "release", PounceBlend (0..1, 0.1 steps),
--       PounceSource = "server" / "predicted".
-- v1.17: move direction (WalkPose 3.4). The horizontal movement measured each frame is taken in the body frame (the
--       RootJoint's rest frame on the HumanoidRootPart: +X forward, +Z right) as an angle (0 = forward, 90 = right,
--       -90 = left, 180 = backward), smoothed (MOVE_DIR_RATE) along the shorter way round and handed to WalkPose.get,
--       so strafing side-steps and backing up steps backward. Below MOVE_DIR_MIN_SPEED studs/s (standing, turning in
--       place) the direction eases back to forward. WalkDirectional = false keeps the v1.16 forward-only stepping.
--       Diagnostic: MoveDir (degrees, whole).
-- v1.18: bite dip (BitePose 1.1): the bite layer gets the model attribute BiteDip (server, BiteServer 1.5 /
--       BotServer 1.2), or BiteDipPredicted while this client shows its own predicted bite (BiteTest 1.3).
-- v1.19: tree ram + stun (RamPose 1.0). Ram layer (models with RamEnabled = true): multiplied on after the head lead,
--       before the roar / bite layers; the head lead is suppressed while it runs. Phase on the owner's client from
--       RamLocalState (RamTest 1.0: windup from RamPredictedAt, charge, recoil from RamLocalImpactAt, then a RAM_FADE s
--       fade after RamLocalEndAt); on every other client from the server stamps: RamStartedAt (RamDeniedAt == it
--       cancels), windup for RamWindup s, then charge until RamEndedAt; impact for RamPose.RECOIL s after RamImpactAt
--       (>= the start), or a RAM_FADE s fade after an end without impact. Stun layer (every model): while StunnedUntil
--       (server time) is in the future the stun flailing (legs kick, head wobbles) is multiplied on last, blended in and
--       out at STUN_BLEND_RATE per second. Diagnostics: RamState ("none" / "windup" / "charge" / "impact" / "fade"),
--       RamSource ("local" / "server"), StunPose ("none" / "kicking"), StunBlend (0..1, 0.1 steps).
-- v1.20: eat / drink (EatPose 1.0). The model attribute SurvivalAction (SurvivalServer 1.0, replicated: "eating" /
--       "drinking" / "none") drives an eat weight that blends toward 1 at EatBlendRate per second while an action runs
--       and back to 0 after it stops (the last kind keeps playing through the fade). The loop clock starts when an
--       action starts (local clock). The eat pose replaces the pose by the eat weight after the jump / pounce layers
--       and before TurnPose; the idle head-turn and the head lead are suppressed while the weight is above 0.01.
--       Off with EatPoseEnabled = false. Diagnostics: EatPoseState ("none" / "eating" / "drinking" / "fade"),
--       EatPoseBlend (0..1, 0.1 steps).
--       Reach: the lowest point of the Head + Jaw parts (measured each frame, so it shows last frame's pose) is steered
--       to a target height by an extra neck dip (eatReach, degrees): drink = lake surface (DinoIsland.Ground.LakeWater
--       top) - EatPose.DRINK_SINK; eat = the top of the carcass named by SurvivalNearCarcass (Workspace.DinoCarcasses,
--       world box of its parts, cached per carcass). eatReach += (lowest - target) x REACH_GAIN degrees per stud, at
--       REACH_RATE per second, within EatPose.REACH_MIN .. REACH_MAX; reset to 0 when an action starts; eased to 0
--       when there is no target. Diagnostics: EatReach (degrees, whole), EatMouthGap (lowest - target, 0.1 steps).
-- v1.21: (a) eat / drink phases (EatPose 1.1, SurvivalServer 1.1). When the model has SurvivalPhase (server: "none" /
--       "lowering" / "eating" / "drinking" / "rising", with SurvivalKind "eat" / "drink", SurvivalPhaseAt (server time),
--       SurvivalEnterTime, SurvivalRiseTime) the v1.20 SurvivalAction path is skipped and the layer follows the phase:
--       lowering -> EatPose.enter(kind, t / SurvivalEnterTime) (weight, hover -> in mix, motion); eating / drinking ->
--       weight 1, mouth in, EatPose.loop(kind, t); rising -> the pose held at the moment the phase began (weight, mix,
--       motion) eased out over SurvivalRiseTime; none (interrupted, dead, disabled) -> the held pose fades out at
--       INTERRUPT_FADE per second. So the mouth reaches the water / carcass exactly when the server starts the refill.
--       Reach (replaces the v1.20 feedback on this path): solved, not chased. Forward kinematics from the
--       HumanoidRootPart through the motors that lead to the Head and Jaw segments (C0 = restC0 x pose, C1) give the
--       lowest point of the visible Head + Jaw parts (their offsets from their segment Root, measured once) for any
--       pose; the extra neck dip that puts that point on a target is found by bisection (REACH_ITERS steps) within
--       EatPose.REACH_MIN .. REACH_MAX, for the "in" target (drink: LakeWater top - EatPose.DRINK_SINK_IN; eat: carcass
--       top - EatPose.EAT_SINK; drink over the bank: never below the ground under the head + 0.2) and the hover target
--       (+ DRINK_HOVER / EAT_HOVER), re-solved when the body or the target
--       moves (REACH_RESOLVE_MOVE studs / REACH_RESOLVE_TURN degrees). reach = lerp(hover, in, mix).
--       Aim (eat): the neck turns toward the carcass centre (angle in the body frame from the Neck segment's Root, within
--       EatPose.AIM_MAX, eased at AIM_RATE per second; 0 for drinking); the reach is solved with that aim. EatAim (deg).
--       Diagnostics: EatPoseState adds "lowering" / "rising"; EatReach = the reach used; EatReachIn / EatReachHover;
--       EatMouthGap = measured lowest Head + Jaw point - the in target (only while fully in).
--   (b) dead pose (DeadPose 1.0): while the Humanoid is dead (Health <= 0) or the model's DummyState is "ko" (knocked-out
--       bots, BiteDummy) the dead pose replaces the pose by a weight that blends toward 1 at DeadBlendRate per second
--       (and back to 0 when the model is up again); applied last, after the stun layer. Off with DeadPoseEnabled =
--       false. Diagnostics: DeadPoseState ("none" / "dead" / "fade"), DeadPoseBlend (0..1, 0.1 steps).
-- Tune with model attributes: Idle*, IdleLook*, Walk*, Run* (see WalkPose.Defaults), MoveWalkSpeed, MoveRunSpeed.
-- Rig attribute: RigHipHeight (hip-to-ground studs at scale 1; multiplied by model scale).
-- Diagnostics (client-side attributes): IdleState, IdleJointCount, IdleLookState,
--   MoveState = "idle" / "walking" / "running", GaitBlend (0 walk .. 1 run, 0.1 steps), MoveSpeed (smoothed studs/s, 0.5 steps), WalkBlend (0..1, 0.1 steps),
--   RigLegLength / RigHeelX / RigToeX (measured leg geometry, studs, 0.01 steps),
--   WalkState = "ready" / "noKnees", RigFootToe / RigAnkleHeight (foot geometry at the ankle),
--   RoarState = "none" / "windup" / "roaring" / "recover",
--   CreepBlend (0..1, 0.1 steps). MoveState adds "creeping" (moving, CreepBlend > 0.5) and
--   "crouched" (not moving, CreepBlend > 0.5),
--   BiteState = "none" / "windup" / "strike" / "recover" (+ "-hit" when the bite landed),
--   BiteSource = "server" / "predicted" (which start time the current bite uses),
--   TurnRate (smoothed, degrees/s, positive = left, 10 steps), TurnHead (head turn amount, degrees).
local RunService = game:GetService("RunService")
local model = script.Parent
local IdlePose = require(script.IdlePose)
local WalkPose = require(script.WalkPose)
local RoarPose = require(script.RoarPose)
local BitePose = require(script.BitePose)
local TurnPose = require(script.TurnPose)
local HeadLeadPose = require(script.HeadLeadPose)
local JumpPose = require(script.JumpPose) -- v1.15 (defaults are read by JumpPose.settings, not written to the model)
local PouncePose = require(script.PouncePose) -- v1.16 (defaults are read by PouncePose.settings)
local RamPose = require(script.RamPose) -- v1.19 (defaults are read by RamPose.settings)
local EatPose = require(script.EatPose) -- v1.20 (defaults are read by EatPose.settings)
local DeadPose = require(script.DeadPose) -- v1.21 (defaults are read by DeadPose.settings)
local Players = game:GetService("Players")

for _, defaults in ipairs({IdlePose.Defaults, WalkPose.Defaults, RoarPose.Defaults, BitePose.Defaults, TurnPose.Defaults, HeadLeadPose.Defaults}) do
	for k, v in pairs(defaults) do
		if model:GetAttribute(k) == nil then model:SetAttribute(k, v) end
	end
end

local WALK_START_SPEED = 0.5  -- studs/s of smoothed movement that counts as walking
local BLEND_RATE = 6          -- how fast idle <-> walk blends (per second)
local SPEED_SMOOTH = 8        -- how fast the measured speed follows the raw value (per second)
local TELEPORT_DIST = 20      -- larger single-frame jumps are ignored (respawn / teleport)
local GAIT_RATE = 4           -- how fast the walk <-> run blend follows speed (per second)
local DEFAULT_WALK_SPEED, DEFAULT_RUN_SPEED = 16, 28
local CREEP_RATE = 5          -- how fast upright <-> creep blends (per second)
local TURN_STEP_FADE = 6      -- studs/s of real movement above which turning adds no stepping
local MOVE_DIR_RATE = 10      -- v1.17: how fast the step direction follows the move direction (per second)
local MOVE_DIR_MIN_SPEED = 2  -- v1.17: studs/s of real movement below which the step direction eases to forward
-- stance joints that blend (replace) vs. add on top of idle motion
local STANCE_LOWER = {RootJoint = true, LegL = true, LegR = true, KneeL = true, KneeR = true, AnkleL = true, AnkleR = true}

local motors = {}
local start = os.clock()
local look = IdlePose.newLook(os.clock(), IdlePose.settings(model))
local hrp, lastPos, lastYaw
local walkPhase, blend, smoothSpeed, gaitBlend = 0, 0, 0, 0
local creepBlend = 0
local smoothTurnRate = 0      -- degrees/s, positive = turning left
local tailPhase = 0           -- tail swing phase while moving (radians)
local moveDir = 0             -- v1.17: smoothed move direction in the body frame (radians, 0 = forward, + = right)
local headLead = 0            -- smoothed head lead (degrees, positive = left)
local jump -- v1.15: current leap {start, source, air, landAt}
local jumpLastY, jumpVy = nil, 0 -- v1.15: HRP height last frame, smoothed vertical speed
local JUMP_LIFTOFF_WAIT = 0.35 -- v1.15: s after the windup to leave the ground
local JUMP_MAX_TIME = 4        -- v1.15: s after the start a leap is given up
local JUMP_VY_SMOOTH = 20      -- v1.15: vertical speed smoothing (per second)
local jumpParams = RaycastParams.new() -- v1.15: ground probe (ignores this model)
jumpParams.FilterType = Enum.RaycastFilterType.Exclude
jumpParams.FilterDescendantsInstances = {model}
local pounceLatchClock, pounceLetGoAt, pounceLast -- v1.16: local latch start, let-go time, last latched pose
local RAM_FADE = 0.25        -- v1.19: s the ram pose eases out after a charge that missed
local STUN_BLEND_RATE = 8    -- v1.19: how fast the stun flailing blends in / out (per second)
local stunBlend = 0          -- v1.19
local eatW, eatKind, eatClock = 0, nil, 0 -- v1.20: eat / drink weight, last kind ("eat" / "drink"), loop start
local eatReach = 0 -- v1.20: extra neck dip (degrees) that brings the mouth to the target
local REACH_GAIN = 6 -- v1.20: degrees of neck dip per stud the mouth is off the target
local REACH_RATE = 3 -- v1.20: how fast the reach follows (per second)
local mouthParts -- v1.20: Head + Jaw parts (visible)
local carcassTop = {} -- v1.20: [carcass name] = top Y of its world box

-- v1.20: lowest point of the visible Head + Jaw parts (world Y)
local function mouthLowest()
	if not mouthParts then
		local list = {}
		for _, n in ipairs({"Head", "Jaw"}) do
			local seg = model:FindFirstChild(n)
			if seg then
				for _, p in ipairs(seg:GetDescendants()) do
					if p:IsA("BasePart") and p.Transparency < 1 then table.insert(list, p) end
				end
			end
		end
		if #list == 0 then return nil end
		mouthParts = list
	end
	local low = math.huge
	for _, p in ipairs(mouthParts) do
		local cf, h = p.CFrame, p.Size / 2
		local ext = math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
		low = math.min(low, p.Position.Y - ext)
	end
	return low
end

-- v1.21 ------------------------------------------------------------------------------------------------------------
local INTERRUPT_FADE = 10      -- v1.21: per second the held eat pose fades after an interrupted / cancelled action
local REACH_ITERS = 14         -- v1.21: bisection steps
local REACH_RESOLVE_MOVE = 0.05 -- v1.21: studs the body / target may move before the reach is solved again
local REACH_RESOLVE_TURN = 0.5 -- v1.21: degrees the body may turn before the reach is solved again
local e21 = {w = 0, mix = 1, m = nil, kind = nil, riseAt = nil, riseFrom = nil, reachIn = 0, reachHover = 0, key = nil,
	aim = 0}
local AIM_RATE = 6             -- v1.21: how fast the neck turns toward the carcass (per second)
local deadW = 0                -- v1.21: dead pose weight
local fk                       -- v1.21: {Head = {joints, parts}, Jaw = {...}} (nil until built)

-- v1.21: chain of motors from the HumanoidRootPart to each mouth segment + the visible parts' offsets from its Root
local function buildFK(hrpPart)
	local segs = {}
	for _, segName in ipairs({"Head", "Jaw"}) do
		local seg = model:FindFirstChild(segName)
		local root = seg and seg:FindFirstChild("Root")
		if not root then return nil end
		local joints, part, guard = {}, root, 0
		while part ~= hrpPart do
			guard += 1
			if guard > 12 then return nil end
			local found
			for name, e in pairs(motors) do
				if e.motor.Part1 == part then found = name break end
			end
			if not found then return nil end
			table.insert(joints, 1, found)
			part = motors[found].motor.Part0
			if not part then return nil end
		end
		local parts = {}
		for _, p in ipairs(seg:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p ~= root then
				table.insert(parts, {off = root.CFrame:Inverse() * p.CFrame, half = p.Size / 2})
			end
		end
		segs[segName] = {joints = joints, parts = parts}
	end
	return segs
end

-- v1.21: lowest point of the visible Head + Jaw parts if the given pose were shown (forward kinematics)
local function mouthLowFK(hrpCF, pose)
	local low = math.huge
	for _, sg in pairs(fk) do
		local cf = hrpCF
		for _, name in ipairs(sg.joints) do
			local e = motors[name]
			cf = cf * e.restC0 * (pose[name] or CFrame.identity) * e.motor.C1:Inverse()
		end
		for _, pt in ipairs(sg.parts) do
			local w = cf * pt.off
			local h = pt.half
			local ext = math.abs(w.RightVector.Y) * h.X + math.abs(w.UpVector.Y) * h.Y + math.abs(w.LookVector.Y) * h.Z
			low = math.min(low, w.Position.Y - ext)
		end
	end
	return low
end

-- v1.21: extra neck dip that puts the mouth's lowest point at targetY (motion-free pose)
local function solveReach(kind, es, ws, g, hrpCF, targetY, aim) -- g = the knee IK geometry (geo is declared further down)
	local function f(r)
		return mouthLowFK(hrpCF, EatPose.pose(kind, es, ws, g, WalkPose.stance, r, nil, aim)) - targetY
	end
	local lo, hi = EatPose.REACH_MIN, EatPose.REACH_MAX
	if f(lo) <= 0 then return lo end -- even the least dip is at / below the target
	if f(hi) >= 0 then return hi end -- even the most dip does not reach it
	for _ = 1, REACH_ITERS do
		local mid = (lo + hi) / 2
		if f(mid) > 0 then lo = mid else hi = mid end
	end
	return (lo + hi) / 2
end

-- v1.21: "in" target height (drink: under the water surface; eat: into the carcass); nil = none
local function eatTargetY21(kind)
	if kind == "drink" then
		local island = workspace:FindFirstChild("DinoIsland")
		local ground = island and island:FindFirstChild("Ground")
		local w = ground and ground:FindFirstChild("LakeWater")
		if not w then return nil end
		local y = w.Position.Y + w.Size.Y / 2 - EatPose.DRINK_SINK_IN
		-- the head over the bank (higher ground than the water): the mouth stops just on the ground there
		local headSeg = model:FindFirstChild("Head")
		if headSeg and headSeg:IsA("Model") then
			local hp = headSeg:GetBoundingBox().Position
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {ground}
			local hit = workspace:Raycast(Vector3.new(hp.X, hp.Y + 20, hp.Z), Vector3.new(0, -80, 0), params)
			if hit and hit.Position.Y + 0.2 > y then y = hit.Position.Y + 0.2 end
		end
		return y
	end
	local name = model:GetAttribute("SurvivalNearCarcass")
	local folder = workspace:FindFirstChild("DinoCarcasses")
	local c = folder and type(name) == "string" and name ~= "" and folder:FindFirstChild(name)
	if not c then return nil end
	local top = -math.huge
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			local ext = math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
			top = math.max(top, p.Position.Y + ext)
		end
	end
	if top == -math.huge then return nil end
	return top - EatPose.EAT_SINK
end

-- v1.20: target height for the mouth (nil = none)
local function eatTargetY(kind)
	if kind == "drink" then
		local island = workspace:FindFirstChild("DinoIsland")
		local ground = island and island:FindFirstChild("Ground")
		local w = ground and ground:FindFirstChild("LakeWater")
		return w and (w.Position.Y + w.Size.Y / 2 - EatPose.DRINK_SINK) or nil
	end
	local name = model:GetAttribute("SurvivalNearCarcass")
	local folder = workspace:FindFirstChild("DinoCarcasses")
	local c = folder and type(name) == "string" and name ~= "" and folder:FindFirstChild(name)
	if not c then return nil end
	if not carcassTop[name] then
		local top = -math.huge
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				local cf, h = p.CFrame, p.Size / 2
				local ext = math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
				top = math.max(top, p.Position.Y + ext)
			end
		end
		if top == -math.huge then return nil end
		carcassTop[name] = top
	end
	return carcassTop[name]
end
local rig -- {L, heelX, toeX}, measured once from the left leg chain
local geo -- WalkPose.buildGeo result (knee IK), built once Knee/Ankle joints are present
local shown = {}

-- Measures parts of the given segments in the frame of rootPart: sole depth (L) and the sole's
-- rear/front X. Done once at rest (idle never moves the knee/ankle), so values are pose-independent.
local function measureSegs(rootPart, segNames)
	local corners = {}
	for _, name in ipairs(segNames) do
		local seg = model:FindFirstChild(name)
		if seg then
			for _, p in ipairs(seg:GetChildren()) do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					local h = p.Size / 2
					for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
						table.insert(corners, rootPart.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
					end end end
				end
			end
		end
	end
	if #corners == 0 then return nil end
	local minY = math.huge
	for _, c in ipairs(corners) do minY = math.min(minY, c.Y) end
	local heelX, toeX = math.huge, -math.huge
	for _, c in ipairs(corners) do
		if c.Y < minY + 0.6 then -- sole-level corners (foot + claws)
			heelX, toeX = math.min(heelX, c.X), math.max(toeX, c.X)
		end
	end
	return {L = -minY, heelX = heelX, toeX = toeX}
end

-- Whole left leg (thigh + shin + foot) measured from the hip.
local function measureRig()
	local seg = model:FindFirstChild("LegL")
	local root = seg and seg:FindFirstChild("Root")
	if not root then return nil end
	return measureSegs(root, {"LegL", "ShinL", "FootL"})
end

-- Knee IK geometry from the rest joint offsets + the foot measured at the ankle.
local function buildGeo()
	local knee, ankle, hipL, hipR = motors.KneeL, motors.AnkleL, motors.LegL, motors.LegR
	local footSeg = model:FindFirstChild("FootL")
	local ankleRoot = footSeg and footSeg:FindFirstChild("Root")
	if not (knee and ankle and hipL and hipR and ankleRoot) then return nil end
	local f = measureSegs(ankleRoot, {"FootL"})
	if not f then return nil end
	return WalkPose.buildGeo(knee.restC0, ankle.restC0, {toe = f.toeX, ankleHeight = f.L},
		hipL.restC0.Position, hipR.restC0.Position)
end

local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		model:SetAttribute(attr, value)
	end
end

local function refresh()
	if IdlePose.addMissing(model, motors) > 0 then
		show("IdleJointCount", IdlePose.count(motors))
	end
end
refresh()
model.DescendantAdded:Connect(function(d)
	if d:IsA("Motor6D") then refresh() end
end)

local function yawOf(cf)
	local f = cf.RightVector -- model faces +X
	return math.atan2(-f.Z, f.X)
end

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

RunService.PreSimulation:Connect(function(dt)
	local s = IdlePose.settings(model)
	if not s.IdleEnabled then
		if shown.IdleState ~= "disabled" then
			IdlePose.reset(motors)
			show("IdleState", "disabled")
		end
		return
	end
	if next(motors) == nil then
		show("IdleState", "waiting")
		return
	end

	local ws = WalkPose.settings(model)
	if not rig then
		rig = measureRig()
		if rig then
			show("RigLegLength", math.floor(rig.L * 100 + 0.5) / 100)
			show("RigHeelX", math.floor(rig.heelX * 100 + 0.5) / 100)
			show("RigToeX", math.floor(rig.toeX * 100 + 0.5) / 100)
		end
	end
	if not geo then
		geo = buildGeo()
		if geo then
			show("WalkState", "ready")
			show("RigFootToe", math.floor(geo.toe * 100 + 0.5) / 100)
			show("RigAnkleHeight", math.floor(geo.ankleHeight * 100 + 0.5) / 100)
		else
			show("WalkState", "noKnees")
		end
	end
	local fallbackL = (model:GetAttribute("RigHipHeight") or 7.65) * model:GetScale()
	local r = rig or {L = fallbackL, heelX = 0, toeX = 0}
	local legLen = r.L

	-- measure movement (works for anchored test movement and physics movement alike)
	hrp = hrp or model:FindFirstChild("HumanoidRootPart")
	local effDist = 0
	local turnRate = 0
	local dirTarget = 0 -- v1.17
	if hrp then
		local pos, yaw = hrp.Position, yawOf(hrp.CFrame)
		if lastPos then
			local d = Vector3.new(pos.X - lastPos.X, 0, pos.Z - lastPos.Z).Magnitude
			if d < TELEPORT_DIST then
				local dYaw = wrapAngle(yaw - lastYaw)
				if dt > 0 then turnRate = math.deg(dYaw) / dt end
				-- turning in place counts as stepping (half a leg length per radian); the share fades out
				-- as real movement grows, so running turns do not speed the legs up
				local moveSpeed = dt > 0 and d / dt or 0
				local turnWeight = math.clamp(1 - moveSpeed / TURN_STEP_FADE, 0, 1)
				effDist = d + math.abs(dYaw) * legLen * 0.5 * turnWeight
				-- v1.17: move direction in the body frame (RootJoint rest frame: +X forward, +Z right)
				local rj = motors.RootJoint
				if rj and moveSpeed > MOVE_DIR_MIN_SPEED and model:GetAttribute("WalkDirectional") ~= false then
					local bodyCF = hrp.CFrame * rj.restC0
					local mv = Vector3.new(pos.X - lastPos.X, 0, pos.Z - lastPos.Z)
					dirTarget = math.atan2(mv:Dot(bodyCF.ZVector), mv:Dot(bodyCF.XVector))
				end
			end
		end
		lastPos, lastYaw = pos, yaw
	end
	local ts = TurnPose.settings(model)
	smoothTurnRate += (turnRate - smoothTurnRate) * math.min(1, dt * ts.TurnHeadSmooth)
	moveDir += wrapAngle(dirTarget - moveDir) * math.min(1, dt * MOVE_DIR_RATE) -- v1.17
	moveDir = wrapAngle(moveDir)
	if dirTarget == 0 and math.abs(moveDir) < 1e-3 then moveDir = 0 end
	local speed = dt > 0 and effDist / dt or 0
	smoothSpeed += (speed - smoothSpeed) * math.min(1, dt * SPEED_SMOOTH)
	local target = (ws.WalkEnabled and geo and smoothSpeed > WALK_START_SPEED) and 1 or 0
	blend += (target - blend) * math.min(1, dt * BLEND_RATE)
	-- walk <-> run blend from where the speed sits between the walk and run speeds
	local walkSpd = model:GetAttribute("MoveWalkSpeed") or DEFAULT_WALK_SPEED
	local runSpd = model:GetAttribute("MoveRunSpeed") or DEFAULT_RUN_SPEED
	local gaitTarget = runSpd > walkSpd and math.clamp((smoothSpeed - walkSpd) / (runSpd - walkSpd), 0, 1) or 0
	gaitBlend += (gaitTarget - gaitBlend) * math.min(1, dt * GAIT_RATE)
	-- upright <-> creep from the replicated Creeping attribute
	local creepTarget = (model:GetAttribute("Creeping") == true and geo) and 1 or 0
	creepBlend += (creepTarget - creepBlend) * math.min(1, dt * CREEP_RATE)
	if creepTarget == 0 and creepBlend < 0.001 then creepBlend = 0 end
	if effDist > 0 and geo then
		local dPhase = effDist / WalkPose.stride(ws, geo, gaitBlend, creepBlend) * 2 * math.pi
		walkPhase = (walkPhase + dPhase) % (2 * math.pi)
		tailPhase = (tailPhase + dPhase * ws.WalkTailRate) % (2 * math.pi)
	end

	-- roar progress (server-time stamp so every client is in sync)
	local rs = RoarPose.settings(model)
	local roarF
	local roarStarted = model:GetAttribute("RoarStartedAt")
	if rs.RoarEnabled and roarStarted then
		local t = workspace:GetServerTimeNow() - roarStarted
		if t >= 0 and t <= rs.RoarDuration then roarF = t / rs.RoarDuration end
	end

	-- bite progress: server stamp, or the local prediction on the attacker's own client
	local bs = BitePose.settings(model)
	local biteT, biteHitT, biteSource
	if bs.BiteEnabled then
		local bStart = model:GetAttribute("BiteStartedAt")
		biteSource = "server"
		local predicted = model:GetAttribute("BitePredictedAt")
		local lp = Players.LocalPlayer
		if predicted and lp and lp.Character == model and (not bStart or predicted > bStart + 0.001) then
			bStart, biteSource = predicted, "predicted"
		end
		if bStart then
			local serverNow = workspace:GetServerTimeNow()
			local t = serverNow - bStart
			local hitAt = model:GetAttribute("BiteHitAt")
			if hitAt and hitAt >= bStart - 0.001 then
				biteHitT = math.max(0, hitAt - bStart)
				if t > biteHitT then t = biteHitT + math.max(0, t - biteHitT - bs.BiteHitStop) end
			end
			if t >= 0 and t <= BitePose.duration(bs) then biteT = t end
		end
	end

	-- v1.20: eat / drink weight from the replicated SurvivalAction
	local now = os.clock()
	local es = EatPose.settings(model)
	local phase21 = model:GetAttribute("SurvivalPhase") -- v1.21: SurvivalServer 1.1 phases (nil = the v1.20 path)
	local action = model:GetAttribute("SurvivalAction")
	local eatTarget = 0
	if phase21 == nil then
		if es.EatPoseEnabled and geo and (action == "eating" or action == "drinking") then
			local kind = action == "eating" and "eat" or "drink"
			if eatKind ~= kind or eatW < 0.01 then eatClock, eatReach = now, 0 end
			eatKind, eatTarget = kind, 1
		end
		eatW += (eatTarget - eatW) * math.min(1, dt * es.EatBlendRate)
		if eatTarget == 0 and eatW < 0.01 then eatW = 0 end
	else -- v1.21: the phase sets the weight, mix and motion
		local kind = model:GetAttribute("SurvivalKind")
		local serverNow = workspace:GetServerTimeNow()
		local at = model:GetAttribute("SurvivalPhaseAt") or serverNow
		local tt = serverNow - at
		local valid = es.EatPoseEnabled and geo ~= nil and (kind == "eat" or kind == "drink")
		if valid and phase21 == "lowering" then
			e21.w, e21.mix, e21.m = EatPose.enter(kind, tt / math.max(0.05, model:GetAttribute("SurvivalEnterTime") or 1), es)
			e21.kind, e21.riseAt = kind, nil
			eatTarget = 1
		elseif valid and (phase21 == "eating" or phase21 == "drinking") then
			e21.w, e21.mix, e21.m = 1, 1, EatPose.loop(kind, tt, es)
			e21.kind, e21.riseAt = kind, nil
			eatTarget = 1
		elseif valid and phase21 == "rising" then
			if e21.riseAt ~= at then
				e21.riseAt = at
				e21.riseFrom = {w = e21.w, mix = e21.mix, m = e21.m}
			end
			local r = math.clamp(tt / math.max(0.05, model:GetAttribute("SurvivalRiseTime") or 0.5), 0, 1)
			e21.w = e21.riseFrom.w * (1 - r * r * (3 - 2 * r))
			e21.mix, e21.m, e21.kind = e21.riseFrom.mix, e21.riseFrom.m, e21.kind or kind
		else
			e21.w = math.max(0, e21.w - dt * INTERRUPT_FADE)
			e21.riseAt = nil
		end
		eatW, eatKind = e21.w, e21.kind
		if eatW < 0.01 then eatW = 0 end
	end
	local eatActive = eatW > 0.01 and eatKind ~= nil
	-- idle (head-turn fades out while walking, roaring, biting or eating), then blend toward walk
	local lookYaw, lookPhase = IdlePose.updateLook(look, now, s)
	local pose = IdlePose.get(now - start, s, lookYaw * (1 - blend) * ((roarF or biteT or eatActive) and 0 or 1))
	-- crouched stance while creeping in place
	if creepBlend > 0.001 and geo then
		local stance = WalkPose.stance(ws, geo)
		for name, off in pairs(stance) do
			if motors[name] then
				local cur = pose[name] or CFrame.identity
				if STANCE_LOWER[name] then
					pose[name] = cur:Lerp(off, creepBlend)
				else
					pose[name] = cur * CFrame.identity:Lerp(off, creepBlend)
				end
			end
		end
	end
	if blend > 0.001 and geo then
		local walk = WalkPose.get(walkPhase, ws, geo, gaitBlend, creepBlend, tailPhase, moveDir) -- v1.17: + direction
		for name in pairs(motors) do
			pose[name] = (pose[name] or CFrame.identity):Lerp(walk[name] or CFrame.identity, blend)
		end
	end
	-- v1.15: leap (crouch / air / land) replaces the idle + walk pose by the jump weight
	local jumpState, jumpW = "none", 0
	if hrp and geo and model:GetAttribute("JumpEnabled") == true then
		local js = JumpPose.settings(model)
		local serverNow = workspace:GetServerTimeNow()
		-- start stamp: server, or the local prediction on the owner's client
		local jStart, jSource = model:GetAttribute("JumpStartedAt"), "server"
		local jPred = model:GetAttribute("JumpPredictedAt")
		local lp = Players.LocalPlayer
		if jPred and lp and lp.Character == model and (not jStart or jPred > jStart + 0.001) then
			jStart, jSource = jPred, "predicted"
		end
		if jStart and model:GetAttribute("JumpDeniedAt") == jStart then jStart = nil end
		if jStart and (not jump or (jStart > jump.start + 0.001 and not
			(jump.source == "predicted" and jSource == "server" and jStart - jump.start < 0.5))) then
			jump = {start = jStart, source = jSource, air = false}
		end
		-- vertical speed from the HRP height change (works for every client)
		local y = hrp.Position.Y
		if jumpLastY and dt > 0 and math.abs(y - jumpLastY) < TELEPORT_DIST then
			jumpVy += ((y - jumpLastY) / dt - jumpVy) * math.min(1, dt * JUMP_VY_SMOOTH)
		end
		jumpLastY = y
		if jump and not jump.done then
			local t = serverNow - jump.start
			local W = model:GetAttribute("JumpWindup") or 0.12
			local power = model:GetAttribute("JumpLaunchPower") or 59
			-- ground gap under the body (nil = no ground within 40 studs)
			local hum = model:FindFirstChildOfClass("Humanoid")
			local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
			local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(base + 40), 0), jumpParams)
			local gap = hit and (y - hit.Position.Y - base) or nil
			show("JumpGroundDist", gap and math.floor(gap * 10 + 0.5) / 10 or 99)
			local airborne = gap == nil or gap > (jump.air and 0.25 or 0.6)
			if not jump.air and airborne and t >= 0 then jump.air = true end
			if jump.air and not jump.landAt and not airborne then jump.landAt = now end
			local jp
			if t > JUMP_MAX_TIME or t < -0.05 then
				jump.done = true
			elseif jump.landAt then
				local u = (now - jump.landAt) / math.max(0.01, js.JumpLandTime)
				if u < 1 then
					jp = JumpPose.land(u, js, geo)
					jumpW, jumpState = 1 - u * u * (3 - 2 * u), "land"
				else
					jump.done = true
				end
			elseif jump.air then
				local fall = math.clamp(-jumpVy / (power * 0.5), 0, 1)
				jp = JumpPose.air(math.max(0, t - W), fall, jumpVy / power, js, geo)
				jumpW, jumpState = 1, (jumpVy >= 0 and "rise" or "fall")
			elseif t < W then
				jp = JumpPose.crouch(t / W, js, geo)
				jumpW, jumpState = 1, "crouch"
			elseif t < W + JUMP_LIFTOFF_WAIT then
				jp = JumpPose.air(t - W, 0, 1, js, geo)
				jumpW, jumpState = 1, "push"
			else
				jump.done = true
			end
			if jp and js.JumpPoseEnabled then
				for name, off in pairs(jp) do
					if motors[name] then pose[name] = (pose[name] or CFrame.identity):Lerp(off, jumpW) end
				end
			else
				jumpW = 0
			end
		end
		show("JumpSource", jump and jump.source or "server")
		show("JumpState", jumpState)
		show("JumpBlend", math.floor(jumpW * 10 + 0.5) / 10)
	end
	-- v1.16: pounce (wind-up / lunge / latched / let-go fade) replaces the pose by the pounce weight
	local pounceActive = false
	if hrp and geo and model:GetAttribute("PounceEnabled") == true then
		local ps = PouncePose.settings(model)
		local serverNow = workspace:GetServerTimeNow()
		local lp = Players.LocalPlayer
		local own = lp ~= nil and lp.Character == model
		local localState = own and model:GetAttribute("PounceLocalState") or nil
		local pStart, pSource = model:GetAttribute("PounceStartedAt"), "server"
		local pPred = model:GetAttribute("PouncePredictedAt")
		if own and pPred and (not pStart or pPred > pStart + 0.001) then pStart, pSource = pPred, "predicted" end
		if pStart and model:GetAttribute("PounceDeniedAt") == pStart then pStart = nil end
		local W = model:GetAttribute("PounceWindup") or 0.1
		local t = pStart and (serverNow - pStart) or nil
		local latched
		if localState then latched = localState == "latched" else latched = model:GetAttribute("PounceLatched") == true end
		local pp, pw, pState = nil, 0, "none"
		if latched then
			if not pounceLatchClock then pounceLatchClock = now end
			local biteAt = model:GetAttribute("PounceBiteAt")
			local latchedAt = model:GetAttribute("PounceLatchedAt")
			local chomp = (biteAt and latchedAt and biteAt >= latchedAt - 0.01) and (serverNow - biteAt) or nil
			pp = PouncePose.latch(now - pounceLatchClock, chomp, ps, geo)
			pw, pState = 1, "latched"
			pounceLast, pounceLetGoAt = pp, nil
		else
			if pounceLatchClock then pounceLetGoAt, pounceLatchClock = now, nil end
			local windup, lunge = false, false
			if localState then
				windup, lunge = localState == "windup", localState == "lunge"
			elseif t and t >= 0 then
				windup = t < W
				if not windup and t < W + 1.0 then
					local hum = model:FindFirstChildOfClass("Humanoid")
					local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
					local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(base + 10), 0), jumpParams)
					local gap = hit and (hrp.Position.Y - hit.Position.Y - base) or 99
					lunge = t < W + 0.15 or gap > 0.4
				end
			end
			if windup then
				pp = JumpPose.crouch(math.clamp((t or 0) / math.max(0.01, W), 0, 1), JumpPose.settings(model), geo)
				pw, pState = 1, "windup"
			elseif lunge then
				pp = PouncePose.lunge(math.max(0, (t or W) - W), ps, geo)
				pw, pState = 1, "lunge"
			elseif pounceLetGoAt and now - pounceLetGoAt < 0.25 and pounceLast then
				local u = (now - pounceLetGoAt) / 0.25
				pp, pw, pState = pounceLast, 1 - u * u * (3 - 2 * u), "release"
			end
		end
		if pp and ps.PouncePoseEnabled then
			for name, off in pairs(pp) do
				if motors[name] then pose[name] = (pose[name] or CFrame.identity):Lerp(off, pw) end
			end
			pounceActive = pw > 0
		else
			pw = 0
		end
		show("PounceState", pState)
		show("PounceBlend", math.floor(pw * 10 + 0.5) / 10)
		show("PounceSource", pSource)
	end
	-- v1.20: eat / drink replaces the pose by the eat weight; the reach steers the mouth to the target
	local mouthGap
	if eatActive and phase21 ~= nil then -- v1.21: phase-driven, reach solved by forward kinematics
		if not fk and hrp then fk = buildFK(hrp) end
		-- aim: turn the neck toward the carcass
		local aimTarget = 0
		if eatKind == "eat" and hrp and motors.RootJoint then
			local name = model:GetAttribute("SurvivalNearCarcass")
			local folder = workspace:FindFirstChild("DinoCarcasses")
			local carc = folder and type(name) == "string" and name ~= "" and folder:FindFirstChild(name)
			local neckSeg = model:FindFirstChild("Neck")
			local neckRoot = neckSeg and neckSeg:FindFirstChild("Root")
			if carc and neckRoot then
				local bodyCF = hrp.CFrame * motors.RootJoint.restC0
				local off = carc:GetBoundingBox().Position - neckRoot.Position
				local fwd, right = off:Dot(bodyCF.XVector), off:Dot(bodyCF.ZVector)
				aimTarget = math.clamp(-math.deg(math.atan2(right, math.max(fwd, 0.5))), -EatPose.AIM_MAX, EatPose.AIM_MAX)
			end
		end
		e21.aim += (aimTarget - e21.aim) * math.min(1, dt * AIM_RATE)
		local targetY = eatTargetY21(eatKind)
		if targetY and fk and hrp then
			local p, yaw = hrp.Position, math.deg(yawOf(hrp.CFrame))
			local k = e21.key
			if not k or k.kind ~= eatKind or math.abs(k.ty - targetY) > REACH_RESOLVE_MOVE
				or (k.p - p).Magnitude > REACH_RESOLVE_MOVE or math.abs(k.yaw - yaw) > REACH_RESOLVE_TURN
				or math.abs(k.aim - e21.aim) > 1 then
				local hover = eatKind == "eat" and EatPose.EAT_HOVER or EatPose.DRINK_HOVER
				e21.reachIn = solveReach(eatKind, es, ws, geo, hrp.CFrame, targetY, e21.aim)
				e21.reachHover = solveReach(eatKind, es, ws, geo, hrp.CFrame, targetY + hover, e21.aim)
				e21.key = {kind = eatKind, ty = targetY, p = p, yaw = yaw, aim = e21.aim}
			end
			if eatW > 0.99 and e21.mix > 0.99 then
				local low = mouthLowest()
				if low then mouthGap = low - targetY end
			end
		end
		eatReach = e21.reachHover + (e21.reachIn - e21.reachHover) * e21.mix
		for name, off in pairs(EatPose.pose(eatKind, es, ws, geo, WalkPose.stance, eatReach, e21.m, e21.aim)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity):Lerp(off, eatW) end
		end
		show("EatReachIn", math.floor(e21.reachIn + 0.5))
		show("EatReachHover", math.floor(e21.reachHover + 0.5))
		show("EatAim", math.floor(e21.aim + 0.5))
	elseif eatActive then
		local targetY = eatTargetY(eatKind)
		local low = targetY and eatW > 0.5 and mouthLowest() or nil
		if low then
			mouthGap = low - targetY
			eatReach += mouthGap * REACH_GAIN * math.min(1, dt * REACH_RATE)
		else
			eatReach -= eatReach * math.min(1, dt * REACH_RATE)
		end
		eatReach = math.clamp(eatReach, EatPose.REACH_MIN, EatPose.REACH_MAX)
		for name, off in pairs(EatPose.get(eatKind, now - eatClock, es, ws, geo, WalkPose.stance, eatReach)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity):Lerp(off, eatW) end
		end
	end
	show("EatPoseState", eatActive and ((phase21 == "lowering" or phase21 == "rising") and phase21
		or (eatTarget == 1 and (eatKind == "eat" and "eating" or "drinking") or "fade")) or "none") -- v1.21: + lowering / rising
	show("EatPoseBlend", math.floor(eatW * 10 + 0.5) / 10)
	show("EatReach", math.floor(eatReach + 0.5))
	show("EatMouthGap", mouthGap and math.floor(mouthGap * 10 + 0.5) / 10 or 0)
	-- v1.19: tree ram phase (applied after the head lead)
	local ramPhase, ramU, ramSource = nil, 0, "server"
	if model:GetAttribute("RamEnabled") == true then
		local rms = RamPose.settings(model)
		local serverNow = workspace:GetServerTimeNow()
		local W = math.max(0.01, rms.RamWindup)
		local lp = Players.LocalPlayer
		local localState = (lp ~= nil and lp.Character == model) and model:GetAttribute("RamLocalState") or nil
		if localState then
			ramSource = "local"
			local pStart = model:GetAttribute("RamPredictedAt")
			if localState == "windup" and pStart then
				ramPhase, ramU = "windup", math.clamp((serverNow - pStart) / W, 0, 1)
			elseif localState == "charge" then
				ramPhase, ramU = "charge", 0
			elseif localState == "recoil" then
				local at = model:GetAttribute("RamLocalImpactAt") or serverNow
				ramPhase, ramU = "impact", math.clamp((serverNow - at) / RamPose.RECOIL, 0, 1)
			else
				local endAt = model:GetAttribute("RamLocalEndAt")
				if endAt and pStart and endAt >= pStart and serverNow - endAt < RAM_FADE then
					ramPhase, ramU = "fade", (serverNow - endAt) / RAM_FADE
				end
			end
		else
			local rStart = model:GetAttribute("RamStartedAt")
			if rStart and model:GetAttribute("RamDeniedAt") ~= rStart then
				local t = serverNow - rStart
				local impactAt = model:GetAttribute("RamImpactAt")
				local endAt = model:GetAttribute("RamEndedAt")
				if impactAt and impactAt >= rStart - 0.001 then
					if serverNow - impactAt < RamPose.RECOIL then
						ramPhase, ramU = "impact", math.clamp((serverNow - impactAt) / RamPose.RECOIL, 0, 1)
					end
				elseif endAt and endAt >= rStart - 0.001 then
					if serverNow - endAt < RAM_FADE then ramPhase, ramU = "fade", (serverNow - endAt) / RAM_FADE end
				elseif t >= 0 and t < W then
					ramPhase, ramU = "windup", t / W
				elseif t >= W and t < W + rms.RamMaxCharge + 1 then
					ramPhase, ramU = "charge", 0
				end
			end
		end
	end
	local ramActive = ramPhase ~= nil
	-- head leans into turns while moving
	local turnHead = 0
	if ts.TurnHeadEnabled and blend > 0.001 then
		turnHead = TurnPose.amount(smoothTurnRate, ts, blend)
		for name, off in pairs(TurnPose.get(turnHead, ts)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
	end
	-- head leads the body into turns (moving and standing); fades out during the roar and the bite
	local hl = HeadLeadPose.settings(model)
	local leadErr, leadSource = 0, "none"
	local localErr = model:GetAttribute("TurnErrorLocal")
	local ownPlayer = Players.LocalPlayer
	if localErr ~= nil and ownPlayer and ownPlayer.Character == model then
		leadErr, leadSource = localErr, "local"
	else
		local serverErr = model:GetAttribute("TurnError")
		if serverErr ~= nil then leadErr, leadSource = serverErr, "server" end
	end
	local leadState
	local leadTarget = 0
	if not hl.HeadLeadEnabled then
		leadState = "off"
	elseif roarF or biteT or pounceActive or ramActive or eatActive then -- v1.16: pounce; v1.19: ram; v1.20: eat / drink
		leadState = "suppressed"
	else
		leadTarget = HeadLeadPose.target(leadErr, hl)
		leadState = leadTarget ~= 0 and "leading" or "none"
	end
	headLead += (leadTarget - headLead) * math.min(1, dt * hl.HeadLeadSmooth)
	if leadTarget == 0 and math.abs(headLead) < 0.01 then headLead = 0 end
	if headLead ~= 0 then
		for name, off in pairs(HeadLeadPose.get(headLead, hl)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
	end
	-- v1.19: tree ram on top of the body and head lead
	if ramPhase then
		for name, off in pairs(RamPose.get(ramPhase, ramU, 1, now)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
	end
	show("RamState", ramPhase or "none")
	show("RamSource", ramSource)
	-- roar on top of whatever the body is doing (upper body only)
	local roarState = "none"
	if roarF then
		local roar, w, r = RoarPose.get(roarF, rs, now)
		for name, off in pairs(roar) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
		roarState = (roarF < 0.2 and "windup") or (roarF < 0.8 and "roaring") or "recover"
	end
	-- bite on top of everything (upper body only)
	local biteState = "none"
	if biteT then
		local dip = (biteSource == "predicted" and model:GetAttribute("BiteDipPredicted") or model:GetAttribute("BiteDip")) or 0 -- v1.18
		local bite = BitePose.get(biteT, biteHitT, bs, typeof(dip) == "number" and dip or 0)
		for name, off in pairs(bite) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
		biteState = BitePose.phase(biteT, bs) .. ((biteHitT and biteT >= biteHitT) and "-hit" or "")
	end
	-- v1.19: stunned flailing, last
	local stunUntil = model:GetAttribute("StunnedUntil")
	local stunTarget = (typeof(stunUntil) == "number" and stunUntil > workspace:GetServerTimeNow()) and 1 or 0
	stunBlend += (stunTarget - stunBlend) * math.min(1, dt * STUN_BLEND_RATE)
	if stunTarget == 0 and stunBlend < 0.01 then stunBlend = 0 end
	if stunBlend > 0 then
		for name, off in pairs(RamPose.stun(stunBlend, now)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
	end
	show("StunPose", stunBlend > 0 and "kicking" or "none")
	show("StunBlend", math.floor(stunBlend * 10 + 0.5) / 10)
	-- v1.21: dead pose, last
	local ds = DeadPose.settings(model)
	local deadHum = model:FindFirstChildOfClass("Humanoid")
	local deadTarget = (ds.DeadPoseEnabled and ((deadHum and deadHum.Health <= 0) or model:GetAttribute("DummyState") == "ko")) and 1 or 0
	deadW += (deadTarget - deadW) * math.min(1, dt * ds.DeadBlendRate)
	if deadTarget == 0 and deadW < 0.01 then deadW = 0 end
	if deadTarget == 1 and deadW > 0.995 then deadW = 1 end
	if deadW > 0 then
		for name, off in pairs(DeadPose.get(ds)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity):Lerp(off, deadW) end
		end
	end
	show("DeadPoseState", deadW > 0 and (deadTarget == 1 and "dead" or "fade") or "none")
	show("DeadPoseBlend", math.floor(deadW * 10 + 0.5) / 10)
	IdlePose.apply(motors, pose)
	show("RoarState", roarState)
	show("BiteState", biteState)
	if biteT then show("BiteSource", biteSource) end

	show("IdleState", "playing")
	show("IdleLookState", lookPhase)
	local creeping = creepBlend > 0.5
	show("MoveState", blend <= 0.5 and (creeping and "crouched" or "idle")
		or (creeping and "creeping" or (gaitBlend > 0.5 and "running" or "walking")))
	show("CreepBlend", math.floor(creepBlend * 10 + 0.5) / 10)
	show("GaitBlend", math.floor(gaitBlend * 10 + 0.5) / 10)
	show("MoveSpeed", math.floor(smoothSpeed * 2 + 0.5) / 2)
	show("MoveDir", math.floor(math.deg(moveDir) + 0.5)) -- v1.17
	show("WalkBlend", math.floor(blend * 10 + 0.5) / 10)
	show("TurnRate", math.floor(smoothTurnRate / 10 + 0.5) * 10)
	show("TurnHead", math.floor(turnHead + 0.5))
	show("HeadLead", math.floor(headLead + 0.5))
	show("HeadLeadSource", leadSource)
	show("HeadLeadState", leadState)
end)
