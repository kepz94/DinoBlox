-- IslandWater v1.0 (Dino Arcade) — the island's water test and dry-path helpers, for PreyServer 1.0 (DINO-13).
-- The same rules as BotServer 1.5 (BotServer keeps its own copy, unchanged): a point is water when the ray down onto
-- DinoIsland.Ground hits nothing, a "Shallows" or "Seabed" part, or ground below WATER_Y (-0.8). Cached per
-- WATER_CELL (2) studs.
--   IslandWater.isWater(p) -> bool
--   IslandWater.groundHit(x, z) -> RaycastResult? (top of DinoIsland.Ground)
--   IslandWater.dryLine(from, to) -> (point, clear): `to` and true when the straight way is dry; else the dry sample
--     SHORE_MARGIN samples (WATER_STEP 4 studs apart) before the first water, and false
--   IslandWater.nearestDry(p) -> point? (rings WATER_STEP .. 120 studs, 16 directions)
local IslandWater = {}
IslandWater.Version = "1.0"
local WATER_Y, WATER_CELL, WATER_STEP, SHORE_MARGIN = -0.8, 2, 4, 1

local params, cache = nil, {}
local function ensure()
	if params then return true end
	local island = workspace:FindFirstChild("DinoIsland")
	local ground = island and island:FindFirstChild("Ground")
	if not ground then return false end
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {ground}
	return true
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

function IslandWater.groundHit(x, z)
	if not ensure() then return nil end
	return workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
end

function IslandWater.isWater(p)
	local cx, cz = math.floor(p.X / WATER_CELL), math.floor(p.Z / WATER_CELL)
	local key = cx .. ":" .. cz
	local v = cache[key]
	if v == nil then
		local hit = IslandWater.groundHit((cx + 0.5) * WATER_CELL, (cz + 0.5) * WATER_CELL)
		v = (hit == nil) or hit.Instance.Name == "Shallows" or hit.Instance.Name == "Seabed" or hit.Position.Y < WATER_Y
		cache[key] = v
	end
	return v
end

function IslandWater.dryLine(from, to)
	local a = flat(from)
	local d = flat(to) - a
	local len = d.Magnitude
	if len < 1e-3 then return to, not IslandWater.isWater(to) end
	local dir = d / len
	local kept = {a}
	local s = 0
	while s < len do
		s = math.min(len, s + WATER_STEP)
		local q = a + dir * s
		if IslandWater.isWater(q) then return kept[math.max(1, #kept - SHORE_MARGIN)], false end
		table.insert(kept, q)
	end
	return to, true
end

function IslandWater.nearestDry(p)
	for r = WATER_STEP, 120, WATER_STEP do
		for i = 0, 15 do
			local a = i * math.pi / 8
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local q = flat(p) + dir * r
			if not IslandWater.isWater(q) then return q + dir * WATER_STEP end
		end
	end
	return nil
end

return IslandWater
