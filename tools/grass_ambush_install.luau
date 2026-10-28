-- grass_ambush_install v1.0 (Dino Arcade) — adds the Ambush v1.0 grass to Workspace.DinoIsland.TallGrass (Studio Edit).
-- DINO-25, plan docs/plans/AMBUSH_v1.0.md Task 2, ADR-004. Run through execute_luau with one line in front of this file:
--   local MODE = "plan"   -- counts and spots only, builds nothing
--   local MODE = "place"  -- builds batch "ambush1" (refused when it already exists)
--   local MODE = "remove" -- deletes every model with GrassBatch "ambush1" and the island attributes below
-- User: "Make some grass be tall enough that a t-Rex is only hidden if it's creeping through it as well but do both
--   options" (more grass everywhere + clusters near raptor packs and lakes); option A (tall grass 17 + short grass 10);
--   red-team: at most +8,000 Workspace parts.
-- Patches (Model "AmbushGrass_<kind>_<n>", ModelStreamingMode Atomic, attributes DinoBush = true, DinoTallGrass = true,
--   GrassKind, GrassHeight, GrassBatch "ambush1", GrassSpot ("pack <marker>" / "lake" / "open")):
--   tall:  RADIUS 15, blades on a 3-stud grid (jitter 1.2, ragged edge 0-3), 17-23 tall, 0.9-1.4 wide, today's colours;
--          GrassHeight 17. 6 per raptor marker (BotSpawns Species "Raptor", the unused one too) at 45-80 studs
--          (400 tries each) + 18 on lake shores (8-40 studs outside a LakeWater rectangle, 3000 tries).
--   short: RADIUS 10, blades on a 2.5-stud grid, 9.5-11.5 tall, 1.0-1.5 wide, colours A6D35F / 9CCF5C / 8CC152 (the planned
--          3.5-stud grid looked like a thin clump in Edit, ~25 blades; 2.5 keeps the total under the +8,000 part cap);
--          GrassHeight 10. 90 on land within +/-940, at least 95 studs apart (20000 tries).
--   Blades: Plastic, Anchored, CanCollide / CanQuery / CanTouch / CastShadow false, tilt +/-9 degrees, on the ground ray.
-- A spot is valid when: 5 rays (centre + 4 at the radius) hit DinoIsland.Ground parts that are not LakeWater / Shallows /
--   Seabed / Water, every top is -0.8 .. 20 and within 3 studs of the others; at least RADIUS + 12 from every tree's
--   bounding-box centre and RADIUS + its half size + 2 from every boulder; at least 90 from the SpawnLocation; at least
--   r1 + r2 + 6 from every patch (existing or placed); a tall patch next to another tall patch only TALL_SPACING 24
--   apart (the island generator's GRASS_SPACING), so clusters join the existing fields into one (the raptor markers were
--   placed at fields: with r1 + r2 + 6 only 2 / 5 / 2 of the 6 per marker fit, plan run 2026-10-27).
--   Random seed 20261027 (same island = same spots).
-- Island attributes: IslandAmbushGrassVersion "1.0", IslandAmbushGrassTall, IslandAmbushGrassShort, IslandAmbushGrassBlades.
local MODE = MODE or "plan"
local VERSION = "1.0"
local BATCH = "ambush1"
local SEED = 20261027
local KINDS = {
	tall = {radius = 15, step = 3, jitter = 1.2, h = {17, 23}, w = {0.9, 1.4}, height = 17,
		colors = {"93BE4E", "82C455", "6FB84A", "5EA63E"}},
	short = {radius = 10, step = 2.5, jitter = 1.0, h = {9.5, 11.5}, w = {1.0, 1.5}, height = 10,
		colors = {"A6D35F", "9CCF5C", "8CC152"}},
}
local PACK_EACH, PACK_DIST, PACK_TRIES = 6, {45, 80}, 400
local LAKE_COUNT, LAKE_DIST, LAKE_TRIES = 18, {8, 40}, 3000
local SHORT_COUNT, SHORT_GAP, SHORT_TRIES, LAND = 90, 95, 20000, 940
local GAP, TREE_GAP, SPAWN_GAP = 6, 12, 90
local TALL_SPACING = 24
local BAD_GROUND = {LakeWater = true, Shallows = true, Seabed = true, Water = true}

local island = workspace:FindFirstChild("DinoIsland")
if not island then return "no DinoIsland" end
local folder = island:FindFirstChild("TallGrass")
local groundFolder = island:FindFirstChild("Ground")
if not (folder and groundFolder) then return "no TallGrass / Ground" end

local function batchModels()
	local t = {}
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("GrassBatch") == BATCH then table.insert(t, m) end
	end
	return t
end

