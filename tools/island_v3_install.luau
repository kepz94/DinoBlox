-- island_v3_install v1.2 (Dino Arcade) — builds Workspace.DinoIsland 3.1 (run in Studio Edit mode via execute_luau).
-- Do not run this file alone: tools/island_v3/island_v3_generator.py writes tools/island_v3/payloads/NN_<stage>.luau,
-- each = "local STAGE, DATA = ..." + the sections of this file that stage needs ("--@section" markers: common, then
-- begin, or guard + the stage's own section, then tail), without full-line comments. Paste them in order (00_begin ...
-- 99_finish). Based on tools/island_v2_install.luau 1.0 (kept unchanged for island 2.0).
-- User: "double the size of the map ... there needs to be elevation as well ... the lakes on the map will be for
--   crocodiles to attack at ... as well as that open field area" ... "the trees themselves should be mostly coconut
--   trees. ranging from thick based tall trees to skinnier long ones" ... "that should be the trees near the coast line
--   then once you enter higher elevation then we should have different type of trees there".
-- Changes from island_v2_install 1.0:
--   * size from DATA: half 1024 (2048 x 2048), cell 16; every ground block runs from DATA.bottom (-36) to its top
--     (lake beds go down to -30.8, below the seabed).
--   * sea: four "Water" parts (1700 x 1700 each, top -0.8: ShakeOffServer reads the first one's top) and four "Seabed"
--     parts (top -8; 1.1: rectangles around the lakes) cover +/- 1700; edge walls at +/- (half + 60).
--   * LakeWater parts are 30.4 thick (top -0.8, down to -31.2) so the 30-stud-deep lake middles are filled
--     (user: "the lakes should be deeper" -> ~30, steeper bowl).
--   * trees: kind 4 = "CoconutPalm_n" (new): shape t (0 = thick-based tall, ~4.6 studs at the base, ~34 tall, nearly
--     straight; 1 = skinny long, ~2 studs at the base, ~52 tall, strongly curved), lean yaw from the data (beach palms
--     lean away from the centre). Ringed Trunk segments (collide), crown, 8 two-piece drooping fronds, 2 tufts,
--     3 coconuts. Kinds 1 (jungle) and 2 (pine) unchanged.
--   * finish: IslandVersion "3.0", IslandHalfSize 940, IslandWanderLimit 920; the build is Workspace.DinoIsland3_Build.
-- Everything else (ground names / colours, boulders, tall grass, bot spawns, manifest check, backup of the old island to
-- ServerStorage.DinoArcade_TestAreaBackup, spawn move, diagnostics) is as island_v2_install 1.0; IslandPalms counts
-- coconut palms.
-- Changelog:
--   1.0  first version.
--   1.1  begin: the "Seabed" parts (top -8) come from DATA.seabed (generator 1.1): rectangles that leave each lake's box
--        open. 1.0 laid four 1700 x 1700 seabed quadrants that cut through every lake at -8 (lakes ~7 studs deep
--        instead of ~30). Refuses a payload without DATA.seabed; sets IslandSeabedBlocks; finish checks it; begin
--        returns the seabed data hash. Water quadrants, walls and everything else unchanged.
--   1.2  DinoIsland 3.1 (generator 1.2: middle + south lakes joined into one lake; ~200-stud mountain on the north
--        ridge with 14-stud cliff bands and one spiral trail). Ground kind 7 = "Trail" (new colours trail / trailDark,
--        alternating per 2-stud step). ISLAND_VERSION "3.1" (finish backs the 3.0 island up as DinoIsland_v3.0).
--@section common
local ServerStorage = game:GetService("ServerStorage")
local INSTALL_VERSION = "1.2"
local ISLAND_VERSION = "3.1" -- v1.2 (3.0 with installer 1.0 / 1.1)
local BUILD = "DinoIsland3_Build"
local CELL, HALF, BOTTOM = 16, 1024, -36 -- begin checks these against DATA
local WATER_TOP = -0.8

local C = { -- island 1.0 COLORS + island 1.1 C (same hex values)
	grass = Color3.fromHex("6AAE45"), grassDark = Color3.fromHex("5A9A3B"), sand = Color3.fromHex("E6D29A"),
	sandWet = Color3.fromHex("C9B57E"), water = Color3.fromHex("3FA7D6"), seabed = Color3.fromHex("A8955F"),
	rock = Color3.fromHex("8A8D91"), rockDark = Color3.fromHex("6E7175"),
	meadow = Color3.fromHex("93BE4E"), meadowDark = Color3.fromHex("82B548"),
	trail = Color3.fromHex("D6B270"), trailDark = Color3.fromHex("C4A062"), -- v1.2: mountain trail (dirt path)
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

-- data hash (same as island_v3_generator data_hash): every number in order, x10 rounded; each stage returns it so the
-- pasted data can be checked against tools/island_v3/manifest.json ("hashes")
local function dataHash(t, h)
	h = h or 7
	for _, v in ipairs(t) do
		if type(v) == "table" then
			h = dataHash(v, h)
		elseif type(v) == "number" then
			h = (h * 31 + math.floor(v * 10 + 0.5) % 1000003 + 1000003) % 2147483647
		end
	end
	return h
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
	if DATA.half ~= HALF or DATA.cell ~= CELL or DATA.bottom ~= BOTTOM then return "begin refused: data size does not match this installer" end
	build:SetAttribute("IslandSpawnPos", Vector3.new(DATA.spawn[1], DATA.spawn[2], DATA.spawn[3]))
	for _, n in ipairs({"Ground", "Rocks", "Trees", "TallGrass", "BotSpawns", "Bots", "EdgeWalls"}) do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = build
	end
	local ground = build.Ground
	if type(DATA.seabed) ~= "table" or #DATA.seabed == 0 or #DATA.seabed % 4 ~= 0 then
		build:Destroy()
		return "begin refused: DATA.seabed missing (generator 1.1+ payload needed)"
	end
	local sb = DATA.seabed -- v1.1: sea floor rectangles {x0, z0, x1, z1} that leave the lakes open
	for k = 1, #sb, 4 do
		local x0, z0, x1, z1 = sb[k], sb[k + 1], sb[k + 2], sb[k + 3]
		block(ground, "Seabed", Vector3.new(x1 - x0, 2, z1 - z0), Vector3.new((x0 + x1) / 2, -9, (z0 + z1) / 2), C.seabed, {studs = false})
	end
	build:SetAttribute("IslandSeabedBlocks", #sb // 4)
	for _, q in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do -- v3: four quadrants (a part is at most 2048 long)
		local water = block(ground, "Water", Vector3.new(1700, 7.2, 1700), Vector3.new(q[1] * 850, WATER_TOP - 3.6, q[2] * 850), C.water,
			{collide = false, query = false, transparency = 0.35, studs = false, shadow = false})
		water.Material = Enum.Material.SmoothPlastic
	end
	local wall = HALF + 60
	for _, s in ipairs({1, -1}) do
		block(build.EdgeWalls, "Wall_X", Vector3.new(2, 120, 2 * wall + 4), Vector3.new(s * (wall + 1), 50, 0), C.water,
			{query = false, transparency = 1, studs = false, shadow = false})
		block(build.EdgeWalls, "Wall_Z", Vector3.new(2 * wall + 4, 120, 2), Vector3.new(0, 50, s * (wall + 1)), C.water,
			{query = false, transparency = 1, studs = false, shadow = false})
	end
	for i, b in ipairs(DATA.bots) do
		local p = block(build.BotSpawns, "BotSpawn_" .. i .. "_" .. b[1], Vector3.new(4, 1, 4), Vector3.new(b[2], b[3] + 0.5, b[4]),
			C.sand, {collide = false, query = false, transparency = 1, studs = false})
		p:SetAttribute("Species", b[1])
	end
	build.Parent = workspace
	stage("begin")
	return ("begin: %s created (4 sea quadrants + %d seabed blocks, 4 walls at +/-%d, %d bot spawns) hash %d"):format(BUILD, #sb // 4,
		wall + 1, #DATA.bots, dataHash(DATA.seabed))
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
		local h = top - BOTTOM -- v3: from BOTTOM (lake beds reach below the seabed)
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
		elseif kind == 7 then -- v1.2: mountain trail, colour alternates per 2-stud step so the stair reads
			name, color = "Trail", step == 0 and C.trail or C.trailDark
		else
			name, color = "Shallows", top > -3 and C.sandWet or C.seabed
		end
		block(ground, name, Vector3.new(w * CELL, h, d * CELL), Vector3.new(cx, top - h / 2, cz), color, opts)
		made += 1
		if made % 300 == 0 then task.wait() end
	end
	build:SetAttribute("IslandGroundBlocks", (build:GetAttribute("IslandGroundBlocks") or 0) + made)
	stage("ground")
	return ("ground chunk %s: %d blocks (total %d) hash %d"):format(DATA.chunk, made, build:GetAttribute("IslandGroundBlocks"), dataHash(DATA.rects))
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
		local p = block(ground, "LakeWater", Vector3.new(w * CELL, 30.4, d * CELL), Vector3.new(cx, WATER_TOP - 15.2, cz), C.water,
			{collide = false, query = false, transparency = 0.35, studs = false, shadow = false})
		p.Material = Enum.Material.SmoothPlastic
		made += 1
	end
	build:SetAttribute("IslandLakeBlocks", made)
	stage("water")
	return ("water: %d lake surface blocks hash %d"):format(made, dataHash(DATA.lakes))
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
	return ("rocks: %d boulders (%d parts) hash %d"):format(#DATA.boulders, countParts(folder), dataHash(DATA.boulders))
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

-- v3 new: coconut palm. t = 0 thick-based tall (base ~4.6, 7 segments, ~34 studs, nearly straight) .. 1 skinny long
-- (base ~2, 10 segments, ~52 studs, strongly curved). leanYaw (degrees): the way the trunk curves.
local function coconutPalm(parent, i, x, z, gy, t, leanYaw)
	local rng = Random.new(5000 + i)
	local m = Instance.new("Model")
	m.Name = "CoconutPalm_" .. i
	local segs = 7 + math.floor(t * 3 + 0.5)
	local segH = 4.6 + 0.6 * t
	local baseW, topW = 4.6 - 2.6 * t, 1.8 - 0.6 * t
	local bend = 1.2 + 3.6 * t -- degrees per segment, growing towards the top
	local cf = CFrame.new(x, gy, z) * CFrame.Angles(0, math.rad(leanYaw + rng:NextNumber(-10, 10)), 0)
	for k = 1, segs do
		cf = cf * CFrame.Angles(math.rad(-(bend * (0.4 + 0.12 * k)) + rng:NextNumber(-0.5, 0.5)), 0, 0)
		local u = (k - 1) / math.max(1, segs - 1)
		local w = baseW + (topW - baseW) * u
		if k == 1 then w = w * (1.12 + 0.1 * (1 - t)) end -- flared foot (thick palms most)
		part(m, "Trunk", Vector3.new(w, segH + 0.3, w), cf * CFrame.new(0, segH / 2, 0), k % 2 == 0 and C.palmRing or C.palmTrunk,
			{collide = true, studs = true})
		cf = cf * CFrame.new(0, segH, 0)
	end
	local crown = CFrame.new(cf.Position) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	local size = 1.15 - 0.25 * t -- thick palms carry bigger crowns
	part(m, "Crown", Vector3.new(3.2, 2.2, 3.2) * size, crown, C.palmRing, {studs = true})
	for f = 1, 8 do
		local fy = (f / 8) * 2 * math.pi + rng:NextNumber(-0.15, 0.15)
		local color = f % 2 == 0 and C.frondDark or C.frond
		local seg = crown * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, fy, 0) * CFrame.Angles(math.rad(rng:NextNumber(6, 16)), 0, 0)
		for k, piece in ipairs({{2.8, 7.5}, {1.8, 6}}) do
			local len = piece[2] * size
			part(m, "Frond", Vector3.new(piece[1] * size, 0.5, len), seg * CFrame.new(0, 0, -len / 2), color, {studs = true})
			seg = seg * CFrame.new(0, 0, -len) * CFrame.Angles(math.rad(-30 - k * 8), 0, 0)
		end
	end
	for k = 1, 2 do
		local seg = crown * CFrame.Angles(0, k * 3.1, 0) * CFrame.Angles(math.rad(55), 0, 0)
		part(m, "Tuft", Vector3.new(1.6, 0.45, 4.5) * size, seg * CFrame.new(0, 0, -2.2 * size), C.frond, {studs = true})
	end
	for k = 1, 3 do
		local a = k * 2.1
		part(m, "Coconut", Vector3.new(1.5, 1.5, 1.5), crown * CFrame.new(math.cos(a) * 1.7, -1.7, math.sin(a) * 1.7), C.coconut, {studs = true})
	end
	m.Parent = parent
end

-- DATA.trees: {kind (1 jungle, 2 pine, 3 palm (1.1), 4 coconut palm), index, x, z, shape t, lean yaw}
if STAGE == "trees" then
	local folder = build.Trees
	local made = {0, 0, 0}
	for n, t in ipairs(DATA.trees) do
		local kind, idx, x, z = t[1], t[2], t[3], t[4]
		local gy = groundAt(x, z)
		if kind == 1 then jungleTree(folder, idx, x, z, gy)
		elseif kind == 2 then pineTree(folder, idx, x, z, gy)
		elseif kind == 4 then coconutPalm(folder, idx, x, z, gy, t[5] or 0, t[6] or 0)
		else palmTree(folder, idx, x, z, gy) end
		made[kind == 4 and 3 or kind] += 1
		if n % 10 == 0 then task.wait() end
	end
	for k, a in ipairs({"IslandJungleTrees", "IslandPines", "IslandPalms"}) do
		build:SetAttribute(a, (build:GetAttribute(a) or 0) + made[k])
	end
	build:SetAttribute("IslandTrees", #folder:GetChildren())
	stage("trees")
	return ("trees chunk %s: jungle %d, pine %d, palm %d (folder now %d trees, %d parts) hash %d"):format(DATA.chunk, made[1], made[2], made[3],
		#folder:GetChildren(), countParts(folder), dataHash(DATA.trees))
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
	return ("grass: %d patches in %d fields, %d blades hash %d"):format(#folder:GetChildren(), DATA.fields, blades, dataHash(DATA.patches))
end

--@section finish
---------------------------------------------------------------- finish
if STAGE == "finish" then
	-- check the build against the generator's manifest
	local e = DATA.expect
	local got = {
		ground = build:GetAttribute("IslandGroundBlocks"), lakes = build:GetAttribute("IslandLakeBlocks"),
		boulders = build:GetAttribute("IslandBoulders"), trees = #build.Trees:GetChildren(), patches = #build.TallGrass:GetChildren(),
		spawns = #build.BotSpawns:GetChildren(), seabed = build:GetAttribute("IslandSeabedBlocks"), -- v1.1: seabed
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
	build:SetAttribute("IslandHalfSize", 940)
	build:SetAttribute("IslandWanderLimit", 920)
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
