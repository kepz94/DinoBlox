-- IdleAnimation v1.13 (Dino Arcade): idle + walk animation for this model, on each player's client.
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
local Players = game:GetService("Players")

for _, defaults in ipairs({IdlePose.Defaults, WalkPose.Defaults, RoarPose.Defaults, BitePose.Defaults, TurnPose.Defaults}) do
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
			end
		end
		lastPos, lastYaw = pos, yaw
	end
	local ts = TurnPose.settings(model)
	smoothTurnRate += (turnRate - smoothTurnRate) * math.min(1, dt * ts.TurnHeadSmooth)
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

	-- idle (head-turn fades out while walking, roaring or biting), then blend toward walk
	local now = os.clock()
	local lookYaw, lookPhase = IdlePose.updateLook(look, now, s)
	local pose = IdlePose.get(now - start, s, lookYaw * (1 - blend) * ((roarF or biteT) and 0 or 1))
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
		local walk = WalkPose.get(walkPhase, ws, geo, gaitBlend, creepBlend, tailPhase)
		for name in pairs(motors) do
			pose[name] = (pose[name] or CFrame.identity):Lerp(walk[name] or CFrame.identity, blend)
		end
	end
	-- head leans into turns while moving
	local turnHead = 0
	if ts.TurnHeadEnabled and blend > 0.001 then
		turnHead = TurnPose.amount(smoothTurnRate, ts, blend)
		for name, off in pairs(TurnPose.get(turnHead, ts)) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
	end
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
		local bite = BitePose.get(biteT, biteHitT, bs)
		for name, off in pairs(bite) do
			if motors[name] then pose[name] = (pose[name] or CFrame.identity) * off end
		end
		biteState = BitePose.phase(biteT, bs) .. ((biteHitT and biteT >= biteHitT) and "-hit" or "")
	end
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
	show("WalkBlend", math.floor(blend * 10 + 0.5) / 10)
	show("TurnRate", math.floor(smoothTurnRate / 10 + 0.5) * 10)
	show("TurnHead", math.floor(turnHead + 0.5))
end)
