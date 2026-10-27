-- payload 00_begin (island_v3_generator 1.0 -> DinoIsland 3.0); generated, do not edit
local STAGE, DATA = "begin", {generator="1.0",spawn={88,-0.4,904},bots={{"Raptor",219.3,0,393.5},{"Raptor",-91.8,4,-457.7},{"Raptor",-143.9,0,448.9},{"TRex",60.3,4,271.6}},half=1024,cell=16,bottom=-16}
local ServerStorage = game:GetService("ServerStorage")
local INSTALL_VERSION = "1.0"
local ISLAND_VERSION = "3.0"
local BUILD = "DinoIsland3_Build"
local CELL, HALF, BOTTOM = 16, 1024, -16 -- begin checks these against DATA
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

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function stage(name)
	build:SetAttribute("IslandBuildStage", name)
end

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
	for _, q in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do -- v3: four quadrants (a part is at most 2048 long)
		block(ground, "Seabed", Vector3.new(1700, 2, 1700), Vector3.new(q[1] * 850, -9, q[2] * 850), C.seabed, {studs = false})
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
	return ("begin: %s created (4 sea + 4 seabed quadrants, 4 walls at +/-%d, %d bot spawns)"):format(BUILD, wall + 1, #DATA.bots)
end

return "unknown STAGE " .. tostring(STAGE)
