-- island_install v1.0 (Dino Arcade) — builds the small test island "Workspace.DinoIsland" (run once in Studio Edit
-- mode via execute_luau / the command bar). Blocky studded style like the dinos.
-- Layout (studs, ground top y = 0, centre at the origin):
--   Grass:  stepped octagon — core 320 x 320 + side strips 25 deep x 220 wide on all four sides (|x|,|z| <= 185).
--   Sand:   ring around it, top y = -0.4 (core 370 x 370 + side strips to 210).
--   Shallows: 472 x 472 sand under the water, top y = -2.2 (water top y = -0.8, so dinos wade at the edge).
--   Water:  1600 x 1600, top y = -0.8, see-through, no collision / no queries. Seabed top y = -8.
--   Edge:   four invisible walls at |x|, |z| = 236 keep everyone on the island (CanQuery false).
--   Hills:  two stepped grass hills (2-stud steps a dino walks up). Rocks: 8 grey blocks. Trees: 10 (trunk + two
--           leaf blocks).
--   Bushes: 14 models "Bush_n" (attribute DinoBush = true), 4 leaf blocks each, ~12 x 6 x 12; no collision, no
--           queries, no touch. BotServer 1.0 treats a player whose HumanoidRootPart is inside a bush's bounding box
--           as hidden.
--   BotSpawns: invisible markers with attribute Species ("Raptor" x 3, "TRex" x 1) read by BotServer 1.0.
--   SpawnLocation (the existing one) moved to (0, 0.5, 150) on the south grass.
-- The old test area is kept, not deleted: Baseplate, DinoArcade_TRex, DinoArcade_Raptor and BiteDummy are moved to
--   ServerStorage.DinoArcade_TestAreaBackup (BiteDummy 1.1 no longer builds a dummy while DinoIsland exists).
-- Attributes on DinoIsland: IslandVersion, IslandHalfSize (185 = grass), IslandWanderLimit (165).
local ServerStorage = game:GetService("ServerStorage")
local VERSION = "1.0"

if workspace:FindFirstChild("DinoIsland") then return "DinoIsland already exists (delete it first to rebuild)" end

local COLORS = {
	grass = Color3.fromHex("6AAE45"), grassDark = Color3.fromHex("5A9A3B"), sand = Color3.fromHex("E6D29A"),
	sandWet = Color3.fromHex("C9B57E"), water = Color3.fromHex("3FA7D6"), seabed = Color3.fromHex("A8955F"),
	rock = Color3.fromHex("8A8D91"), rockDark = Color3.fromHex("6E7175"), trunk = Color3.fromHex("7A5232"),
	leaf = Color3.fromHex("3E8E3A"), leafDark = Color3.fromHex("2F7A30"), bush = Color3.fromHex("4CA040"),
	bushDark = Color3.fromHex("3B8A33"),
}

-- backup of the old test area
local backup = ServerStorage:FindFirstChild("DinoArcade_TestAreaBackup")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "DinoArcade_TestAreaBackup"
	backup.Parent = ServerStorage
end
local moved = {}
for _, name in ipairs({"Baseplate", "DinoArcade_TRex", "DinoArcade_Raptor", "BiteDummy"}) do
	local o = workspace:FindFirstChild(name)
	if o then o.Parent = backup; table.insert(moved, name) end
end

local island = Instance.new("Model")
island.Name = "DinoIsland"
island:SetAttribute("IslandVersion", VERSION)
island:SetAttribute("IslandHalfSize", 185)
island:SetAttribute("IslandWanderLimit", 165)

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = island
	return f
end

-- opts: collide (default true), query (default true), transparency, studs (top studs, default true), all (studs all sides)
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
	p.Parent = parent
	return p
end

-- ground: grass / sand / shallows (non-overlapping pieces per layer; layers have different tops)
local ground = folder("Ground")
local function octagon(name, top, thick, core, strip, stripWide, color)
	local y = top - thick / 2
	block(ground, name .. "_Core", Vector3.new(core * 2, thick, core * 2), Vector3.new(0, y, 0), color)
	local d = (strip - core)
	for _, s in ipairs({1, -1}) do
		block(ground, name .. "_X" .. (s > 0 and "E" or "W"), Vector3.new(d, thick, stripWide * 2), Vector3.new(s * (core + d / 2), y, 0), color)
		block(ground, name .. "_Z" .. (s > 0 and "S" or "N"), Vector3.new(stripWide * 2, thick, d), Vector3.new(0, y, s * (core + d / 2)), color)
	end
end
octagon("Grass", 0, 6, 160, 185, 110, COLORS.grass)
octagon("Sand", -0.4, 6, 185, 210, 130, COLORS.sand)
block(ground, "Shallows", Vector3.new(472, 4, 472), Vector3.new(0, -2.2 - 2, 0), COLORS.sandWet)
block(ground, "Seabed", Vector3.new(1600, 2, 1600), Vector3.new(0, -9, 0), COLORS.seabed, {studs = false})
local water = block(ground, "Water", Vector3.new(1600, 7.2, 1600), Vector3.new(0, -0.8 - 3.6, 0), COLORS.water,
	{collide = false, query = false, transparency = 0.35, studs = false})
