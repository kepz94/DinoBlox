-- payload 21_trees (island_v2_generator 1.0 -> DinoIsland 2.0); generated, do not edit
local STAGE, DATA = "trees", {chunk="2/3",trees={{2,102,67.3,-54.6},{1,40,-224,313.6},{2,103,55.1,-176.1},{2,104,3,-145.7},{1,41,376,114.8},{2,105,-293.4,46.2},{2,106,79.7,-221.8},{1,42,338.4,-121},{2,107,221.5,71.4},{1,43,-184.8,240.5},{2,108,26.7,-45.8},{2,109,459.4,251.7},{2,110,301.6,170.3},{2,111,224.6,-90.5},{2,112,-148.4,403.1},{1,44,347.2,-8.3},{2,113,90.7,218.5},{2,114,289.9,416.7},{1,45,404.6,345.2},{1,46,312.2,6.2},{1,47,-195.4,271.8},{1,48,62.5,196.7},{1,49,-217.6,242},{1,50,-182.7,46.6},{1,51,279.1,-134.4},{2,115,291.5,-173.1},{1,52,-395.1,-85.8},{1,53,-189.3,80.2},{2,116,40.5,-246.8},{1,54,-383,275.5},{1,55,372.7,306.5},{2,117,32,-116.9},{1,56,349.2,-238.9},{2,118,224.3,352.1},{2,119,102.2,455.5},{2,120,348,247},{2,121,122.4,-248.7},{1,57,246.5,-306.3},{2,122,375.4,-49.7},{2,123,253.6,181.6},{1,58,231.9,-19.3},{2,124,84.8,-82.6},{2,125,229.9,-396.6},{2,126,-110.9,-152},{1,59,-327.6,-106.3},{2,127,-296.6,199.5},{2,128,-395.6,380.7},{2,129,181.8,289.6},{2,130,313.7,208},{1,60,387.4,-115.5},{2,131,202.9,208.8},{1,61,55.2,123.8},{2,132,-249.8,-128.2},{1,62,293.5,359.6},{1,63,146.2,-277.8},{2,133,218.1,-121.3},{2,134,154.3,-24},{2,135,-190.8,-159.9},{2,136,122,361.8},{2,137,-123.5,428.8},{2,138,347.8,372.1},{2,139,-150.3,-57.1},{2,140,189,-90.4},{2,141,424.1,135.8},{2,142,-449.9,167.4},{2,143,-292.1,123.2},{2,144,-234.6,385.8},{1,64,-152,42},{2,145,-198.9,351.3},{2,146,-252.3,-196.9},{2,147,373.5,387.8},{1,65,-272.2,171.5},{1,66,336.6,312.5},{2,148,26.8,-308.7},{2,149,-139,166.8},{2,150,-224.3,-172.2},{2,151,258.3,380.2},{1,67,-67.2,-247.6},{2,152,364.7,82.8},{2,153,-361.1,-87.9},{2,154,437.3,-6.5},{1,68,300.9,-361.9},{2,155,49.6,-87.5},{2,156,208.7,-255.1},{2,157,-21,159.9},{1,69,-2.4,-228.7},{2,158,-216.8,-27.9},{1,70,56.8,-327.5},{2,159,-215.4,14.3},{1,71,-114.1,24.4},{2,160,149.2,-218.4},{1,72,133.8,7.3},{2,161,-137,122.9},{2,162,-129.7,243.2},{2,163,403.2,235.7},{2,164,267.6,-328.3},{2,165,189.4,-228.5},{2,166,259.9,-103.2},{2,167,391.6,145.3},{1,73,218.3,-357.2},{2,168,464.9,156.3},{1,74,-140.3,-225.3},{1,75,-66.3,-167.3},{2,169,-53.7,-133.9},{2,170,-419.3,-40.6},{2,171,-126.7,289.4},{1,76,319.3,-398.1},{2,172,-261,223.1},{2,173,-153.9,366.2},{2,174,114.7,-213.7},{2,175,181.7,-2.3},{2,176,-172.9,-93.3},{2,177,-178.8,-45.9},{2,178,334.1,-46.6},{2,179,445.5,285.6},{1,77,316.8,-302.7},{2,180,-193.2,445.6},{2,181,7.6,169.1},{2,182,83.1,-146.7},{2,183,359.4,34.1},{1,78,-363.2,173.7},{2,184,301.5,-109.8},{1,79,283.1,-241.5},{2,185,252,-435.7},{2,186,96.5,251.2},{2,187,439.7,-87.5},{2,188,-258.2,346.3},{2,189,276.6,135.6},{2,190,188.2,-145.3},{1,80,-79.4,47.3},{2,191,253.1,116.3},{1,81,-292.5,-121.8},{2,192,347.3,-190.7},{2,193,254.5,-42.2},{2,194,425.9,176.2},{1,82,-212.8,206.9},{1,83,137.9,-341.1},{2,195,313.8,-245.5},{1,84,-297.1,400.2},{2,196,-454.9,197.6}}}
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
