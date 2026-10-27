-- island_v2_install v1.0 (Dino Arcade) — builds Workspace.DinoIsland 2.0 (run in Studio Edit mode via execute_luau).
-- Do not run this file alone: tools/island_v2/island_v2_generator.py writes tools/island_v2/payloads/NN_<stage>.luau,
-- each = "local STAGE, DATA = ..." + the sections of this file that stage needs ("--@section" markers: common, then
-- begin, or guard + the stage's own section, then tail), without full-line comments. Paste them in order (00_begin ...
-- 99_finish).
-- User: "create a better map ... medium sized ... model it after this picture but turn it into an island ... art style
--   of our current game ... tall grass field sections for hunting near water". Answers: 1024 x 1024; back up 1.1 and
--   replace; photo layout only; lakes act like the sea.
-- Layout (from the generator, 8-stud cells, x / z in [-512, 512], photo north = -Z):
--   Ground blocks: greedy rectangles of equal (surface, top) cells, each from y = -8 (seabed top) up to its top.
--     Forest floor "Grass" (tops 0..10 in 2-stud steps, colours alternate per step like the island 1.0 hills),
--     "Meadow" (photo meadow + lake shores + hunting-field clearings, tops 0 / 2), "RockGround" (grey terraced
--     outcrops up to 30, studs on every side), "Sand" (beach, top -0.4), "Shallows" (sea shelf top -2.2 and every lake
--     bed: rim -2.2, inside -4.2). The name "Shallows" is what ShakeOffServer 1.1's water test looks for, so lakes count
--     as water with no code change.
--   Ground.Water: the sea, 1600 x 1600, top -0.8 (same part as island 1.0: ShakeOffServer reads its top).
--   Ground.Seabed 1600 x 1600, top -8. Ground "LakeWater" parts: lake surfaces, top -0.8, see-through, no collision /
--     no queries / no touch (not named "Water", so ShakeOffServer still reads the sea's top).
--   EdgeWalls: four invisible walls at |x|, |z| = 560.
--   Rocks: boulders (one or two studded grey blocks).
--   Trees: "JungleTree_n" and "Palm_n" (island 1.1 builders, unchanged apart from the ground height) and "Pine_n"
--     (new blocky conifer: Trunk1 / Trunk2 + four alternating leaf tiers + tip, ~32 studs tall). Trunk* / Root parts
--     collide (RamServer / RamTest / ShakeOffServer find trees by those names); leaves don't.
--   TallGrass: "TallGrass_n" patches (island 1.1 blades, radius 15) grouped into hunting fields next to lakes and the
--     coast. Attributes DinoBush = true, DinoTallGrass = true, TallGrassField = field number. ModelStreamingMode Atomic.
--   BotSpawns: 3 x Raptor + 1 x TRex markers (attribute Species) next to the fields. Bots: empty folder (BotServer).
-- Ground heights for trees / boulders / blades come from a ray down onto the Ground folder.
-- Build: everything goes into Workspace.DinoIsland2_Build; "finish" moves the current Workspace.DinoIsland to
--   ServerStorage.DinoArcade_TestAreaBackup as "DinoIsland_v1.1" (not deleted), renames the build to DinoIsland and
--   moves the SpawnLocation to the south beach.
-- Diagnostics (DinoIsland attributes): IslandVersion "2.0", IslandHalfSize 470, IslandWanderLimit 460,
--   IslandGeneratorVersion, IslandInstallVersion, IslandBuildStage (begin / ground / water / rocks / trees / grass / done),
--   IslandGroundBlocks, IslandLakeBlocks, IslandBoulders, IslandTrees, IslandPines, IslandJungleTrees, IslandPalms,
--   IslandTallGrassPatches, IslandTallGrassFields, IslandParts. Each stage returns its counts.
--@section common
local ServerStorage = game:GetService("ServerStorage")
local INSTALL_VERSION = "1.0"
local ISLAND_VERSION = "2.0"
local BUILD = "DinoIsland2_Build"
local CELL, HALF = 8, 512
local WATER_TOP = -0.8

local C = { -- island 1.0 COLORS + island 1.1 C (same hex values)
	grass = Color3.fromHex("6AAE45"), grassDark = Color3.fromHex("5A9A3B"), sand = Color3.fromHex("E6D29A"),
	sandWet = Color3.fromHex("C9B57E"), water = Color3.fromHex("3FA7D6"), seabed = Color3.fromHex("A8955F"),
	rock = Color3.fromHex("8A8D91"), rockDark = Color3.fromHex("6E7175"),
	meadow = Color3.fromHex("93BE4E"), meadowDark = Color3.fromHex("82B548"),
	trunk = Color3.fromHex("6B4A2E"), trunkDark = Color3.fromHex("553A23"), root = Color3.fromHex("5E4129"),
	leaf = Color3.fromHex("3E8E3A"), leafDark = Color3.fromHex("2F7A30"), leafLight = Color3.fromHex("58A845"),
	palmTrunk = Color3.fromHex("B08A5A"), palmRing = Color3.fromHex("8F6D43"), frond = Color3.fromHex("4FA83C"),
	frondDark = Color3.fromHex("3D8F2F"), coconut = Color3.fromHex("5A3D22"),
	blades = {Color3.fromHex("6FB84A"), Color3.fromHex("5EA63E"), Color3.fromHex("82C455"), Color3.fromHex("93BE4E")},
}

-- island 1.0 block(): top studs (or all sides), collides by default
local function block(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CanQuery = opts.query ~= false
	p.CanTouch = false
	p.Transparency = opts.transparency or 0
	p.TopSurface = opts.studs == false and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.all then
		for _, f in ipairs({"Top", "Front", "Back", "Left", "Right"}) do p[f .. "Surface"] = Enum.SurfaceType.Studs end
	end
	if opts.shadow == false then p.CastShadow = false end
	p.Parent = parent
	return p
end

-- island 1.1 part(): no collision unless asked, studs on every side when asked
local function part(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.query ~= false
	p.CanTouch = false
	p.CastShadow = opts.shadow ~= false
	local surf = opts.studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	for _, f in ipairs({"Top", "Front", "Back", "Left", "Right"}) do p[f .. "Surface"] = surf end
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function countParts(inst)
	local n = 0
	for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
	return n
end

local build = workspace:FindFirstChild(BUILD)

-- ground height under (x, z): ray down onto the Ground folder only
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function stage(name)
	build:SetAttribute("IslandBuildStage", name)
end

--@section begin
---------------------------------------------------------------- begin
if STAGE == "begin" then
	local cur = workspace:FindFirstChild("DinoIsland")
	if cur and cur:GetAttribute("IslandVersion") == ISLAND_VERSION then return "DinoIsland is already " .. ISLAND_VERSION end
	if build then return "a " .. BUILD .. " already exists (delete it to start over)" end
	build = Instance.new("Model")
	build.Name = BUILD
	build:SetAttribute("IslandGeneratorVersion", DATA.generator)
	build:SetAttribute("IslandInstallVersion", INSTALL_VERSION)
	build:SetAttribute("IslandSpawnPos", Vector3.new(DATA.spawn[1], DATA.spawn[2], DATA.spawn[3]))
	for _, n in ipairs({"Ground", "Rocks", "Trees", "TallGrass", "BotSpawns", "Bots", "EdgeWalls"}) do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = build
	end
	local ground = build.Ground
	block(ground, "Seabed", Vector3.new(1600, 2, 1600), Vector3.new(0, -9, 0), C.seabed, {studs = false})
	local water = block(ground, "Water", Vector3.new(1600, 7.2, 1600), Vector3.new(0, WATER_TOP - 3.6, 0), C.water,
		{collide = false, query = false, transparency = 0.35, studs = false, shadow = false})
	water.Material = Enum.Material.SmoothPlastic
	for _, s in ipairs({1, -1}) do
		block(build.EdgeWalls, "Wall_X", Vector3.new(2, 80, 1124), Vector3.new(s * 561, 30, 0), C.water,
			{query = false, transparency = 1, studs = false, shadow = false})
		block(build.EdgeWalls, "Wall_Z", Vector3.new(1124, 80, 2), Vector3.new(0, 30, s * 561), C.water,
			{query = false, transparency = 1, studs = false, shadow = false})
	end
	for i, b in ipairs(DATA.bots) do
		local p = block(build.BotSpawns, "BotSpawn_" .. i .. "_" .. b[1], Vector3.new(4, 1, 4), Vector3.new(b[2], b[3] + 0.5, b[4]),
			C.sand, {collide = false, query = false, transparency = 1, studs = false})
		p:SetAttribute("Species", b[1])
	end
	build.Parent = workspace
	stage("begin")
	return ("begin: %s created (sea, seabed, 4 walls, %d bot spawns)"):format(BUILD, #DATA.bots)
end

--@section guard
if not build then return "no " .. BUILD .. " (run the 00_begin payload first)" end
groundParams.FilterDescendantsInstances = {build.Ground}

--@section ground
---------------------------------------------------------------- ground
-- DATA.rects: flat {i0, j0, w, d, kind, top x 10, ...}; kind 1 Grass, 2 Meadow, 3 RockGround, 4 Sand, 5 Shallows (sea),
-- 6 Shallows (lake bed)
if STAGE == "ground" then
	local ground = build.Ground
	local r = DATA.rects
	local made = 0
	for k = 1, #r, 6 do
		local i0, j0, w, d, kind, top = r[k], r[k + 1], r[k + 2], r[k + 3], r[k + 4], r[k + 5] / 10
		local h = top + 8
		local cx = -HALF + (i0 + w / 2) * CELL
		local cz = -HALF + (j0 + d / 2) * CELL
		local step = math.floor(top / 2 + 0.5) % 2 -- colour alternates per 2-stud step
		local name, color, opts
		if kind == 1 then
			name, color = "Grass", step == 0 and C.grass or C.grassDark
		elseif kind == 2 then
			name, color = "Meadow", step == 0 and C.meadow or C.meadowDark
		elseif kind == 3 then
			name, color, opts = "RockGround", step == 0 and C.rock or C.rockDark, {all = true}
		elseif kind == 4 then
			name, color = "Sand", C.sand
		elseif kind == 5 then
			name, color = "Shallows", C.sandWet
		else
			name, color = "Shallows", top > -3 and C.sandWet or C.seabed
		end
		block(ground, name, Vector3.new(w * CELL, h, d * CELL), Vector3.new(cx, top - h / 2, cz), color, opts)
		made += 1
		if made % 300 == 0 then task.wait() end
	end
	build:SetAttribute("IslandGroundBlocks", (build:GetAttribute("IslandGroundBlocks") or 0) + made)
	stage("ground")
	return ("ground chunk %s: %d blocks (total %d)"):format(DATA.chunk, made, build:GetAttribute("IslandGroundBlocks"))
end

--@section water
---------------------------------------------------------------- water (lake surfaces)
if STAGE == "water" then
	local ground = build.Ground
	local r = DATA.lakes
	local made = 0
	for k = 1, #r, 4 do
		local i0, j0, w, d = r[k], r[k + 1], r[k + 2], r[k + 3]
		local cx = -HALF + (i0 + w / 2) * CELL
		local cz = -HALF + (j0 + d / 2) * CELL
		local p = block(ground, "LakeWater", Vector3.new(w * CELL, 3.4, d * CELL), Vector3.new(cx, WATER_TOP - 1.7, cz), C.water,
			{collide = false, query = false, transparency = 0.35, studs = false, shadow = false})
		p.Material = Enum.Material.SmoothPlastic
		made += 1
	end
	build:SetAttribute("IslandLakeBlocks", made)
	stage("water")
	return ("water: %d lake surface blocks"):format(made)
end

--@section rocks
---------------------------------------------------------------- rocks (boulders)
-- DATA.boulders: {x, z, sx, sy, sz, yaw, dark, two}
if STAGE == "rocks" then
	local folder = build.Rocks
	for n, b in ipairs(DATA.boulders) do
		local x, z, sx, sy, sz, yaw, dark, two = table.unpack(b)
		local gy = groundAt(x, z)
		local cf = CFrame.new(x, gy + sy / 2 - 0.5, z) * CFrame.Angles(0, math.rad(yaw), 0)
		block(folder, "Rock_" .. n, Vector3.new(sx, sy, sz), cf, dark == 1 and C.rockDark or C.rock, {all = true})
		if two == 1 then
			local s2 = Vector3.new(sx * 0.6, sy * 0.7, sz * 0.6)
			block(folder, "Rock_" .. n .. "_top", s2, cf * CFrame.new(sx * 0.12, sy / 2 + s2.Y / 2, -sz * 0.1) * CFrame.Angles(0, math.rad(25), 0),
				dark == 1 and C.rock or C.rockDark, {all = true})
		end
	end
	build:SetAttribute("IslandBoulders", #DATA.boulders)
	stage("rocks")
	return ("rocks: %d boulders (%d parts)"):format(#DATA.boulders, countParts(folder))
end

--@section trees
---------------------------------------------------------------- trees
-- island 1.1 jungle tree (unchanged apart from the ground height gy)
local function jungleTree(parent, i, x, z, gy)
	local rng = Random.new(2000 + i)
	local m = Instance.new("Model")
	m.Name = "JungleTree_" .. i
	local base = CFrame.new(x, gy, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	local SEGS = {{5.6, rng:NextNumber(11, 13), C.trunk}, {4.6, rng:NextNumber(10, 12), C.trunkDark}, {3.6, rng:NextNumber(9, 11), C.trunk}}
	local cf = base
	local joints = {}
	for k, sgm in ipairs(SEGS) do
		part(m, "Trunk" .. k, Vector3.new(sgm[1], sgm[2] + 0.6, sgm[1]), cf * CFrame.new(0, sgm[2] / 2, 0), sgm[3], {collide = true, studs = true})
		cf = cf * CFrame.new(0, sgm[2], 0) * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-5, 5)))
		joints[k] = cf
	end
	local top = cf
	for r = 1, 5 do
		local yaw = r * 2 * math.pi / 5 + rng:NextNumber(-0.25, 0.25)
		part(m, "Root", Vector3.new(1.8, 4.5, 5), base * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 1.4, 3.4) * CFrame.Angles(math.rad(38), 0, 0),
			C.root, {collide = true, studs = true})
	end
	for b = 1, 3 do
		local yaw = b * 2 * math.pi / 3 + rng:NextNumber(-0.35, 0.35)
		local from = (b == 3) and joints[1] or joints[2]
		local len = rng:NextNumber(9, 11)
		local start = from * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(rng:NextNumber(38, 48)), 0, 0)
		part(m, "Branch", Vector3.new(1.8, 1.8, len), start * CFrame.new(0, 0, -len / 2), C.trunkDark, {studs = true})
		local tip = (start * CFrame.new(0, 0, -len)).Position
		local spin = CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
		part(m, "Leaves", Vector3.new(11, 5, 11), CFrame.new(tip + Vector3.new(0, 1.5, 0)) * spin, b % 2 == 0 and C.leafDark or C.leaf, {studs = true})
		part(m, "LeavesTop", Vector3.new(7, 3.5, 7), CFrame.new(tip + Vector3.new(rng:NextNumber(-1, 1), 5, rng:NextNumber(-1, 1))) * spin,
			C.leafLight, {studs = true})
	end
	local cy = top.Position
	local spin = CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	part(m, "Canopy", Vector3.new(22, 7, 22), CFrame.new(cy + Vector3.new(0, 2.5, 0)) * spin, C.leaf, {studs = true})
	part(m, "Canopy2", Vector3.new(15, 6, 15), CFrame.new(cy + Vector3.new(rng:NextNumber(-2, 2), 8, rng:NextNumber(-2, 2))) * spin, C.leafLight, {studs = true})
	part(m, "Canopy3", Vector3.new(8, 4, 8), CFrame.new(cy + Vector3.new(rng:NextNumber(-2, 2), 12.5, rng:NextNumber(-2, 2))) * spin, C.leafDark, {studs = true})
	for k = 1, 2 do
		local a = rng:NextNumber(0, 2 * math.pi)
		part(m, "CanopySide", Vector3.new(11, 5, 11), CFrame.new(cy + Vector3.new(math.cos(a) * 10, 1, math.sin(a) * 10)) * spin, C.leafDark, {studs = true})
	end
	for v = 1, 4 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local len = rng:NextNumber(6, 10)
		part(m, "Vine", Vector3.new(0.5, len, 0.5), CFrame.new(cy + Vector3.new(math.cos(a) * 9.5, -1 - len / 2, math.sin(a) * 9.5)), C.leafDark)
	end
	m.Parent = parent
end

-- island 1.1 palm (unchanged; leans away from the island centre)
local function palmTree(parent, i, x, z, groundY)
	local rng = Random.new(3000 + i)
	local m = Instance.new("Model")
	m.Name = "Palm_" .. i
	local yaw = math.atan2(-x, -z) + rng:NextNumber(-0.6, 0.6)
	local cf = CFrame.new(x, groundY, z) * CFrame.Angles(0, yaw, 0)
	local segH = 3
	for s = 1, 8 do
		cf = cf * CFrame.Angles(math.rad(-2.5 - s * 0.5), 0, 0)
		local w = 2.5 - s * 0.1
		part(m, "Trunk", Vector3.new(w, segH + 0.3, w), cf * CFrame.new(0, segH / 2, 0), s % 2 == 0 and C.palmRing or C.palmTrunk,
			{collide = true, studs = true})
		cf = cf * CFrame.new(0, segH, 0)
	end
	local crown = CFrame.new(cf.Position)
	part(m, "Crown", Vector3.new(2.8, 2, 2.8), crown, C.palmRing, {studs = true})
	for f = 1, 9 do
		local fy = (f / 9) * 2 * math.pi + rng:NextNumber(-0.12, 0.12)
		local color = f % 2 == 0 and C.frondDark or C.frond
		local seg = crown * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, fy, 0) * CFrame.Angles(math.rad(rng:NextNumber(8, 16)), 0, 0)
		for k, piece in ipairs({{2.4, 5}, {2, 5}, {1.3, 4}}) do
			part(m, "Frond", Vector3.new(piece[1], 0.45, piece[2]), seg * CFrame.new(0, 0, -piece[2] / 2), color, {studs = true})
			seg = seg * CFrame.new(0, 0, -piece[2]) * CFrame.Angles(math.rad(-22 - k * 6), 0, 0)
		end
	end
	for t = 1, 3 do
		local seg = crown * CFrame.Angles(0, t * 2.1, 0) * CFrame.Angles(math.rad(55), 0, 0)
		part(m, "Tuft", Vector3.new(1.4, 0.4, 4), seg * CFrame.new(0, 0, -2), C.frond, {studs = true})
	end
	for k = 1, 4 do
		local a = k * 1.6
		part(m, "Coconut", Vector3.new(1.3, 1.3, 1.3), crown * CFrame.new(math.cos(a) * 1.5, -1.5, math.sin(a) * 1.5), C.coconut, {studs = true})
	end
	m.Parent = parent
end

-- new: blocky conifer for the dense forest (7 parts, ~32 studs tall: above the 17-23-stud grass like the jungle trees)
local function pineTree(parent, i, x, z, gy)
	local rng = Random.new(4000 + i)
	local m = Instance.new("Model")
	m.Name = "Pine_" .. i
	local base = CFrame.new(x, gy, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local h1 = rng:NextNumber(7, 9)
	part(m, "Trunk1", Vector3.new(3.4, h1 + 0.6, 3.4), base * CFrame.new(0, h1 / 2, 0), C.trunk, {collide = true, studs = true})
	part(m, "Trunk2", Vector3.new(2.4, 12, 2.4), base * CFrame.new(0, h1 + 6, 0), C.trunkDark, {collide = true, studs = true})
	local scale = rng:NextNumber(0.9, 1.12)
	local TIERS = {{16, C.leafDark}, {12.5, C.leaf}, {9, C.leafDark}, {5.5, C.leaf}}
	local y = h1 + 2.5
	for k, t in ipairs(TIERS) do
		local w = t[1] * scale
		part(m, "Leaves" .. k, Vector3.new(w, 4.5, w), base * CFrame.new(0, y, 0) * CFrame.Angles(0, (k % 2) * math.pi / 4, 0), t[2], {studs = true})
		y += 5
	end
	part(m, "LeavesTip", Vector3.new(2.6, 3, 2.6), base * CFrame.new(0, y - 1, 0), C.leafLight, {studs = true})
	m.Parent = parent
end

-- DATA.trees: {kind (1 jungle, 2 pine, 3 palm), index, x, z}
if STAGE == "trees" then
	local folder = build.Trees
	local made = {0, 0, 0}
	for n, t in ipairs(DATA.trees) do
		local kind, idx, x, z = t[1], t[2], t[3], t[4]
		local gy = groundAt(x, z)
		if kind == 1 then jungleTree(folder, idx, x, z, gy)
		elseif kind == 2 then pineTree(folder, idx, x, z, gy)
		else palmTree(folder, idx, x, z, gy) end
		made[kind] += 1
		if n % 10 == 0 then task.wait() end
	end
	for k, a in ipairs({"IslandJungleTrees", "IslandPines", "IslandPalms"}) do
		build:SetAttribute(a, (build:GetAttribute(a) or 0) + made[k])
	end
	build:SetAttribute("IslandTrees", #folder:GetChildren())
	stage("trees")
	return ("trees chunk %s: jungle %d, pine %d, palm %d (folder now %d trees, %d parts)"):format(DATA.chunk, made[1], made[2], made[3],
		#folder:GetChildren(), countParts(folder))
end

--@section grass
---------------------------------------------------------------- tall grass (island 1.1 blades, radius DATA.radius)
-- DATA.patches: {index, field, x, z}
if STAGE == "grass" then
	local folder = build.TallGrass
	local RADIUS, STEP = DATA.radius, 3
	local blades = 0
	for _, pt in ipairs(DATA.patches) do
		local idx, field, cx, cz = pt[1], pt[2], pt[3], pt[4]
		local rng = Random.new(1000 + idx)
		local m = Instance.new("Model")
		m.Name = "TallGrass_" .. idx
		m:SetAttribute("DinoBush", true)
		m:SetAttribute("DinoTallGrass", true)
		m:SetAttribute("TallGrassField", field)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for gx = -RADIUS, RADIUS, STEP do
			for gz = -RADIUS, RADIUS, STEP do
				local x = gx + rng:NextNumber(-1.2, 1.2)
				local z = gz + rng:NextNumber(-1.2, 1.2)
				local edge = RADIUS - rng:NextNumber(0, 3)
				if x * x + z * z <= edge * edge then
					local h = rng:NextNumber(17, 23)
					local gy = groundAt(cx + x, cz + z)
					local cf = CFrame.new(cx + x, gy, cz + z)
						* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
						* CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), 0, math.rad(rng:NextNumber(-9, 9)))
						* CFrame.new(0, h / 2, 0)
					part(m, "Blade", Vector3.new(rng:NextNumber(0.9, 1.4), h, 0.45), cf, C.blades[rng:NextInteger(1, #C.blades)])
					blades += 1
				end
			end
		end
		m.Parent = folder
		task.wait()
	end
	build:SetAttribute("IslandTallGrassPatches", #folder:GetChildren())
	build:SetAttribute("IslandTallGrassFields", DATA.fields)
	stage("grass")
	return ("grass: %d patches in %d fields, %d blades"):format(#folder:GetChildren(), DATA.fields, blades)
end

--@section finish
---------------------------------------------------------------- finish
if STAGE == "finish" then
	-- check the build against the generator's manifest
	local e = DATA.expect
	local got = {
		ground = build:GetAttribute("IslandGroundBlocks"), lakes = build:GetAttribute("IslandLakeBlocks"),
		boulders = build:GetAttribute("IslandBoulders"), trees = #build.Trees:GetChildren(), patches = #build.TallGrass:GetChildren(),
		spawns = #build.BotSpawns:GetChildren(),
	}
	local bad = {}
	for k, v in pairs(e) do
		if got[k] ~= v then table.insert(bad, ("%s %s~=%s"):format(k, tostring(got[k]), tostring(v))) end
	end
	if #bad > 0 then return "finish refused, build incomplete: " .. table.concat(bad, ", ") end
	-- back up the current island (not deleted)
	local backup = ServerStorage:FindFirstChild("DinoArcade_TestAreaBackup")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "DinoArcade_TestAreaBackup"
		backup.Parent = ServerStorage
	end
	local old = workspace:FindFirstChild("DinoIsland")
	local oldName = "none"
	if old then
		oldName = "DinoIsland_v" .. tostring(old:GetAttribute("IslandVersion") or "?")
		old.Name = oldName
		old.Parent = backup
	end
	build.Name = "DinoIsland"
	build:SetAttribute("IslandVersion", ISLAND_VERSION)
	build:SetAttribute("IslandHalfSize", 470)
	build:SetAttribute("IslandWanderLimit", 460)
	build:SetAttribute("IslandParts", countParts(build))
	stage("done")
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local sp = build:GetAttribute("IslandSpawnPos")
	if spawn and sp then spawn.CFrame = CFrame.new(sp.X, sp.Y + spawn.Size.Y / 2, sp.Z) end
	return ("DinoIsland %s installed: %d parts; old island -> ServerStorage.DinoArcade_TestAreaBackup.%s; spawn %s")
		:format(ISLAND_VERSION, build:GetAttribute("IslandParts"), oldName, spawn and tostring(spawn.Position) or "none")
end

--@section tail
return "unknown STAGE " .. tostring(STAGE)
