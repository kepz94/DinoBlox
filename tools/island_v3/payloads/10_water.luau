-- payload 10_water (island_v3_generator 1.2 -> DinoIsland 3.1); generated, do not edit
local STAGE, DATA = "water", {lakes={113,20,1,21,112,21,1,20,114,21,3,17,111,22,1,18,110,23,1,16,117,23,1,14,109,24,1,6,118,24,1,14,119,26,1,11,120,29,1,1,120,31,1,1,109,34,1,2,109,37,1,1,114,38,2,1,114,39,1,1,82,70,3,15,80,71,2,17,85,71,1,12,79,72,1,16,86,72,1,10,77,73,2,15,87,73,1,8,76,74,1,15,88,74,1,6,75,75,1,15,89,75,1,4,74,76,1,15,73,77,1,15,72,80,1,13,71,82,1,13,70,84,1,15,69,85,1,15,82,85,2,1,68,86,1,15,82,86,1,1,67,87,1,15,65,88,2,14,77,88,1,1,62,89,3,15,61,90,1,15,60,91,1,13,59,92,1,12,58,94,1,9,57,96,1,6,56,97,1,4,55,98,1,2,65,102,1,1,62,104,2,1}}
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

return "unknown STAGE " .. tostring(STAGE)
