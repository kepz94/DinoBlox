-- payload 22_trees (island_v2_generator 1.0 -> DinoIsland 2.0); generated, do not edit
local STAGE, DATA = "trees", {chunk="3/3",trees={{2,197,-325.4,121.4},{1,85,-302.2,14},{2,198,-79.7,436.4},{2,199,-177.2,170},{2,200,106.5,-277.5},{2,201,-235.7,278},{2,202,51.2,338.5},{2,203,144.2,335.1},{2,204,-150,-154.9},{2,205,237.9,207.4},{2,206,-378.1,146.3},{1,86,291.2,-209.3},{1,87,-117.2,-33.2},{2,207,415.5,273.9},{2,208,369.4,195.5},{2,209,202.4,-410.1},{2,210,177.7,183.7},{2,211,267.8,63.1},{2,212,95.3,-319.4},{2,213,137.3,-186.4},{2,214,-295.3,274.3},{1,88,-170.1,17.6},{2,215,258,426.7},{1,89,222.5,123.8},{2,216,413.6,84.6},{2,217,325.5,341.9},{1,90,19.6,-89.6},{1,91,162.7,367.4},{1,92,-328.6,396.8},{2,218,213.9,9.9},{1,93,109.2,193.2},{1,94,-59.2,176.6},{2,219,-283.5,-47.3},{2,220,376.8,-18.7},{2,221,194.1,367.5},{1,95,97,296.3},{2,222,186.6,-349.7},{2,223,198.5,-31.3},{2,224,24.3,134.7},{2,225,40.4,-147.2},{2,226,344.2,-368.8},{2,227,227.2,-281.5},{2,228,393.2,-148.4},{2,229,49.8,444.4},{2,230,343.8,403.3},{1,96,-308.7,148.8},{2,231,25.2,-4.4},{1,97,-385.4,-24.3},{2,232,266,305},{1,98,-238.4,73.1},{1,99,243,-238.5},{2,233,-238.2,-98.7},{2,234,-140,-97.8},{2,235,245.1,-134.4},{2,236,-406.6,97.7},{2,237,445.8,-140.1},{1,100,-33.3,-74.6},{1,101,-188.3,301.6},{1,102,244.1,-170},{1,103,299.3,324.1},{2,238,-130.3,93.6},{2,239,-247.4,413.4},{2,240,-406.9,348.1},{2,241,-156,227.9},{2,242,375.8,-353.7},{2,243,350.9,-310.8},{2,244,91.8,19.8},{2,245,-229.2,355.4},{2,246,414.2,-60.5},{2,247,301.7,66.5},{2,248,-224.9,-219.4},{1,104,-338.7,-21.9},{1,105,344.9,109.5},{2,249,-160.5,144.3},{1,106,370.9,226.6},{2,250,-101,222.9},{2,251,429.7,206.6},{2,252,204.3,-179.3},{2,253,-398.1,303.3},{1,107,-52.2,-8.2},{1,108,-108.6,-238.4},{2,254,-77.2,16.7},{2,255,-262.2,42.3},{1,109,-37.9,100.2},{1,110,-259,380.3},{1,111,-156.3,74.5},{1,112,-110.3,169.7},{1,113,-26.7,16},{1,114,252.5,-408.7},{1,115,-330,292.5},{1,116,-240.6,192.7},{1,117,-20,-124.8},{1,118,45.4,62.8},{1,119,-120.4,-5.4},{1,120,-154.1,312.9},{1,121,159.6,-173.1},{1,122,-276.5,96.6},{1,123,363.4,-112.6},{1,124,-370.5,-46.8},{1,125,0.4,-304},{1,126,-185.2,420.5},{3,1,-421.2,-75.5},{3,2,-180,-230.9},{3,3,464.9,-47.6},{3,4,-112.5,-252.5},{3,5,289.8,-431.5},{3,6,147.7,-404.3},{3,7,432.2,336.8},{3,8,382.5,407.4},{3,9,-445.4,137.3},{3,10,-65.9,452.4},{3,11,-366.8,46},{3,12,487.3,195.4},{3,13,457.7,-224.3},{3,14,210.7,-456.9},{3,15,-392.7,410.9},{3,16,49.5,463.7},{3,17,290.8,434.7},{3,18,-277.6,-190.7},{3,19,474.5,115.4},{3,20,23,-351.1},{3,21,-463.1,208.9},{3,22,-242.9,-276.9},{3,23,462.5,-130},{3,24,-330.2,-120.2}}}
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

return "unknown STAGE " .. tostring(STAGE)
