-- StepAssistCore v1.0 (Dino Arcade) — step-up assist shared by the owner client (StepAssist 1.0, player dinos) and the
-- server (StepAssistServer 1.0, bots in DinoIsland.Bots and prey in DinoIsland.Prey).
-- Why (DINO-7 terrain gate, measured in Play): the island is a 16-stud tile grid whose most common step between land
--   tiles is 2 studs (8038 edges; Sand -> Grass 2.4). A Humanoid only got up a step when its HipHeight was about the step
--   height or more: Hatchling T-Rex (HipHeight 1.98) 0 of 6 test steps, raptors below Adult (0.84 / 1.26 / 1.68) 0 of 6,
--   adult raptor (2.10) 3 of 6, adult T-Rex (4.96) 5 of 6. User's answer: step-up assist, for all dinos.
-- Rule, every frame (PreSimulation) per dino:
--   * Active only while: DinoIsland attribute StepAssistEnabled ~= false; HumanoidRootPart not anchored; Humanoid state
--     Running / RunningNoPhysics (on the ground, not jumping / falling / ragdolled / dead); Humanoid.MoveDirection
--     (flat) > MOVE_MIN (it wants to move); not riding a latch (PounceLatched ~= true), not knocked out (DummyState ~=
--     "ko"), not pinned (PinnedAt not set) - those positions belong to PounceServer / BotServer / BiteTargetHealth.
--   * Direction: Humanoid.MoveDirection. Server-driven dinos (opts.walkTo, StepAssistServer): Humanoid:MoveTo on the
--     server leaves MoveDirection at 0 (measured: wandering bots read 0.00), so when it is 0 and no WalkToPart is set,
--     the flat direction to Humanoid.WalkToPoint is used when that point is more than WALKTO_MIN studs away. Players
--     never use WalkToPoint (theirs is unused and points at the origin).
--   * Blocked: flat speed < BLOCK_SPEED_FRAC x WalkSpeed for BLOCK_TIME s in a row.
--   * Ledge search (only when blocked): ground under the HumanoidRootPart = y0 (ray down, DinoIsland.Ground only); rays
--     down at PROBE_STEP .. PROBE_REACH studs ahead along MoveDirection (from StepAssistMax + 1 above y0); the first
--     hit higher than y0 + STEP_MIN is the ledge when it is at most y0 + StepAssistMax (default 2.6) and flat (normal
--     Y > FLAT_MIN); higher = a wall (no lift, StepAssistState "wall").
--   * Lift: over LIFT_TIME s the HumanoidRootPart (and with it the whole welded / jointed model) rises (ledge - y0 +
--     LIFT_CLEAR) and moves (probe distance where the ledge was found + LIFT_PAST, at most PROBE_REACH) studs along the
--     direction, so the HumanoidRootPart ends over the ledge, vertical velocity held at 0; then COOLDOWN s before the
--     next lift. Legs, joints and animation are untouched. (A fixed 0.6-stud nudge left a server-walked 0.4 raptor
--     1.06 studs short of the face: it dropped back and needed a second lift.)
--   * Repeat guard: a new lift within REPEAT_TIME s of the last one and less than REPEAT_DIST studs (flat) from where
--     that one started is skipped (StepAssistState "stuck"; something else, e.g. a tree trunk, is in the way).
-- Diagnostics (model attributes, written by whoever runs it): StepAssistState ("idle" / "blocked" / "lift" / "wall" /
--   "off" / "stuck"), StepAssistCount, StepAssistLastHeight (studs lifted), StepAssistLastAt (server time), StepAssistWalls.
local StepAssistCore = {}

StepAssistCore.Version = "1.0"
StepAssistCore.DEFAULT_MAX = 2.6
local MOVE_MIN = 0.5
local BLOCK_SPEED_FRAC = 0.25
local BLOCK_TIME = 0.1
local STEP_MIN = 0.3
local PROBE_STEP = 0.5
local PROBE_REACH = 4
local FLAT_MIN = 0.9
local LIFT_TIME = 0.12
local LIFT_CLEAR = 0.15
local LIFT_PAST = 0.4
local COOLDOWN = 0.25
local REPEAT_TIME, REPEAT_DIST = 1.5, 1
local WALKTO_MIN = 6

local RUNNING = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- one state table per dino
-- opts (optional): {walkTo = true} for server-driven dinos (see Direction above)
function StepAssistCore.new(model, hum, hrp, opts)
	return {model = model, hum = hum, hrp = hrp, blockedFor = 0, lift = nil, nextAt = 0, shown = {},
		walkTo = opts ~= nil and opts.walkTo == true}
end

local function show(st, k, v)
	if st.shown[k] ~= v then
		st.shown[k] = v
		st.model:SetAttribute(k, v)
	end
end

local function settings()
	local island = workspace:FindFirstChild("DinoIsland")
	local ground = island and island:FindFirstChild("Ground")
	local enabled = not island or island:GetAttribute("StepAssistEnabled") ~= false
	local max = island and island:GetAttribute("StepAssistMax")
	if type(max) ~= "number" then max = StepAssistCore.DEFAULT_MAX end
	return enabled, max, ground
end

