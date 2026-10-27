-- payload 99_finish (island_v3_generator 1.1 -> DinoIsland 3.0); generated, do not edit
local STAGE, DATA = "finish", {expect={ground=4725,lakes=49,boulders=109,trees=405,patches=54,spawns=4,seabed=88}}
local ServerStorage = game:GetService("ServerStorage")
local INSTALL_VERSION = "1.1"
local ISLAND_VERSION = "3.0"
local BUILD = "DinoIsland3_Build"
local CELL, HALF, BOTTOM = 16, 1024, -36 -- begin checks these against DATA
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

if not build then return "no " .. BUILD .. " (run the 00_begin payload first)" end
groundParams.FilterDescendantsInstances = {build.Ground}

if STAGE == "finish" then
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

return "unknown STAGE " .. tostring(STAGE)
