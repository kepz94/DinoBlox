-- island_decor v1.1 (Dino Arcade) — upgrades Workspace.DinoIsland 1.0 (tools/island_install.luau) to 1.1 (run once in
-- Studio Edit mode). User: "tall grass not bushes, and better designed trees".
-- 1. The 1.0 Bushes and Trees folders are moved (not deleted) to ServerStorage.DinoArcade_TestAreaBackup as
--    "Island1.0_Bushes" / "Island1.0_Trees".
-- 2. TallGrass (folder "TallGrass"): 14 patches "TallGrass_n" at the 1.0 bush spots (two nudged off a rock / hill), each
--    ~28 x 28 studs of thin blocky blades 17-23 studs tall (T-Rex height: both dinos can hide), on a jittered 3-stud
--    grid trimmed to a rough circle, random yaw / slight lean, four greens. Blades: no collision / queries / touch.
--    Patch attributes DinoBush = true (the hiding rule of BotServer / BushView) and DinoTallGrass = true;
--    ModelStreamingMode Atomic (each patch streams in whole).
-- 3. Trees (folder "Trees"): 10 blocky jungle trees at the 1.0 tree spots, ~33 studs tall (well above the 20-stud
--    grass) — tapered three-segment trunk, five buttress roots, three side branches below the crown each with its
--    own two-block leaf cluster, a wide layered canopy (22 / 15 / 8 + two side lumps) and four hanging vines — and
--    8 palm trees on the beach — 8 ringed trunk segments in a gentle curve away from the island, 9 three-piece
--    drooping fronds, a short upright tuft, 4 coconuts.
--    Trunks and roots collide; leaves, branches and fronds do not (CanQuery stays on so the camera avoids them).
-- Shapes are seeded (Random.new(seed per item)), so a rebuild gives the same island.
-- DinoIsland attribute IslandVersion -> "1.1".
local ServerStorage = game:GetService("ServerStorage")
local VERSION = "1.1"

local island = workspace:FindFirstChild("DinoIsland")
if not island then return "no DinoIsland (run tools/island_install.luau first)" end
if island:GetAttribute("IslandVersion") == VERSION then return "DinoIsland is already " .. VERSION end

local C = {
	trunk = Color3.fromHex("6B4A2E"), trunkDark = Color3.fromHex("553A23"), root = Color3.fromHex("5E4129"),
	leaf = Color3.fromHex("3E8E3A"), leafDark = Color3.fromHex("2F7A30"), leafLight = Color3.fromHex("58A845"),
	palmTrunk = Color3.fromHex("B08A5A"), palmRing = Color3.fromHex("8F6D43"), frond = Color3.fromHex("4FA83C"),
	frondDark = Color3.fromHex("3D8F2F"), coconut = Color3.fromHex("5A3D22"),
	grass = {Color3.fromHex("6FB84A"), Color3.fromHex("5EA63E"), Color3.fromHex("82C455"), Color3.fromHex("93BE4E")},
}

-- 1. back up the 1.0 decor
local backup = ServerStorage:FindFirstChild("DinoArcade_TestAreaBackup")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "DinoArcade_TestAreaBackup"
	backup.Parent = ServerStorage
end
for _, name in ipairs({"Bushes", "Trees"}) do
	local f = island:FindFirstChild(name)
	if f then
		f.Name = "Island1.0_" .. name
		f.Parent = backup
	end
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

-- 2. tall grass
local grassFolder = Instance.new("Folder")
grassFolder.Name = "TallGrass"
local PATCHES = {{-30, 120}, {35, 132}, {-80, 70}, {60, 100}, {-130, -10}, {130, -20}, {-50, -20}, {50, 20}, {-100, -140},
	{90, -140}, {-10, -110}, {0, 70}, {-150, 90}, {150, 60}}
