-- BotRoam v1.0 (Dino Arcade) — where a roaming bot group goes next: path check, next spot, respawn spot.
-- DINO-28, plan docs/plans/ROAMING_v1.0.md, ADR-005. Pure: the island is read through a `sample(x, z)` function the caller
--   passes in (BotServer 1.8: the ground top under (x, z), nil for water), and randomness through a Random object.
-- User: "lets just forget the scale with your growth thingy and just have roaming bots on the map"; option B of
--   docs/mockups/roaming_options.html, random spots; red-team: no roaming within 250 studs of the spawn.
-- groundOk(top): top ~= nil and MIN_TOP (-0.8) <= top <= MAX_TOP (20) (dry, low ground; the mountain / rock tops are higher).
-- pathOk(from, to, sample, opts) -> ok, reason: samples every STEP (4) studs along the flat straight way (from excluded,
--   to included): outside +/-limit -> "limit"; sample nil or below MIN_TOP -> "water"; above MAX_TOP -> "high"; more than
--   MAX_RISE (3) above the previous sample -> "rise" (StepAssist lifts 2.6; drops are fine) -> else "ok".
-- pickSpot(rng, from, sample, opts) -> spot (Vector3 at the ground top) or nil, tries: up to opts.tries (40) candidates at a
--   random angle and a random distance minDist (250) .. maxDist (650) from `from`; the first inside +/-limit, at least
--   dist from every opts.avoid {pos, dist} and passing pathOk.
-- respawnSpot(rng, sample, players, opts) -> spot or nil: up to RESPAWN_TRIES (200) random points inside +/-limit with
--   groundOk, at least PLAYER_DIST (150) from every player position and dist from every opts.avoid.
local BotRoam = {}
BotRoam.Version = "1.0"
BotRoam.STEP = 4
BotRoam.MAX_RISE = 3
BotRoam.MIN_TOP = -0.8
BotRoam.MAX_TOP = 20
BotRoam.LIMIT = 920
BotRoam.MIN_DIST = 250
BotRoam.MAX_DIST = 650
BotRoam.TRIES = 40
BotRoam.PLAYER_DIST = 150
BotRoam.RESPAWN_TRIES = 200

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

function BotRoam.groundOk(top)
	return top ~= nil and top >= BotRoam.MIN_TOP and top <= BotRoam.MAX_TOP
end

function BotRoam.pathOk(from, to, sample, opts)
	local limit = (opts and opts.limit) or BotRoam.LIMIT
	local a = flat(from)
	local d = flat(to) - a
	local len = d.Magnitude
	local prev = sample(a.X, a.Z)
	if len < 1e-3 then return true, "ok" end
	local dir = d / len
	local s = 0
	while s < len do
		s = math.min(len, s + BotRoam.STEP)
		local q = a + dir * s
		if math.abs(q.X) > limit or math.abs(q.Z) > limit then return false, "limit" end
		local top = sample(q.X, q.Z)
		if top == nil or top < BotRoam.MIN_TOP then return false, "water" end
		if top > BotRoam.MAX_TOP then return false, "high" end
		if prev ~= nil and top - prev > BotRoam.MAX_RISE then return false, "rise" end
		prev = top
	end
	return true, "ok"
end

local function farFromAll(p, list)
	for _, a in ipairs(list or {}) do
		if (flat(a.pos) - flat(p)).Magnitude < a.dist then return false end
	end
	return true
end

function BotRoam.pickSpot(rng, from, sample, opts)
	local limit = (opts and opts.limit) or BotRoam.LIMIT
	local minD = (opts and opts.minDist) or BotRoam.MIN_DIST
	local maxD = (opts and opts.maxDist) or BotRoam.MAX_DIST
	local tries = (opts and opts.tries) or BotRoam.TRIES
	local base = flat(from)
	for i = 1, tries do
		local ang = rng:NextNumber(0, 2 * math.pi)
		local dist = rng:NextNumber(minD, maxD)
		local p = base + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		if math.abs(p.X) <= limit and math.abs(p.Z) <= limit and farFromAll(p, opts and opts.avoid)
			and BotRoam.pathOk(base, p, sample, opts) then
			return Vector3.new(p.X, sample(p.X, p.Z), p.Z), i
		end
	end
	return nil, tries
end

function BotRoam.respawnSpot(rng, sample, players, opts)
	local limit = (opts and opts.limit) or BotRoam.LIMIT
	local playerDist = (opts and opts.playerDist) or BotRoam.PLAYER_DIST
	local tries = (opts and opts.tries) or BotRoam.RESPAWN_TRIES
	for _ = 1, tries do
		local x, z = rng:NextNumber(-limit, limit), rng:NextNumber(-limit, limit)
		local top = sample(x, z)
		if BotRoam.groundOk(top) then
			local p = Vector3.new(x, top, z)
			local ok = farFromAll(p, opts and opts.avoid)
			if ok then
				for _, pl in ipairs(players or {}) do
					if (flat(pl) - flat(p)).Magnitude < playerDist then ok = false break end
				end
			end
			if ok then return p end
		end
	end
	return nil
end

return BotRoam
