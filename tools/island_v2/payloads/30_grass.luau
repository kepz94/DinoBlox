-- payload 30_grass (island_v2_generator 1.0 -> DinoIsland 2.0); generated, do not edit
local STAGE, DATA = "grass", {radius=15,fields=6,patches={{1,1,200.1,143.3},{2,1,139.8,203.4},{3,1,223.2,99.8},{4,1,41.4,157.3},{5,1,-19.5,190.9},{6,1,71.4,260.6},{7,1,74.7,79.7},{8,2,143.9,32.7},{9,2,172.2,39.1},{10,2,106.6,55},{11,2,118.6,33.6},{12,2,200.7,41.9},{13,2,159.1,10.7},{14,2,77.4,41.9},{15,3,401.2,-174.6},{16,3,431.9,-185.4},{17,3,432,-160.5},{18,4,-400.4,129.1},{19,4,-336.2,64.7},{20,4,-355.1,-5},{21,4,-394.4,-49.3},{22,4,-337.4,15.5},{23,4,-334.1,39.4},{24,4,-374.1,114.7},{25,5,440.4,54.6},{26,5,453,179.3},{27,5,438.7,79.3},{28,5,436,253.4},{29,5,445.5,223.7},{30,5,441.2,154.7},{31,5,437,104.1},{32,6,-22.9,-246},{33,6,-87,-228.7},{34,6,-117.3,-215.3},{35,6,3.6,-258.4},{36,6,16.2,-284},{37,6,-31.1,-216.5},{38,6,-59.1,-215.3}}}
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

if not build then return "no " .. BUILD .. " (run the 00_begin payload first)" end
groundParams.FilterDescendantsInstances = {build.Ground}

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

return "unknown STAGE " .. tostring(STAGE)
