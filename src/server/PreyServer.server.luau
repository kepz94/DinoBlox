-- PreyServer v1.0 (Dino Arcade) — small prey on the island: compies, chickens, crabs (DINO-13, plan
-- docs/plans/PREY_v1.0.md; user's answers: all four prey types planned, spawn both near players and in zones, everyone
-- hunts, compies sprint then tire, chickens on grass and crabs on beaches, cap 15 compies, no health bars on prey).
-- Models: ServerStorage.DinoArcade.PreyModels 1.0 (flags IsBot / Bitable / Species / DummyMaxHealth, so DinoHitboxes,
--   BiteTargetHealth, BiteServer, PounceServer, SurvivalServer carcasses, KillRegenServer and GrowthServer kill XP
--   handle prey with no change). Water: ServerStorage.DinoArcade.IslandWater 1.0. BotServer is not touched.
-- Folder: Workspace.DinoIsland.Prey; models "Prey_<Kind>_<n>". Compies get clones of StarterCharacterScripts
--   IdleAnimation / StatusBadges / PounceFX / StunFX (as BotServer bots); chickens / crabs get PreyScripts.PreyHop.
--   Server-owned physics (SetNetworkOwner nil); velocity capped every tick (horizontal 1.5 x run, up 30).
-- Zones (picked once at start, same island = same zones): compy zones beside the TallGrass patches, chicken zones on
--   Grass / Meadow tiles, crab zones on Sand tiles (dry, top above -0.8); per kind greedy farthest-point from the
--   first candidate (sorted by X then Z), at most ZONE_MAX 6, at least ZONE_SPACING 150 studs apart. A zone holds one
--   group while a player is within ZONE_ACTIVE 300 studs (never spawned within NO_POP 40 studs of a player).
-- Near players: each living player keeps PLAYER_GROUPS 2 groups spawned NEAR_MIN 60 - NEAR_MAX 150 studs away on dry
--   ground inside IslandWanderLimit, never within NO_POP 40 of any player; Sand -> crabs, else compies and chickens
--   alternately. Top-up every TOPUP 20 s (first 3 s after start). Caps: MAX_GROUPS 24 groups, MAX_COMPIES 15 compies
--   (a compy group that would pass it is cut down; none left -> chickens instead near players, nothing in a zone).
-- Behaviour (every TICK 0.1 s), predator = a living player character or a BotServer bot that is not knocked out:
--   * graze: walk (MoveWalkSpeed) to a dry point within GRAZE_RADIUS 15 of the group centre, pause 1-3 s
--   * compy: a predator within 30 of any member alarms the whole group: "flee" at run 30 for 4 s, then "tired" (walk
--     14, still away) for 3 s, then flee again if a predator is within 30, else graze (group centre = where they are)
--   * chicken / crab: a predator within 15 of that one: "hop" away at 10 for 3 s, then graze
--   * away goal: FLEE_DIST 20 studs along the best of 7 directions (0, +-45, +-90, +-135 degrees off straight away),
--     each cut at the shore (IslandWater.dryLine); re-picked every 0.5 s; a cut goal adds 1 to PreyWaterCuts
--   * knocked out (DummyState "ko") or pinned (PinnedAt): anchored roll onto its side (0.4 s), PreyState "ko" /
--     "pinned"; once knocked out it stays down (also through BiteTargetHealth's 3 s reset) and is removed
--     PREY_KO_REMOVE 2.5 s after the KO or when a pin on it ends, whichever is later -> SurvivalServer leaves the
--     carcass (food = DummyMaxHealth: compy 15, chicken / crab 8). A pin that ends without a KO: it rolls back up
--     (0.5 s) and runs (flee / hop).
--   * despawn: a group with no player within DESPAWN_RADIUS 250 of its centre for DESPAWN_TIME 30 s and no member down
--     is removed (alive, so no carcass).
-- Toggle: script attribute PreyEnabled (default true); false = every prey removed, nothing spawns
--   (PreyServerState "disabled"); true again = spawning resumes.
-- Diagnostics: per model PreyState ("graze" / "flee" / "tired" / "hop" / "ko" / "pinned" / "getup"), PreyGroup,
--   PreyWaterCuts, PreySpawnedAt; script PreyServerVersion, PreyServerState ("running" / "disabled" / "noIsland" /
--   "noModels"), PreyCount, PreyCompies, PreyGroups, PreyZones ("Compy n · Chicken n · Crab n"), PreyZonesActive,
--   PreySpawned, PreyDespawned, PreyKOs.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local TICK = 0.1
local ZONE_MAX, ZONE_SPACING, ZONE_ACTIVE, NO_POP = 6, 150, 300, 40
local PLAYER_GROUPS, NEAR_MIN, NEAR_MAX = 2, 60, 150
local TOPUP, FIRST_TOPUP = 20, 3
local MAX_GROUPS, MAX_COMPIES = 24, 15
local DESPAWN_RADIUS, DESPAWN_TIME = 250, 30
local PREY_KO_REMOVE = 2.5
local GRAZE_RADIUS, FLEE_DIST, GOAL_EVERY = 15, 20, 0.5
local ROLL_TIME, GETUP_TIME = 0.4, 0.5
local DIRS = {0, 45, -45, 90, -90, 135, -135}
local COMPY_SCRIPTS = {"IdleAnimation", "StatusBadges", "PounceFX", "StunFX"}

script:SetAttribute("PreyServerVersion", VERSION)
if script:GetAttribute("PreyEnabled") == nil then script:SetAttribute("PreyEnabled", true) end
for _, k in ipairs({"PreySpawned", "PreyDespawned", "PreyKOs"}) do script:SetAttribute(k, 0) end
local function enabled() return script:GetAttribute("PreyEnabled") ~= false end

local island = workspace:WaitForChild("DinoIsland", 30)
local ground = island and island:WaitForChild("Ground", 10)
if not ground then
	script:SetAttribute("PreyServerState", "noIsland")
	return
end
local PM, Water, hopTemplate
do
	local ok = pcall(function()
		local da = ServerStorage:WaitForChild("DinoArcade", 10)
		PM = require(da:WaitForChild("PreyModels", 10))
		Water = require(da:WaitForChild("IslandWater", 10))
		hopTemplate = da:WaitForChild("PreyScripts", 10):WaitForChild("PreyHop", 10)
	end)
	if not ok or not PM or not Water then
		script:SetAttribute("PreyServerState", "noModels")
		return
	end
end
local preyFolder = island:FindFirstChild("Prey")
if not preyFolder then
	preyFolder = Instance.new("Folder")
	preyFolder.Name = "Prey"
	preyFolder.Parent = island
end
local wanderLimit = island:GetAttribute("IslandWanderLimit") or 165

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function inside(p) return math.abs(p.X) <= wanderLimit and math.abs(p.Z) <= wanderLimit end
local function dryGround(q)
	if not inside(q) or Water.isWater(q) then return nil end
	return Water.groundHit(q.X, q.Z)
end

-- zones -----------------------------------------------------------------------------------------------------------------
local function zoneCandidates(kind)
	local list = {}
	if kind == "Compy" then
		local tg = island:FindFirstChild("TallGrass")
		for _, patch in ipairs(tg and tg:GetChildren() or {}) do
			local cf, size
			if patch:IsA("Model") then cf, size = patch:GetBoundingBox()
			elseif patch:IsA("BasePart") then cf, size = patch.CFrame, patch.Size end
			if cf then
				for _, dir in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis}) do
					local reach = (dir.X ~= 0 and size.X or size.Z) / 2 + 12
					local q = flat(cf.Position) + dir * reach
					if dryGround(q) then
						table.insert(list, q)
						break
					end
				end
			end
		end
	else
		local names = kind == "Crab" and {Sand = true} or {Grass = true, Meadow = true}
		for _, p in ipairs(ground:GetChildren()) do
			if p:IsA("BasePart") and names[p.Name] then
				local q = flat(p.Position)
				if p.Position.Y + p.Size.Y / 2 > -0.8 and dryGround(q) then table.insert(list, q) end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.X ~= b.X then return a.X < b.X end
		return a.Z < b.Z
	end)
	return list