if MODE == "remove" then
	local n = 0
	for _, m in ipairs(batchModels()) do m:Destroy() n += 1 end
	for _, k in ipairs({"IslandAmbushGrassVersion", "IslandAmbushGrassTall", "IslandAmbushGrassShort", "IslandAmbushGrassBlades"}) do
		island:SetAttribute(k, nil)
	end
	return ("removed %d patches; TallGrass now %d"):format(n, #folder:GetChildren())
end
if MODE ~= "plan" and MODE ~= "place" then return "unknown MODE " .. tostring(MODE) end
if #batchModels() > 0 then return ("refused: batch %s already has %d patches (run remove first)"):format(BATCH, #batchModels()) end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {groundFolder}
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
	if not hit or BAD_GROUND[hit.Instance.Name] then return nil end
	return hit.Position.Y
end

-- obstacles
local trees, boulders, patches = {}, {}, {}
for _, m in ipairs((island:FindFirstChild("Trees") or folder):GetChildren()) do
	if m:IsA("Model") then local cf = m:GetBoundingBox() table.insert(trees, Vector3.new(cf.Position.X, 0, cf.Position.Z)) end
end
for _, m in ipairs((island:FindFirstChild("Rocks") or folder):GetChildren()) do
	local cf, size
	if m:IsA("Model") then cf, size = m:GetBoundingBox() elseif m:IsA("BasePart") then cf, size = m.CFrame, m.Size end
	if cf then table.insert(boulders, {p = Vector3.new(cf.Position.X, 0, cf.Position.Z), r = math.max(size.X, size.Z) / 2}) end
end
for _, m in ipairs(folder:GetChildren()) do
	if m:IsA("Model") then
		local cf, size = m:GetBoundingBox()
		table.insert(patches, {p = Vector3.new(cf.Position.X, 0, cf.Position.Z), r = math.max(size.X, size.Z) / 2})
	end
end
local existing = #patches
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local spawnP = spawn and Vector3.new(spawn.Position.X, 0, spawn.Position.Z)
local lakes = {}
for _, p in ipairs(groundFolder:GetChildren()) do
	if p.Name == "LakeWater" and p:IsA("BasePart") then
		table.insert(lakes, {p.Position.X - p.Size.X / 2, p.Position.Z - p.Size.Z / 2, p.Position.X + p.Size.X / 2, p.Position.Z + p.Size.Z / 2})
	end
end

local reasons = {water = 0, slope = 0, tree = 0, boulder = 0, spawn = 0, patch = 0}
local function valid(x, z, r)
	local tops = {}
	for _, o in ipairs({{0, 0}, {r, 0}, {-r, 0}, {0, r}, {0, -r}}) do
		local y = ground(x + o[1], z + o[2])
		if not y or y < -0.8 or y > 20 then reasons.water += 1 return false end
		table.insert(tops, y)
	end
	if math.max(table.unpack(tops)) - math.min(table.unpack(tops)) > 3 then reasons.slope += 1 return false end
	local p = Vector3.new(x, 0, z)
	for _, t in ipairs(trees) do if (t - p).Magnitude < r + TREE_GAP then reasons.tree += 1 return false end end
	for _, b in ipairs(boulders) do if (b.p - p).Magnitude < r + b.r + 2 then reasons.boulder += 1 return false end end
	if spawnP and (spawnP - p).Magnitude < SPAWN_GAP then reasons.spawn += 1 return false end
	for _, q in ipairs(patches) do
		local need = (r >= KINDS.tall.radius and q.r >= KINDS.tall.radius) and TALL_SPACING or r + q.r + GAP
		if (q.p - p).Magnitude < need then reasons.patch += 1 return false end
	end
	return true
end

local rng = Random.new(SEED)
local plan = {}
local function add(kind, x, z, spot)
	local r = KINDS[kind].radius
	table.insert(patches, {p = Vector3.new(x, 0, z), r = r})
	table.insert(plan, {kind = kind, x = x, z = z, spot = spot})
end

-- 1. tall clusters around each raptor marker (sorted by name, so the order is fixed)
local markers = {}
local spawns = island:FindFirstChild("BotSpawns")
for _, m in ipairs(spawns and spawns:GetChildren() or {}) do
	if m:IsA("BasePart") and m:GetAttribute("Species") == "Raptor" then table.insert(markers, m) end
end
table.sort(markers, function(a, b) return a.Name < b.Name end)
local perMarker = {}
for _, m in ipairs(markers) do
	local got, tries = 0, 0
	while got < PACK_EACH and tries < PACK_TRIES do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(PACK_DIST[1], PACK_DIST[2])
		local x, z = m.Position.X + math.cos(a) * d, m.Position.Z + math.sin(a) * d
		if valid(x, z, KINDS.tall.radius) then add("tall", x, z, "pack " .. m.Name) got += 1 end
	end
	table.insert(perMarker, m.Name .. "=" .. got)
end
-- 2. tall patches on lake shores
local lakeGot, tries = 0, 0
while lakeGot < LAKE_COUNT and tries < LAKE_TRIES and #lakes > 0 do
	tries += 1
	local L = lakes[rng:NextInteger(1, #lakes)]
	local side = rng:NextInteger(1, 4)
	local d = rng:NextNumber(LAKE_DIST[1], LAKE_DIST[2])
	local x, z
	if side == 1 then x, z = L[1] - d, rng:NextNumber(L[2], L[4])
	elseif side == 2 then x, z = L[3] + d, rng:NextNumber(L[2], L[4])
	elseif side == 3 then x, z = rng:NextNumber(L[1], L[3]), L[2] - d
	else x, z = rng:NextNumber(L[1], L[3]), L[4] + d end
	if valid(x, z, KINDS.tall.radius) then add("tall", x, z, "lake") lakeGot += 1 end
end
-- 3. short grass spread over the land
local shortGot, shortPts = 0, {}
tries = 0
while shortGot < SHORT_COUNT and tries < SHORT_TRIES do
	tries += 1
	local x, z = rng:NextNumber(-LAND, LAND), rng:NextNumber(-LAND, LAND)
	local far = true
	for _, q in ipairs(shortPts) do
		if (q - Vector3.new(x, 0, z)).Magnitude < SHORT_GAP then far = false break end
	end
	if far and valid(x, z, KINDS.short.radius) then
		add("short", x, z, "open")
		table.insert(shortPts, Vector3.new(x, 0, z))
		shortGot += 1
	end
end

local tallN = 0
for _, s in ipairs(plan) do if s.kind == "tall" then tallN += 1 end end
local summary = ("tall %d (packs %s; lake %d) short %d | existing %d, %d trees, %d boulders, %d lake rects | rejected: water/rock %d slope %d tree %d boulder %d spawn %d patch %d")
	:format(tallN, table.concat(perMarker, ", "), lakeGot, shortGot, existing, #trees, #boulders, #lakes,
		reasons.water, reasons.slope, reasons.tree, reasons.boulder, reasons.spawn, reasons.patch)
if MODE == "plan" then return "PLAN " .. summary end

-- build
local function partsInWorkspace()
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
	return n
end
local before = partsInWorkspace()
local blades = 0
local counters = {tall = 0, short = 0}
for _, s in ipairs(plan) do
	local K = KINDS[s.kind]
	counters[s.kind] += 1
	local brng = Random.new(SEED + counters[s.kind] * 7 + (s.kind == "tall" and 0 or 100000))
	local m = Instance.new("Model")
	m.Name = ("AmbushGrass_%s_%d"):format(s.kind, counters[s.kind])
	m:SetAttribute("DinoBush", true)
	m:SetAttribute("DinoTallGrass", true)
	m:SetAttribute("GrassKind", s.kind)
	m:SetAttribute("GrassHeight", K.height)
	m:SetAttribute("GrassBatch", BATCH)
	m:SetAttribute("GrassSpot", s.spot)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local R = K.radius
	for gx = -R, R, K.step do
		for gz = -R, R, K.step do
			local x = gx + brng:NextNumber(-K.jitter, K.jitter)
			local z = gz + brng:NextNumber(-K.jitter, K.jitter)
			local edge = R - brng:NextNumber(0, 3)
			if x * x + z * z <= edge * edge then
				local gy = ground(s.x + x, s.z + z)
				if gy then
					local h = brng:NextNumber(K.h[1], K.h[2])
					local cf = CFrame.new(s.x + x, gy, s.z + z)
						* CFrame.Angles(0, brng:NextNumber(0, math.pi), 0)
						* CFrame.Angles(math.rad(brng:NextNumber(-9, 9)), 0, math.rad(brng:NextNumber(-9, 9)))
						* CFrame.new(0, h / 2, 0)
					local p = Instance.new("Part")
					p.Name = "Blade"
					p.Size = Vector3.new(brng:NextNumber(K.w[1], K.w[2]), h, 0.45)
					p.CFrame = cf
					p.Color = Color3.fromHex(K.colors[brng:NextInteger(1, #K.colors)])
					p.Material = Enum.Material.Plastic
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = false
					p.TopSurface = Enum.SurfaceType.Smooth
					p.BottomSurface = Enum.SurfaceType.Smooth
					p.Parent = m
					blades += 1
				end
			end
		end
	end
	m.Parent = folder
end
island:SetAttribute("IslandAmbushGrassVersion", VERSION)
island:SetAttribute("IslandAmbushGrassTall", counters.tall)
island:SetAttribute("IslandAmbushGrassShort", counters.short)
island:SetAttribute("IslandAmbushGrassBlades", blades)
local after = partsInWorkspace()
return ("PLACED %s | blades %d | parts %d -> %d (+%d) | TallGrass now %d"):format(summary, blades, before, after, after - before, #folder:GetChildren())