local RADIUS, STEP = 14, 3
local bladeCount = 0
for i, c in ipairs(PATCHES) do
	local rng = Random.new(1000 + i)
	local m = Instance.new("Model")
	m.Name = "TallGrass_" .. i
	m:SetAttribute("DinoBush", true)
	m:SetAttribute("DinoTallGrass", true)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- streams in whole (BushView needs the full bounding box)
	for gx = -RADIUS, RADIUS, STEP do
		for gz = -RADIUS, RADIUS, STEP do
			local x = gx + rng:NextNumber(-1.2, 1.2)
			local z = gz + rng:NextNumber(-1.2, 1.2)
			local edge = RADIUS - rng:NextNumber(0, 3) -- ragged edge
			if x * x + z * z <= edge * edge then
				local h = rng:NextNumber(17, 23)
				local cf = CFrame.new(c[1] + x, 0, c[2] + z)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
					* CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), 0, math.rad(rng:NextNumber(-9, 9)))
					* CFrame.new(0, h / 2, 0) -- lean about the base
				part(m, "Blade", Vector3.new(rng:NextNumber(0.9, 1.4), h, 0.45), cf, C.grass[rng:NextInteger(1, #C.grass)])
				bladeCount += 1
			end
		end
	end
	m.Parent = grassFolder
end
grassFolder.Parent = island

-- 3. trees
local treeFolder = Instance.new("Folder")
treeFolder.Name = "Trees"

local function jungleTree(i, x, z)
	local rng = Random.new(2000 + i)
	local m = Instance.new("Model")
	m.Name = "JungleTree_" .. i
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	-- tapered trunk: three segments, each leaning a little
	local SEGS = {{5.6, rng:NextNumber(11, 13), C.trunk}, {4.6, rng:NextNumber(10, 12), C.trunkDark}, {3.6, rng:NextNumber(9, 11), C.trunk}}
	local cf = base
	local joints = {}
	for k, sgm in ipairs(SEGS) do
		part(m, "Trunk" .. k, Vector3.new(sgm[1], sgm[2] + 0.6, sgm[1]), cf * CFrame.new(0, sgm[2] / 2, 0), sgm[3], {collide = true, studs = true})
		cf = cf * CFrame.new(0, sgm[2], 0) * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-5, 5)))
		joints[k] = cf
	end
	local top = cf
	-- buttress roots
	for r = 1, 5 do
		local yaw = r * 2 * math.pi / 5 + rng:NextNumber(-0.25, 0.25)
		part(m, "Root", Vector3.new(1.8, 4.5, 5), base * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 1.4, 3.4) * CFrame.Angles(math.rad(38), 0, 0),
			C.root, {collide = true, studs = true})
	end
	-- side branches below the crown, each with its own leaf cluster
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
	-- crown: wide layered canopy with side lumps
	local cy = top.Position
	local spin = CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	part(m, "Canopy", Vector3.new(22, 7, 22), CFrame.new(cy + Vector3.new(0, 2.5, 0)) * spin, C.leaf, {studs = true})
	part(m, "Canopy2", Vector3.new(15, 6, 15), CFrame.new(cy + Vector3.new(rng:NextNumber(-2, 2), 8, rng:NextNumber(-2, 2))) * spin, C.leafLight, {studs = true})
	part(m, "Canopy3", Vector3.new(8, 4, 8), CFrame.new(cy + Vector3.new(rng:NextNumber(-2, 2), 12.5, rng:NextNumber(-2, 2))) * spin, C.leafDark, {studs = true})
	for k = 1, 2 do
		local a = rng:NextNumber(0, 2 * math.pi)
		part(m, "CanopySide", Vector3.new(11, 5, 11), CFrame.new(cy + Vector3.new(math.cos(a) * 10, 1, math.sin(a) * 10)) * spin, C.leafDark, {studs = true})
	end
	-- hanging vines from the canopy edge
	for v = 1, 4 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local len = rng:NextNumber(6, 10)
		part(m, "Vine", Vector3.new(0.5, len, 0.5), CFrame.new(cy + Vector3.new(math.cos(a) * 9.5, -1 - len / 2, math.sin(a) * 9.5)), C.leafDark)
	end
	m.Parent = treeFolder