end

local function pickZones(cands)
	local chosen = {}
	if #cands == 0 then return chosen end
	table.insert(chosen, cands[1])
	local minD = {}
	for i, c in ipairs(cands) do minD[i] = (c - cands[1]).Magnitude end
	while #chosen < ZONE_MAX do
		local bi, bd = nil, -1
		for i, d in ipairs(minD) do
			if d > bd then bi, bd = i, d end
		end
		if not bi or bd < ZONE_SPACING then break end
		local c = cands[bi]
		table.insert(chosen, c)
		for i, o in ipairs(cands) do
			local d = (o - c).Magnitude
			if d < minD[i] then minD[i] = d end
		end
	end
	return chosen
end

local zones = {}
do
	local counts = {}
	for _, kind in ipairs(PM.KINDS) do
		local picked = pickZones(zoneCandidates(kind))
		for _, pos in ipairs(picked) do table.insert(zones, {kind = kind, pos = pos, group = nil}) end
		table.insert(counts, ("%s %d"):format(kind, #picked))
	end
	script:SetAttribute("PreyZones", table.concat(counts, " · "))
end

-- state -------------------------------------------------------------------------------------------------------------------
local groups = {} -- [id] = {id, kind, centre, members = {rec}, zone, player, state, stateUntil, farSince}
local recs = {} -- [model] = rec
local nextGroupId = 0
local nextIndex = {}
local playerAlt = setmetatable({}, {__mode = "k"})

local function show(rec, k, v)
	if rec.shown[k] ~= v then
		rec.shown[k] = v
		rec.model:SetAttribute(k, v)
	end
end

local function counts()
	local n, compies, g = 0, 0, 0
	for _, rec in pairs(recs) do
		n += 1
		if rec.kind == "Compy" then compies += 1 end
	end
	for _ in pairs(groups) do g += 1 end
	return n, compies, g
end

local function alivePlayers()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then table.insert(list, {player = pl, pos = hrp.Position}) end
	end
	return list
end

local function playerWithin(p, r, players)
	for _, e in ipairs(players) do
		if flat(e.pos - p).Magnitude <= r then return true end
	end
	return false
end

local function spawnMember(g, pos)
	local m = PM.build(g.kind)
	if not m then return nil end
	nextIndex[g.kind] = (nextIndex[g.kind] or 0) + 1
	m.Name = ("Prey_%s_%d"):format(g.kind, nextIndex[g.kind])
	if g.kind == "Compy" then
		for _, name in ipairs(COMPY_SCRIPTS) do
			local s = StarterPlayer.StarterCharacterScripts:FindFirstChild(name)
			if s then s:Clone().Parent = m end
		end
	elseif hopTemplate then
		hopTemplate:Clone().Parent = m
	end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then m:Destroy() return nil end
	m:SetAttribute("PreyState", "graze")
	m:SetAttribute("PreyGroup", g.id)
	m:SetAttribute("PreyWaterCuts", 0)
	m:SetAttribute("PreySpawnedAt", workspace:GetServerTimeNow())
	local want = CFrame.new(pos + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight + 0.2, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	local offset = m:GetPivot():ToObjectSpace(hrp.CFrame)
	m:PivotTo(want * offset:Inverse())
	m.Parent = preyFolder
	pcall(function() hrp:SetNetworkOwner(nil) end)
	local rec = {model = m, hrp = hrp, hum = hum, kind = g.kind, st = PM.STATS[g.kind], group = g, state = "graze",
		stateUntil = 0, goal = nil, goalUntil = 0, waitUntil = nil, nextGoalAt = 0, down = false, shown = {state = "graze"}}
	recs[m] = rec
	table.insert(g.members, rec)
	script:SetAttribute("PreySpawned", (script:GetAttribute("PreySpawned") or 0) + 1)
	return rec
end

local function spawnGroup(kind, centre, zone, player)
	local _, compies, g = counts()
	if g >= MAX_GROUPS then return nil end
	local st = PM.STATS[kind]
	local n = math.random(st.group[1], st.group[2])
	if kind == "Compy" then
		n = math.min(n, MAX_COMPIES - compies)
		if n < 1 then return nil end
	end
	nextGroupId += 1
	local grp = {id = nextGroupId, kind = kind, centre = centre, members = {}, zone = zone, player = player,
		state = "graze", stateUntil = 0, farSince = nil}
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi
		local q = centre + Vector3.new(math.cos(a), 0, math.sin(a)) * 3
		local hit = dryGround(q)
		if hit then spawnMember(grp, Vector3.new(q.X, hit.Position.Y, q.Z)) end
	end
	if #grp.members == 0 then return nil end
	groups[grp.id] = grp
	return grp
end

local function removeGroup(g, despawned)
	for _, rec in ipairs(g.members) do
		recs[rec.model] = nil
		if rec.model.Parent then rec.model:Destroy() end
	end
	if despawned then
		script:SetAttribute("PreyDespawned", (script:GetAttribute("PreyDespawned") or 0) + #g.members)
	end
	g.members = {}
	groups[g.id] = nil
	if g.zone and g.zone.group == g then g.zone.group = nil end
end

-- KO / pin roll (as BotServer 1.5's, copied) -----------------------------------------------------------------------------
local function rollCF(rec, k)
	local hrp, hum = rec.hrp, rec.hum
	local look = flat(rec.downFrom.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local stand = CFrame.lookAt(rec.downFrom.Position, rec.downFrom.Position + look.Unit)
	local lyingPos = Vector3.new(stand.X, rec.downGround + rec.halfWidth, stand.Z)
	local standPos = Vector3.new(stand.X, rec.downGround + hrp.Size.Y / 2 + hum.HipHeight, stand.Z)
	return CFrame.new(standPos:Lerp(lyingPos, k)) * stand.Rotation * CFrame.Angles(0, 0, math.pi / 2 * k)
end

local function animateRoll(rec, from, to, duration, done)
	local t0 = os.clock()
	local token = {}
	rec.rollToken = token
	task.spawn(function()
		while rec.rollToken == token and rec.model.Parent do
			local u = math.min(1, (os.clock() - t0) / duration)
			local s = u * u * (3 - 2 * u)
			rec.hrp.CFrame = rollCF(rec, from + (to - from) * s)
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if rec.rollToken == token and done then done() end
	end)
end

local function lieDown(rec)
	if rec.down then return end
	rec.down = true
	rec.hum:Move(Vector3.zero)
	rec.downFrom = rec.hrp.CFrame
	local hit = Water.groundHit(rec.hrp.Position.X, rec.hrp.Position.Z)
	rec.downGround = hit and hit.Position.Y or (rec.hrp.Position.Y - rec.hrp.Size.Y / 2 - rec.hum.HipHeight)
	local size = rec.model:GetExtentsSize()
	rec.halfWidth = math.min(size.X, size.Z) / 2
	rec.hrp.Anchored = true
	animateRoll(rec, 0, 1, ROLL_TIME)
end

local function standUp(rec)
	rec.gettingUp = true
	animateRoll(rec, 1, 0, GETUP_TIME, function()
		rec.hrp.Anchored = false
		pcall(function() rec.hrp:SetNetworkOwner(nil) end)
		rec.down, rec.gettingUp = false, false
	end)
end

-- movement ---------------------------------------------------------------------------------------------------------------
local function predatorsList()
	local list = {}
	for _, e in ipairs(alivePlayers()) do table.insert(list, e.pos) end
	local bf = island:FindFirstChild("Bots")
	for _, b in ipairs(bf and bf:GetChildren() or {}) do
		local hrp = b:FindFirstChild("HumanoidRootPart")
		if hrp and b:GetAttribute("DummyState") ~= "ko" then table.insert(list, hrp.Position) end
	end
	return list
end

local function nearest(p, preds)
	local best, bd = nil, math.huge
	for _, q in ipairs(preds) do
		local d = flat(q - p).Magnitude
		if d < bd then best, bd = q, d end
	end
	return best, bd
end

local function awayGoal(rec, predPos)
	local pos = rec.hrp.Position
	local away = flat(pos - predPos)
	away = away.Magnitude > 1e-3 and away.Unit or flat(-rec.hrp.CFrame.LookVector).Unit
	local best, bestScore, bestClear = nil, -math.huge, true
	for _, deg in ipairs(DIRS) do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(away)
		local goal = flat(pos) + dir * FLEE_DIST
		goal = Vector3.new(math.clamp(goal.X, -wanderLimit, wanderLimit), 0, math.clamp(goal.Z, -wanderLimit, wanderLimit))
		local cut, clear = Water.dryLine(pos, goal)
		local score = flat(cut - predPos).Magnitude
		if score > bestScore + 0.5 then best, bestScore, bestClear = cut, score, clear end
	end
	if not bestClear then rec.model:SetAttribute("PreyWaterCuts", (rec.model:GetAttribute("PreyWaterCuts") or 0) + 1) end
	return Vector3.new(best.X, pos.Y, best.Z)
end

local function grazeGoal(rec)
	local c = rec.group.centre
	for _ = 1, 8 do
		local a = math.random() * 2 * math.pi
		local d = math.sqrt(math.random()) * GRAZE_RADIUS
		local q = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if inside(q) and not Water.isWater(q) then
			local cut, clear = Water.dryLine(rec.hrp.Position, q)
			if clear then return Vector3.new(cut.X, rec.hrp.Position.Y, cut.Z) end
		end
	end
	return nil
end

local function setState(rec, s)
	rec.state = s
	show(rec, "PreyState", s)
end

local function stepMember(rec, now, preds)
	local m, hum, hrp = rec.model, rec.hum, rec.hrp
	-- knocked out / pinned
	local ko = m:GetAttribute("DummyState") == "ko"
	local pinned = m:GetAttribute("PinnedAt") ~= nil
	if ko and not rec.koAt then
		rec.koAt = now
		script:SetAttribute("PreyKOs", (script:GetAttribute("PreyKOs") or 0) + 1)
	end
	if rec.koAt then
		lieDown(rec)
		setState(rec, pinned and "pinned" or "ko")
		if not pinned and now - rec.koAt >= PREY_KO_REMOVE then
			recs[m] = nil
			m:Destroy() -- SurvivalServer places the carcass (downed IsBot model removed)
		end
		return
	end
	if pinned then
		lieDown(rec)
		setState(rec, "pinned")
		return
	end
	if rec.down then
		if not rec.gettingUp then standUp(rec) end
		setState(rec, "getup")
		return
	end
	-- fling guard
	local v = hrp.AssemblyLinearVelocity
	local h = flat(v)
	local hmax = 1.5 * rec.st.run
	if h.Magnitude > hmax or v.Y > 30 then
		h = h.Magnitude > hmax and h.Unit * hmax or h
		hrp.AssemblyLinearVelocity = Vector3.new(h.X, math.min(v.Y, 30), h.Z)
	end
	local predPos, d = nearest(hrp.Position, preds)
	-- state
	if rec.kind == "Compy" then
		local g = rec.group
		if rec.state ~= g.state then setState(rec, g.state) end
	else
		if rec.state ~= "hop" and predPos and d <= rec.st.alarm then
			setState(rec, "hop")
			rec.stateUntil = now + rec.st.fleeTime
			rec.nextGoalAt = 0
		elseif rec.state == "hop" and now >= rec.stateUntil then
			setState(rec, "graze")
			rec.group.centre = flat(hrp.Position)
			rec.goal, rec.waitUntil = nil, nil
		end
	end
	-- move
	if rec.state == "flee" or rec.state == "hop" or rec.state == "tired" then
		hum.WalkSpeed = rec.state == "tired" and rec.st.walk or rec.st.run
		if now >= rec.nextGoalAt and predPos then
			rec.goal = awayGoal(rec, predPos)
			rec.nextGoalAt = now + GOAL_EVERY
		end
		if rec.goal then hum:MoveTo(rec.goal) end
		rec.waitUntil = nil
	else
		hum.WalkSpeed = rec.st.walk
		if rec.goal and (flat(hrp.Position - rec.goal).Magnitude < 2 or now > rec.goalUntil) then
			rec.goal = nil
			rec.waitUntil = now + 1 + math.random() * 2
			hum:Move(Vector3.zero)
		end
		if not rec.goal and (not rec.waitUntil or now >= rec.waitUntil) then
			rec.goal = grazeGoal(rec)
			rec.goalUntil = now + 8
			rec.waitUntil = nil
		end
		if rec.goal then hum:MoveTo(rec.goal) end
	end
end

local function stepGroup(g, now, preds, players)
	-- members still here
	local live = {}
	for _, rec in ipairs(g.members) do
		if rec.model.Parent and recs[rec.model] then table.insert(live, rec) end
	end
	g.members = live
	if #live == 0 then
		groups[g.id] = nil
		if g.zone and g.zone.group == g then g.zone.group = nil end
		return
	end
	-- compy group alarm
	if g.kind == "Compy" then
		local alarmed = false
		for _, rec in ipairs(live) do
			if not rec.down then
				local _, d = nearest(rec.hrp.Position, preds)
				if d <= rec.st.alarm then alarmed = true break end
			end
		end
		local st = PM.STATS.Compy
		if g.state == "graze" and alarmed then
			g.state, g.stateUntil = "flee", now + st.fleeTime
			for _, rec in ipairs(live) do rec.nextGoalAt = 0 end
		elseif g.state == "flee" and now >= g.stateUntil then
			g.state, g.stateUntil = "tired", now + st.tiredTime
		elseif g.state == "tired" and now >= g.stateUntil then
			if alarmed then
				g.state, g.stateUntil = "flee", now + st.fleeTime
			else
				g.state = "graze"
				local sum = Vector3.zero
				for _, rec in ipairs(live) do sum += flat(rec.hrp.Position) end
				g.centre = sum / #live
				for _, rec in ipairs(live) do rec.goal, rec.waitUntil = nil, nil end
			end
		end
	end
	for _, rec in ipairs(live) do
		local ok, err = pcall(stepMember, rec, now, preds)
		if not ok then warn("PreyServer: " .. tostring(err)) end
	end
	-- despawn when no player is near and nobody is down
	local sum = Vector3.zero
	local anyDown = false
	for _, rec in ipairs(g.members) do
		sum += flat(rec.hrp.Position)
		if rec.down or rec.koAt then anyDown = true end
	end
	if #g.members == 0 then return end
	local centre = sum / #g.members
	if playerWithin(centre, DESPAWN_RADIUS, players) then
		g.farSince = nil
	else
		g.farSince = g.farSince or now
		if now - g.farSince >= DESPAWN_TIME and not anyDown then removeGroup(g, true) end
	end
end

-- spawning ---------------------------------------------------------------------------------------------------------------
local function topUp(players)
	for _, z in ipairs(zones) do
		if z.group and not groups[z.group.id] then z.group = nil end
		if not z.group and playerWithin(z.pos, ZONE_ACTIVE, players) and not playerWithin(z.pos, NO_POP, players) then
			local hit = dryGround(z.pos)
			if hit then z.group = spawnGroup(z.kind, Vector3.new(z.pos.X, hit.Position.Y, z.pos.Z), z, nil) end
		end
	end
	for _, e in ipairs(players) do
		local have = 0
		for _, g in pairs(groups) do
			if g.player == e.player then have += 1 end
		end
		local tries = 0
		while have < PLAYER_GROUPS and tries < 12 do
			tries += 1
			local a = math.random() * 2 * math.pi
			local dist = NEAR_MIN + math.random() * (NEAR_MAX - NEAR_MIN)
			local q = flat(e.pos) + Vector3.new(math.cos(a), 0, math.sin(a)) * dist
			local hit = dryGround(q)
			if hit and not playerWithin(q, NO_POP, players) then
				local kind
				if hit.Instance.Name == "Sand" then
					kind = "Crab"
				else
					playerAlt[e.player] = not playerAlt[e.player]
					kind = playerAlt[e.player] and "Compy" or "Chicken"
					local _, compies = counts()
					if kind == "Compy" and compies >= MAX_COMPIES then kind = "Chicken" end
				end
				if spawnGroup(kind, Vector3.new(q.X, hit.Position.Y, q.Z), nil, e.player) then have += 1 end
			end
		end
	end
end

local function removeAll()
	for _, g in pairs(groups) do removeGroup(g, false) end
	for m in pairs(recs) do
		if m.Parent then m:Destroy() end
	end
	recs = {}
	for _, z in ipairs(zones) do z.group = nil end
	for _, k in ipairs({"PreyCount", "PreyCompies", "PreyGroups", "PreyZonesActive"}) do script:SetAttribute(k, 0) end
end

script:GetAttributeChangedSignal("PreyEnabled"):Connect(function()
	if not enabled() then removeAll() end
end)

local acc, nextTopUp, lastWasEnabled = 0, os.clock() + FIRST_TOPUP, nil
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	acc = 0
	local on = enabled()
	if on ~= lastWasEnabled then
		lastWasEnabled = on
		script:SetAttribute("PreyServerState", on and "running" or "disabled")
	end
	if not on then return end
	local now = os.clock()
	local players = alivePlayers()
	if now >= nextTopUp then
		nextTopUp = now + TOPUP
		topUp(players)
	end
	local preds = predatorsList()
	for _, g in pairs(groups) do stepGroup(g, now, preds, players) end
	-- player links: a player who left no longer owns groups
	for _, g in pairs(groups) do
		if g.player and not g.player.Parent then g.player = nil end
	end
	local n, compies, gcount = counts()
	local active = 0
	for _, z in ipairs(zones) do
		if z.group and groups[z.group.id] then active += 1 end
	end
	if script:GetAttribute("PreyCount") ~= n then script:SetAttribute("PreyCount", n) end
	if script:GetAttribute("PreyCompies") ~= compies then script:SetAttribute("PreyCompies", compies) end
	if script:GetAttribute("PreyGroups") ~= gcount then script:SetAttribute("PreyGroups", gcount) end
	if script:GetAttribute("PreyZonesActive") ~= active then script:SetAttribute("PreyZonesActive", active) end
end)