water.Material = Enum.Material.SmoothPlastic
local walls = folder("EdgeWalls")
for _, s in ipairs({1, -1}) do
	block(walls, "Wall_X", Vector3.new(2, 60, 476), Vector3.new(s * 237, 28, 0), COLORS.water, {query = false, transparency = 1, studs = false})
	block(walls, "Wall_Z", Vector3.new(476, 60, 2), Vector3.new(0, 28, s * 237), COLORS.water, {query = false, transparency = 1, studs = false})
end

-- hills: 2-stud steps
local hills = folder("Hills")
local function hill(name, x, z, tiers)
	for i, t in ipairs(tiers) do
		block(hills, name .. "_" .. i, Vector3.new(t[1], 2, t[2]), Vector3.new(x, 1 + 2 * (i - 1), z), i % 2 == 1 and COLORS.grassDark or COLORS.grass)
	end
end
hill("Hill1", -90, -70, {{70, 60}, {50, 42}, {30, 26}})
hill("Hill2", 95, 60, {{56, 48}, {34, 30}})

-- rocks
local rocks = folder("Rocks")
local ROCKS = {
	{-30, -80, Vector3.new(8, 5, 7), 20}, {120, -40, Vector3.new(10, 6, 9), -15}, {-130, -50, Vector3.new(7, 4, 6), 35},
	{40, 110, Vector3.new(9, 5, 8), 10}, {-90, 40, Vector3.new(6, 4, 6), -30}, {140, 140, Vector3.new(12, 7, 10), 25},
	{-150, 150, Vector3.new(8, 5, 8), -10}, {10, -30, Vector3.new(5, 3, 5), 40},
}
for i, r in ipairs(ROCKS) do
	local cf = CFrame.new(r[1], r[3].Y / 2, r[2]) * CFrame.Angles(0, math.rad(r[4]), 0)
	block(rocks, "Rock_" .. i, r[3], cf, i % 2 == 0 and COLORS.rockDark or COLORS.rock, {all = true})
end

-- trees
local trees = folder("Trees")
local TREES = {{-140, -120}, {-60, -150}, {30, -140}, {140, -110}, {-150, 20}, {150, 10}, {-100, 110}, {110, 120}, {-20, 40}, {60, -60}}
for i, t in ipairs(TREES) do
	local m = Instance.new("Model")
	m.Name = "Tree_" .. i
	block(m, "Trunk", Vector3.new(3, 14, 3), Vector3.new(t[1], 7, t[2]), COLORS.trunk, {all = true})
	block(m, "Leaves", Vector3.new(14, 6, 14), Vector3.new(t[1], 16, t[2]), COLORS.leaf, {all = true})
	block(m, "LeavesTop", Vector3.new(9, 4, 9), Vector3.new(t[1], 21, t[2]), COLORS.leafDark, {all = true})
	m.Parent = trees
end

-- bushes (hiding spots): no collision / queries / touch
local bushes = folder("Bushes")
local BUSHES = {{-30, 120}, {35, 125}, {-80, 70}, {60, 100}, {-130, -10}, {130, -20}, {-60, -30}, {50, 20}, {-100, -140},
	{90, -140}, {-10, -110}, {0, 70}, {-150, 90}, {150, 60}}
local LEAVES = { -- offset x, z, size
	{0, 0, Vector3.new(8, 5, 8)}, {4, 3, Vector3.new(6, 4, 6)}, {-4, 2, Vector3.new(5, 6, 5)}, {1, -4, Vector3.new(6, 4, 5)},
}
for i, b in ipairs(BUSHES) do
	local m = Instance.new("Model")
	m.Name = "Bush_" .. i
	m:SetAttribute("DinoBush", true)
	for k, l in ipairs(LEAVES) do
		local cf = CFrame.new(b[1] + l[1], l[3].Y / 2, b[2] + l[2]) * CFrame.Angles(0, math.rad((i * 37 + k * 23) % 40 - 20), 0)
		block(m, "Leaves_" .. k, l[3], cf, k % 2 == 0 and COLORS.bushDark or COLORS.bush, {collide = false, query = false, all = true})
	end
	m.Parent = bushes
end

-- bot spawn markers
local spawns = folder("BotSpawns")
local BOTS = {{"Raptor", -140, -90}, {"Raptor", 120, -80}, {"Raptor", -20, -60}, {"TRex", 40, -100}}
for i, b in ipairs(BOTS) do
	local p = block(spawns, "BotSpawn_" .. i .. "_" .. b[1], Vector3.new(4, 1, 4), Vector3.new(b[2], 0.5, b[3]), COLORS.sand,
		{collide = false, query = false, transparency = 1, studs = false})
	p:SetAttribute("Species", b[1])
end
folder("Bots")

island.Parent = workspace

-- player spawn on the south grass
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if spawn then
	spawn.CFrame = CFrame.new(0, spawn.Size.Y / 2, 150)
end

local count = 0
for _, d in ipairs(island:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
return ("DinoIsland %s built: %d parts; moved to backup: %s; spawn %s"):format(VERSION, count, table.concat(moved, ", "),
	spawn and tostring(spawn.Position) or "none")