end

local function palmTree(i, x, z, groundY)
	local rng = Random.new(3000 + i)
	local m = Instance.new("Model")
	m.Name = "Palm_" .. i
	local yaw = math.atan2(-x, -z) + rng:NextNumber(-0.6, 0.6) -- leans away from the island centre
	local cf = CFrame.new(x, groundY, z) * CFrame.Angles(0, yaw, 0)
	local segH = 3
	for s = 1, 8 do
		cf = cf * CFrame.Angles(math.rad(-2.5 - s * 0.5), 0, 0) -- gentle curve, steeper near the top
		local w = 2.5 - s * 0.1
		part(m, "Trunk", Vector3.new(w, segH + 0.3, w), cf * CFrame.new(0, segH / 2, 0), s % 2 == 0 and C.palmRing or C.palmTrunk,
			{collide = true, studs = true})
		cf = cf * CFrame.new(0, segH, 0)
	end
	local crown = CFrame.new(cf.Position)
	part(m, "Crown", Vector3.new(2.8, 2, 2.8), crown, C.palmRing, {studs = true})
	-- 9 drooping fronds of three pieces each
	for f = 1, 9 do
		local fy = (f / 9) * 2 * math.pi + rng:NextNumber(-0.12, 0.12)
		local color = f % 2 == 0 and C.frondDark or C.frond
		local seg = crown * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, fy, 0) * CFrame.Angles(math.rad(rng:NextNumber(8, 16)), 0, 0)
		for k, piece in ipairs({{2.4, 5}, {2, 5}, {1.3, 4}}) do
			part(m, "Frond", Vector3.new(piece[1], 0.45, piece[2]), seg * CFrame.new(0, 0, -piece[2] / 2), color, {studs = true})
			seg = seg * CFrame.new(0, 0, -piece[2]) * CFrame.Angles(math.rad(-22 - k * 6), 0, 0)
		end
	end
	-- short upright tuft in the middle
	for t = 1, 3 do
		local seg = crown * CFrame.Angles(0, t * 2.1, 0) * CFrame.Angles(math.rad(55), 0, 0)
		part(m, "Tuft", Vector3.new(1.4, 0.4, 4), seg * CFrame.new(0, 0, -2), C.frond, {studs = true})
	end
	for k = 1, 4 do
		local a = k * 1.6
		part(m, "Coconut", Vector3.new(1.3, 1.3, 1.3), crown * CFrame.new(math.cos(a) * 1.5, -1.5, math.sin(a) * 1.5), C.coconut, {studs = true})
	end
	m.Parent = treeFolder
end

local JUNGLE = {{-140, -120}, {-60, -150}, {30, -140}, {140, -110}, {-150, 20}, {150, 10}, {-100, 110}, {110, 120}, {-20, 40}, {60, -60}}
for i, t in ipairs(JUNGLE) do jungleTree(i, t[1], t[2]) end
local PALMS = {{172, 135}, {-172, 135}, {172, -135}, {-172, -135}, {197, 40}, {-197, -40}, {40, 197}, {-60, -197}}
for i, p in ipairs(PALMS) do palmTree(i, p[1], p[2], -0.4) end
treeFolder.Parent = island

island:SetAttribute("IslandVersion", VERSION)
local treeParts = 0
for _, d in ipairs(treeFolder:GetDescendants()) do if d:IsA("BasePart") then treeParts += 1 end end
return ("DinoIsland %s: %d tall-grass patches (%d blades), %d jungle trees + %d palms (%d parts); 1.0 bushes/trees in backup")
	:format(VERSION, #PATCHES, bladeCount, #JUNGLE, #PALMS, treeParts)
