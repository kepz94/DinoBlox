-- payload 22_trees (island_v3_generator 1.2 -> DinoIsland 3.1); generated, do not edit
local STAGE, DATA = "trees", {chunk="3/3",trees={{4,187,190.5,-638.8,0.4,26},{4,188,-586.5,568.9,0.9,174},{4,189,-340.1,35.2,0.1,42},{4,190,-770.3,-58,0.9,307},{4,191,323.8,-798.5,0.3,181},{4,192,485.3,456.1,0.5,309},{4,193,515.9,853.4,0.6,10},{4,194,651.1,683.8,0.1,193},{4,195,865.4,406.6,0.7,71},{4,196,388.5,-829.8,0.7,310},{4,197,-567,-94.6,0.1,161},{4,198,625.4,423.2,0.5,116},{4,199,-373.2,-90.7,0.1,165},{4,200,-550,70.5,0.1,196},{1,89,-797.2,619.2,0,0},{4,201,871.4,-383.6,0.2,185},{1,90,454.3,-563.1,0,0},{1,91,674.7,-79.3,0,0},{4,202,-807.9,181.8,0.9,220},{4,203,693.8,-634.3,0.1,356},{1,92,-476.5,-197.3,0,0},{4,204,192.6,763.7,0.9,21},{1,93,760.7,-31.6,0,0},{4,205,-609.1,315,0.6,273},{4,206,-66.5,-149.2,0.6,203},{4,207,911.7,107,0.2,209},{4,208,803.9,185.8,0.5,107},{4,209,-114.8,639.8,0.8,163},{4,210,598.6,648.3,0.7,87},{4,211,-574.5,-318.1,0.5,130},{4,212,611.9,-776.6,0.2,330},{4,213,-287.6,696.6,0.4,308},{1,94,560.6,-618.7,0,0},{4,214,3,-400.4,0.8,26},{1,95,-373.7,612.6,0,0},{1,96,-704.9,431,0,0},{4,215,-256.1,180.4,0.1,66},{4,216,49.7,-681.2,0.4,91},{4,217,-451.7,152.9,0.3,49},{4,218,826.7,-120.8,0.6,72},{1,97,560.7,-95.5,0,0},{4,219,66.4,890.1,0.2,108},{4,220,926,181.1,0.8,71},{1,98,598.8,126.3,0,0},{1,99,689.7,219,0,0},{4,221,106.7,602.7,0.1,299},{1,100,-318.2,-314.7,0,0},{4,222,-104.4,-16.4,0.4,342},{4,223,-209.9,447.2,0.3,331},{4,224,-55.3,-82.6,0.5,81},{4,225,525.7,-841.4,0.2,191},{4,226,-75.8,200.4,0.2,326},{4,227,-518,760.7,0.4,283},{4,228,-333.2,831.8,0.6,276},{4,229,314.8,592.2,0.8,212},{4,230,-312.7,149,0.7,258},{4,231,-220.7,339.5,0.2,165},{4,232,-714.9,577.4,0.7,72},{4,233,-723.3,1.6,0.7,344},{4,234,-442.4,453,0.5,151},{4,235,-41.4,-547,0.5,250},{4,236,-268.5,602.5,0.6,258},{4,237,-485.2,274.7,0.9,7},{4,238,70.6,78.1,0.1,93},{4,239,66.3,281.8,0.7,33},{4,240,-128,682.5,0.5,292},{4,241,380,398.1,0.8,265},{4,242,-189.6,7.3,0.1,305},{4,243,708.2,-229.3,0.4,215},{4,244,-51.9,-322.4,0.5,156},{4,245,-803.9,-146.8,0.5,271},{4,246,476.3,245.9,1,98},{4,247,-552.2,-135.9,0.8,156},{4,248,130.2,637.9,0.4,101},{4,249,657,-638.5,0.9,1},{4,250,663.6,594.6,0.9,305},{4,251,-678.6,758.2,0.8,106}}}
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

return "unknown STAGE " .. tostring(STAGE)