local paramsCache = {}
local function paramsFor(ground)
	local p = paramsCache[ground]
	if not p then
		p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Include
		p.FilterDescendantsInstances = {ground}
		p.RespectCanCollide = true
		paramsCache[ground] = p
	end
	return p
end

-- returns ledge height above y0, or nil + reason ("noGround" / "wall" / "none")
local function findLedge(hrp, dir, max, params)
	local pos = hrp.Position
	local down = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
	if not down then return nil, "noGround" end
	local y0 = down.Position.Y
	for s = PROBE_STEP, PROBE_REACH, PROBE_STEP do
		local origin = Vector3.new(pos.X, y0 + max + 1, pos.Z) + dir * s
		local hit = workspace:Raycast(origin, Vector3.new(0, -(max + 1 + STEP_MIN + 0.5), 0), params)
		if hit then
			local h = hit.Position.Y - y0
			if h >= max + 0.999 then return nil, "wall" end -- the ray started inside / at the top of something tall
			if h > STEP_MIN then
				if h <= max and hit.Normal.Y > FLAT_MIN then return h, s end
				return nil, "wall"
			end
		else
			-- the ray started inside a part taller than max + 1 (no hit from inside): a wall
			local inside = workspace:Raycast(Vector3.new(pos.X, y0 + 0.05, pos.Z) + dir * (s - PROBE_STEP), dir * PROBE_STEP, params)
			if inside then return nil, "wall" end
		end
	end
	return nil, "none"
end

-- call every frame; dt in seconds; now = server time (for the diagnostic)
function StepAssistCore.step(st, dt, now)
	local hum, hrp = st.hum, st.hrp
	local enabled, max, ground = settings()
	if not enabled or not ground then
		st.lift, st.blockedFor = nil, 0
		show(st, "StepAssistState", "off")
		return
	end
	-- lift in progress
	local l = st.lift
	if l then
		if hrp.Anchored or not hrp.Parent then
			st.lift = nil
			return
		end
		l.t += dt
		local a = math.min(1, l.t / LIFT_TIME)
		local p = l.from + l.dir * (l.nudge * a) + Vector3.new(0, l.dy * a, 0)
		local cur = hrp.Position
		-- keep any sideways / forward motion the Humanoid made this frame, replace the climb part
		hrp.CFrame = CFrame.new(Vector3.new(cur.X + (p.X - l.lastX), p.Y, cur.Z + (p.Z - l.lastZ))) * hrp.CFrame.Rotation
		l.lastX, l.lastZ = p.X, p.Z
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		if a >= 1 then
			st.lift = nil
			st.nextAt = os.clock() + COOLDOWN
			show(st, "StepAssistState", "idle")
		end
		return
	end
	local want = flat(hum.MoveDirection)
	if want.Magnitude < MOVE_MIN and st.walkTo and hum.WalkToPart == nil then
		local d = flat(hum.WalkToPoint - hrp.Position)
		if d.Magnitude > WALKTO_MIN then want = d.Unit end
	end
	local m = st.model
	if hrp.Anchored or hum.Health <= 0 or not RUNNING[hum:GetState()] or want.Magnitude < MOVE_MIN
		or m:GetAttribute("PounceLatched") == true or m:GetAttribute("DummyState") == "ko" or m:GetAttribute("PinnedAt") ~= nil then
		st.blockedFor = 0
		show(st, "StepAssistState", "idle")
		return
	end
	local speed = flat(hrp.AssemblyLinearVelocity).Magnitude
	if speed >= BLOCK_SPEED_FRAC * math.max(hum.WalkSpeed, 1) then
		st.blockedFor = 0
		show(st, "StepAssistState", "idle")
		return
	end
	st.blockedFor += dt
	if st.blockedFor < BLOCK_TIME or os.clock() < st.nextAt then
		show(st, "StepAssistState", "blocked")
		return
	end
	local dir = want.Unit
	local h, why = findLedge(hrp, dir, max, paramsFor(ground)) -- why = probe distance when h is found
	if not h then
		if why == "wall" then
			if st.shown.StepAssistState ~= "wall" then
				st.model:SetAttribute("StepAssistWalls", (st.model:GetAttribute("StepAssistWalls") or 0) + 1)
			end
			show(st, "StepAssistState", "wall")
		else
			show(st, "StepAssistState", "blocked")
		end
		st.nextAt = os.clock() + COOLDOWN
		return
	end
	local from = hrp.Position
	if st.lastFrom and os.clock() - st.lastClock < REPEAT_TIME and flat(from - st.lastFrom).Magnitude < REPEAT_DIST then
		st.nextAt = os.clock() + COOLDOWN
		show(st, "StepAssistState", "stuck")
		return
	end
	st.lastFrom, st.lastClock = from, os.clock()
	st.lift = {t = 0, from = from, dir = dir, dy = h + LIFT_CLEAR, nudge = math.min(why + LIFT_PAST, PROBE_REACH),
		lastX = from.X, lastZ = from.Z}
	st.blockedFor = 0
	st.model:SetAttribute("StepAssistCount", (st.model:GetAttribute("StepAssistCount") or 0) + 1)
	st.model:SetAttribute("StepAssistLastHeight", math.floor(h * 100 + 0.5) / 100)
	st.model:SetAttribute("StepAssistLastAt", now)
	show(st, "StepAssistState", "lift")
end

return StepAssistCore
