-- payload 30_grass (island_v3_generator 1.3 -> DinoIsland 3.2); generated, do not edit
local STAGE, DATA = "grass", {radius=15,fields=9,patches={{1,1,-130.1,512.8},{2,1,-84.9,432.5},{3,1,-104.5,451.1},{4,1,-160,519.1},{5,1,-169.5,579.4},{6,1,-144.4,598.2},{7,1,-73.6,400.9},{8,1,-134.7,487.5},{9,1,-126.6,460.7},{10,1,-110.5,416},{11,2,207.5,418.8},{12,2,305.1,383.8},{13,2,279.7,406.8},{14,2,235.9,420.1},{15,2,194.1,442.3},{16,2,345.9,354.3},{17,2,178.5,469},{18,2,305.1,413.3},{19,2,332.8,385.4},{20,2,366.8,367.9},{21,3,21,363.7},{22,3,86.3,295.9},{23,3,-39,381.7},{24,3,34.4,339},{25,3,72.4,316.2},{26,3,-9.7,364.3},{27,3,49.2,310.1},{28,3,-31.5,353.1},{29,3,3,341.2},{30,4,400.2,286.6},{31,4,420.5,262.1},{32,4,399.8,318.1},{33,4,371.3,331.1},{34,4,447.7,257.6},{35,5,-55.4,678.5},{36,5,-83.4,671.3},{37,5,-108.7,662},{38,5,-62.9,701.3},{39,6,113.7,228.4},{40,6,102,256.5},{41,6,106,199.7},{42,7,-173.4,-496.8},{43,7,-70.6,-496.2},{44,7,-126.2,-480.8},{45,7,-100.6,-480.8},{46,7,-155,-480.2},{47,8,-235.6,880.8},{48,8,-263.6,880.1},{49,8,-207.7,878.1},{50,9,448,-869.5},{51,9,479.3,-864.8},{52,9,512.4,-863}}}
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
	return ("grass: %d patches in %d fields, %d blades hash %d"):format(#folder:GetChildren(), DATA.fields, blades, dataHash(DATA.patches))
end

return "unknown STAGE " .. tostring(STAGE)
