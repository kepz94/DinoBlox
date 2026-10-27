-- payload 00_begin (island_v3_generator 1.3 -> DinoIsland 3.2); generated, do not edit
local STAGE, DATA = "begin", {generator="1.3",spawn={88,-0.4,904},bots={{"Raptor",-152.7,0,476.9},{"Raptor",-89.6,4,-461.6},{"Raptor",238.6,2,446.4},{"TRex",60,0,349.9}},half=1024,cell=16,bottom=-50,seabed={-1024,-1024,0,0,-1024,0,0,384,-1024,384,-48,400,-1024,400,-64,416,-1024,416,-80,432,-1024,432,-96,464,-1024,464,-112,496,-1024,496,-128,512,-1024,512,-144,528,-1024,528,-160,1024,-160,592,-144,1024,-144,608,-128,1024,-128,624,-112,1024,-112,640,-96,1024,-96,656,-64,1024,-64,672,0,1024,0,-1024,1024,-720,0,-720,768,-704,816,-720,1024,-704,0,-704,752,-688,864,-704,1024,-672,0,-688,736,-672,0,-672,720,-656,880,-672,1024,-656,0,-656,704,0,896,-656,1024,-624,912,-624,1024,-576,928,-576,1024,0,704,-528,720,-496,912,-496,928,0,896,-416,912,0,704,-400,720,0,848,-400,896,0,720,-384,736,0,832,-384,848,0,736,-368,752,0,816,-368,832,0,752,-352,816,0,0,0,1024,80,0,80,272,96,352,80,1024,96,0,96,240,112,368,96,1024,112,0,112,224,128,384,112,1024,128,0,128,192,144,400,128,1024,144,0,144,176,160,416,144,1024,160,0,160,160,176,432,160,1024,1024,0,176,144,192,0,192,128,240,0,240,112,272,416,256,432,1024,0,272,96,304,400,272,416,1024,384,288,400,1024,0,304,80,320,368,304,384,1024,0,320,64,336,352,320,368,1024,0,336,48,352,0,352,32,368,336,352,352,1024,320,368,336,1024,304,384,320,1024,240,400,304,1024,208,416,240,1024,192,432,208,1024,176,448,192,1024,160,464,176,1024,144,480,160,1024,128,512,144,1024,112,576,128,1024,96,592,112,1024,80,608,96,1024,48,624,80,1024,32,640,48,1024,16,656,32,1024,0,672,16,1024,-1700,-1700,0,-1024,0,-1700,1700,-1024,-1700,-1024,-1024,0,-1700,0,-1024,1024,-1700,1024,0,1700,0,1024,1700,1700,1024,-1024,1700,0,1024,0,1700,1024}}
local ServerStorage = game:GetService("ServerStorage")
local INSTALL_VERSION = "1.3"
local ISLAND_VERSION = "3.2" -- v1.3 (3.1 with installer 1.2, 3.0 with 1.0 / 1.1)
local BUILD = "DinoIsland3_Build"
local CELL, HALF, BOTTOM = 16, 1024, -50 -- begin checks these against DATA (v1.3: BOTTOM -36 -> -50)
local WATER_TOP = -0.8
local LAKE_TRANSPARENCY = 0.1 -- v1.3: murky (1.0-1.2: 0.35, sea blue); the sea Water parts keep 0.35 / water blue

local C = { -- island 1.0 COLORS + island 1.1 C (same hex values)
	grass = Color3.fromHex("6AAE45"), grassDark = Color3.fromHex("5A9A3B"), sand = Color3.fromHex("E6D29A"),
	sandWet = Color3.fromHex("C9B57E"), water = Color3.fromHex("3FA7D6"), seabed = Color3.fromHex("A8955F"),
	rock = Color3.fromHex("8A8D91"), rockDark = Color3.fromHex("6E7175"),
	meadow = Color3.fromHex("93BE4E"), meadowDark = Color3.fromHex("82B548"),
	trail = Color3.fromHex("D6B270"), trailDark = Color3.fromHex("C4A062"), -- v1.2: mountain trail (dirt path)
	lakeMurky = Color3.fromHex("52693B"), -- v1.3: murky olive-green lake water (crocodiles hide under it)
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
	for k = 1, #sb, 4 do -- v1.3: sea "Water" over the same rectangles as the seabed (1.0-1.2: four 1700 x 1700 quadrants,
		local x0, z0, x1, z1 = sb[k], sb[k + 1], sb[k + 2], sb[k + 3]
		local water = block(ground, "Water", Vector3.new(x1 - x0, 7.2, z1 - z0), Vector3.new((x0 + x1) / 2, WATER_TOP - 3.6, (z0 + z1) / 2), C.water,
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
	return ("begin: %s created (%d sea + %d seabed blocks, 4 walls at +/-%d, %d bot spawns) hash %d"):format(BUILD, #sb // 4, #sb // 4,
		wall + 1, #DATA.bots, dataHash(DATA.seabed))
end

return "unknown STAGE " .. tostring(STAGE)
