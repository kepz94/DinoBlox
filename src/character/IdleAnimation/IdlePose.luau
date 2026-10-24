-- IdlePose v1.3 (Dino Arcade) — code-driven idle for the TRex rig
-- Pure pose function: time -> per-joint offset, applied on top of each joint's rest C0.
-- Joint frames are world-aligned at build time: +X forward, +Y up, Z = side.
--   Pitch = rotation about Z (positive lifts the front), Yaw = rotation about Y.
-- Settings come from model attributes (defaults below), so tuning needs no code edits.
-- v1.1: drives Motor6D.C0 | v1.2: joints picked up as they stream in
-- v1.3: occasional head turn ("look") layered on top of the loop

local IdlePose = {}

IdlePose.Version = "1.3"
IdlePose.Defaults = {
	IdleEnabled      = true,
	IdlePeriod       = 1.0,  -- seconds per loop
	IdleBob          = 0.3,  -- studs; body dips 0..2*IdleBob
	IdleHead         = 1.0,  -- multiplier on neck/head/jaw motion
	IdleTailSway     = 1.0,  -- multiplier on tail side-to-side
	-- head turn (v1.3)
	IdleLookEnabled  = true,
	IdleLookAngle    = 30,   -- degrees, total for neck + head
	IdleLookMinGap   = 3,    -- seconds between turns (random between min and max)
	IdleLookMaxGap   = 7,
	IdleLookHold     = 1.2,  -- seconds held to the side
}

local LOOK_TURN_TIME   = 0.3  -- quick snap out
local LOOK_RETURN_TIME = 0.5  -- slower return
local LOOK_NECK_SHARE  = 0.4  -- neck takes 40% of the turn, head 60%

local rad, sin, cos, pi = math.rad, math.sin, math.cos, math.pi
local TAIL_YAW = {2, 3, 4, 5, 6} -- degrees per tail segment (cumulative down the chain)

local function easeOut(u) return 1 - (1 - u) ^ 3 end
local function easeInOut(u) return u < 0.5 and 4 * u ^ 3 or 1 - (-2 * u + 2) ^ 3 / 2 end

-- lookYaw: radians, signed (0 = facing forward)
function IdlePose.get(t, s, lookYaw)
	lookYaw = lookYaw or 0
	local w = 2 * pi * t / s.IdlePeriod
	local bob = s.IdleBob * (1 - cos(w))
	local rootPitch = rad(1.2 * sin(w))
	local out = {}

	-- body dips and rocks slightly
	out.RootJoint = CFrame.new(0, -bob, 0) * CFrame.Angles(0, 0, rootPitch)
	-- legs counter the dip and the rock so feet stay planted
	local leg = CFrame.Angles(0, 0, -rootPitch) * CFrame.new(0, bob, 0)
	out.LegL, out.LegR = leg, leg
	-- head follows a beat behind the body; head turn layered on as yaw
	out.Neck = CFrame.Angles(0, lookYaw * LOOK_NECK_SHARE, 0) * CFrame.Angles(0, 0, rad(-2.0 * s.IdleHead * sin(w - 0.5)))
	out.Head = CFrame.Angles(0, lookYaw * (1 - LOOK_NECK_SHARE), 0) * CFrame.Angles(0, 0, rad(-2.5 * s.IdleHead * sin(w - 1.0)))
	out.Jaw  = CFrame.Angles(0, 0, rad(-2.0 * s.IdleHead * (0.5 + 0.5 * sin(w - 1.4))))
	-- tiny arms flap
	local arm = CFrame.Angles(0, 0, rad(8 * sin(w - 1.2)))
	out.ArmL, out.ArmR = arm, arm
	-- tail sways side to side, tip lagging behind
	for k = 1, 5 do
		out["Tail" .. k] = CFrame.Angles(0, rad(TAIL_YAW[k] * s.IdleTailSway * sin(w - 0.5 * k)), rad(-1.0 * sin(w - 0.4 * k)))
	end
	return out
end

-- Head-turn state machine: rest -> turn -> hold -> return -> rest
-- Every branch sets yaw; phase name is exposed for diagnostics.
function IdlePose.newLook(now, s, rng)
	rng = rng or Random.new()
	return {phase = "rest", t0 = now, dir = 1, rng = rng,
		nextAt = now + rng:NextNumber(s.IdleLookMinGap, s.IdleLookMaxGap)}
end

function IdlePose.updateLook(look, now, s)
	local A = rad(s.IdleLookAngle)
	if not s.IdleLookEnabled then
		look.phase, look.nextAt = "off", now + look.rng:NextNumber(s.IdleLookMinGap, s.IdleLookMaxGap)
		return 0, look.phase
	end
	if look.phase == "off" then
		look.phase = "rest"
	end
	if look.phase == "rest" then
		if now >= look.nextAt then
			look.phase, look.t0 = "turn", now
			look.dir = look.rng:NextInteger(0, 1) == 0 and -1 or 1
		else
			return 0, look.phase
		end
	end
	if look.phase == "turn" then
		local u = (now - look.t0) / LOOK_TURN_TIME
		if u < 1 then return look.dir * A * easeOut(u), look.phase end
		look.phase, look.t0 = "hold", now
	end
	if look.phase == "hold" then
		if now - look.t0 < s.IdleLookHold then return look.dir * A, look.phase end
		look.phase, look.t0 = "return", now
	end
	if look.phase == "return" then
		local u = (now - look.t0) / LOOK_RETURN_TIME
		if u < 1 then return look.dir * A * (1 - easeInOut(u)), look.phase end
		look.phase = "rest"
		look.nextAt = now + look.rng:NextNumber(s.IdleLookMinGap, s.IdleLookMaxGap)
	end
	return 0, look.phase
end

function IdlePose.settings(model)
	local s = {}
	for k, v in pairs(IdlePose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

function IdlePose.addMissing(model, motors)
	-- adds joints not yet tracked; existing entries keep their rest C0
	local added = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and not motors[d.Name] then
			motors[d.Name] = {motor = d, restC0 = d.C0}
			added += 1
		end
	end
	return added
end

function IdlePose.count(motors)
	local n = 0
	for _ in pairs(motors) do n += 1 end
	return n
end

function IdlePose.apply(motors, pose)
	for name, e in pairs(motors) do
		e.motor.C0 = e.restC0 * (pose[name] or CFrame.identity)
	end
end

function IdlePose.reset(motors)
	for _, e in pairs(motors) do e.motor.C0 = e.restC0 end
end

return IdlePose
