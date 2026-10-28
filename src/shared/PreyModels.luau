-- PreyModels v1.0 (Dino Arcade) — builds the small prey: Compy, Chicken, Crab (DINO-11, plan docs/plans/PREY_v1.0.md).
-- Looks: the Studio mockup approved on 2026-10-27 (docs/mockups/prey_looks.jpg).
-- build(kind) returns an UNPARENTED Model (PreyServer parents it into Workspace.DinoIsland.Prey) with the flags the
--   existing systems already read, set before parenting so their DescendantAdded hooks see them:
--   Species = kind (DinoHitboxes builds hitboxes, PounceServer accepts it), Bitable = true + DummyMaxHealth
--   (BiteTargetHealth health / KO, BiteServer), IsBot = true (SurvivalServer carcass on removal, KillRegenServer,
--   GrowthServer kill XP), IsPrey = true, BotSpecies, PreyKind, DisplayName, MoveWalkSpeed, MoveRunSpeed.
--   Humanoid: BreakJointsOnDeath false, JumpPower 0, DisplayDistanceType None. HumanoidRootPart unanchored.
-- Compy: DinoModelBuilder.build(RaptorModelData) recoloured (green 5E943E -> rgb(196,150,72), stripes 283A1E ->
--   rgb(110,62,30), belly C9C98F -> rgb(236,222,180)), Model:ScaleTo(0.3) (about 3.9 studs long).
-- Chicken / Crab ("snacks"): one "Torso" segment Model (Root + blocks welded to it, so DinoHitboxes builds one Torso
--   hitbox), Root joined to the HumanoidRootPart by Motor6D "RootJoint" (PreyHop 1.0 animates its C0). Body front =
--   HumanoidRootPart LookVector (-Z), like the dinos. The crab's claws and eyes face +X (across its path), so it
--   walks sideways. Legs and feet (part names starting "Leg" / "Foot") go in a second segment "LegL" whose Root is
--   joined to the Torso Root (Motor6D "LegJoint"): DinoHitboxes makes that box bite-only (no collision), so the
--   blocking Torso box stays off the ground. Measured in Play: with the legs in the Torso segment its box sat on the
--   ground and the chickens dragged at 1-2 studs/s instead of 10. Bites on the legs count as "torso" (BiteServer).
local ServerStorage = game:GetService("ServerStorage")

local PreyModels = {}
PreyModels.Version = "1.0"
PreyModels.KINDS = {"Compy", "Chicken", "Crab"}
-- health = meat (DummyMaxHealth), walk / run studs per s, group size, alarm radius, flee / tired seconds
PreyModels.STATS = {
	Compy = {health = 15, walk = 14, run = 30, group = {3, 5}, alarm = 30, fleeTime = 4, tiredTime = 3},
	Chicken = {health = 8, walk = 6, run = 10, group = {2, 4}, alarm = 15, fleeTime = 3, tiredTime = 0},
	Crab = {health = 8, walk = 6, run = 10, group = {2, 4}, alarm = 15, fleeTime = 3, tiredTime = 0},
}

local COMPY_COLOURS = {
	["5E943E"] = Color3.fromRGB(196, 150, 72),
	["283A1E"] = Color3.fromRGB(110, 62, 30),
	["C9C98F"] = Color3.fromRGB(236, 222, 180),
}
local COMPY_SCALE = 0.3

local WHITE = Color3.fromRGB(242, 242, 236)
local RED = Color3.fromRGB(214, 40, 40)
local ORANGE = Color3.fromRGB(245, 168, 40)
local SHELL = Color3.fromRGB(222, 102, 70)
local CLAW = Color3.fromRGB(236, 128, 92)
local BLACK = Color3.fromRGB(25, 25, 25)

-- snack layouts: {name, size {x,y,z}, position {x,y,z} relative to the HumanoidRootPart, colour, rotation z (deg)}
-- y is measured from the HumanoidRootPart centre; the ground is at -(hrpHalfY + hipHeight).
local SNACKS = {
	Chicken = {
		hrp = {1.1, 1, 1.6}, hip = 0.9, -- ground at y = -1.4
		parts = {
			{"Body", {1.1, 1.3, 1.6}, {0, 0.15, 0.1}, WHITE},
			{"Head", {0.8, 0.8, 0.8}, {0, 0.95, -0.7}, WHITE},
			{"Comb", {0.2, 0.35, 0.5}, {0, 1.5, -0.7}, RED},
			{"Beak", {0.4, 0.25, 0.35}, {0, 0.9, -1.27}, ORANGE},
			{"Wattle", {0.2, 0.35, 0.15}, {0, 0.6, -1.17}, RED},
			{"Tail", {0.9, 0.7, 0.35}, {0, 0.6, 0.95}, WHITE},
			{"LegL", {0.15, 0.9, 0.15}, {-0.3, -0.95, 0.1}, ORANGE},
			{"LegR", {0.15, 0.9, 0.15}, {0.3, -0.95, 0.1}, ORANGE},
			{"FootL", {0.35, 0.1, 0.5}, {-0.3, -1.35, -0.05}, ORANGE},
			{"FootR", {0.35, 0.1, 0.5}, {0.3, -1.35, -0.05}, ORANGE},
		},
	},
	Crab = {
		hrp = {1.4, 0.6, 2}, hip = 0.45, -- ground at y = -0.75; claws / eyes at +X (sideways walker)
		parts = {
			{"Shell", {1.6, 0.6, 2.2}, {0, 0, 0}, SHELL},
			{"ShellTop", {1.1, 0.25, 1.6}, {0, 0.42, 0}, SHELL},
			{"ClawL", {0.7, 0.45, 0.55}, {1.15, 0, -0.65}, CLAW},
			{"ClawR", {0.7, 0.45, 0.55}, {1.15, 0, 0.65}, CLAW},
			{"StalkL", {0.12, 0.5, 0.12}, {0.6, 0.55, -0.3}, BLACK},
			{"StalkR", {0.12, 0.5, 0.12}, {0.6, 0.55, 0.3}, BLACK},
			{"EyeL", {0.22, 0.22, 0.22}, {0.6, 0.85, -0.3}, BLACK},
			{"EyeR", {0.22, 0.22, 0.22}, {0.6, 0.85, 0.3}, BLACK},
			{"Leg1L", {0.15, 0.65, 0.15}, {0.45, -0.42, -1.2}, SHELL, -20},
			{"Leg2L", {0.15, 0.65, 0.15}, {0, -0.42, -1.2}, SHELL, -20},
			{"Leg3L", {0.15, 0.65, 0.15}, {-0.45, -0.42, -1.2}, SHELL, -20},
			{"Leg1R", {0.15, 0.65, 0.15}, {0.45, -0.42, 1.2}, SHELL, 20},
			{"Leg2R", {0.15, 0.65, 0.15}, {0, -0.42, 1.2}, SHELL, 20},
			{"Leg3R", {0.15, 0.65, 0.15}, {-0.45, -0.42, 1.2}, SHELL, 20},
		},
	},
}

local function flags(model, kind)
	local st = PreyModels.STATS[kind]
	model:SetAttribute("Species", kind)
	model:SetAttribute("BotSpecies", kind)
	model:SetAttribute("PreyKind", kind)
	model:SetAttribute("IsPrey", true)
	model:SetAttribute("IsBot", true)
	model:SetAttribute("Bitable", true)
	model:SetAttribute("DummyMaxHealth", st.health)
	model:SetAttribute("DisplayName", kind)
	model:SetAttribute("MoveWalkSpeed", st.walk)
	model:SetAttribute("MoveRunSpeed", st.run)
	model:SetAttribute("PreyModelsVersion", PreyModels.Version)
end

local function setupHumanoid(hum, walk)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.AutoRotate = true
	hum.WalkSpeed = walk
end

local function buildCompy()
	local folder = ServerStorage:WaitForChild("DinoArcade")
	local Builder = require(folder:WaitForChild("DinoModelBuilder"))
	local data = require(folder:WaitForChild("Models"):WaitForChild("RaptorModelData"))
	local m = Builder.build(data, {name = "Compy"})
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local c = COMPY_COLOURS[d.Color:ToHex():upper()]
			if c then d.Color = c end
		end
	end
	m:ScaleTo(COMPY_SCALE)
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = false end
	return m
end

local function buildSnack(kind)
	local L = SNACKS[kind]
	local m = Instance.new("Model")
	m.Name = kind
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(table.unpack(L.hrp))
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CanTouch = false
	hrp.CanQuery = false
	hrp.Anchored = false
	hrp.CFrame = CFrame.new()
	hrp.Parent = m
	m.PrimaryPart = hrp
	local seg = Instance.new("Model")
	seg.Name = "Torso"
	seg.Parent = m
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.new()
	root.Parent = seg
	local legSeg = Instance.new("Model")
	legSeg.Name = "LegL"
	legSeg.Parent = m
	local legRoot = root:Clone()
	legRoot.Parent = legSeg
	local legJoint = Instance.new("Motor6D")
	legJoint.Name = "LegJoint"
	legJoint.Part0 = root
	legJoint.Part1 = legRoot
	legJoint.Parent = legRoot
	for _, p in ipairs(L.parts) do
		local isLeg = p[1]:sub(1, 3) == "Leg" or p[1]:sub(1, 4) == "Foot"
		local part = Instance.new("Part")
		part.Name = kind .. "_" .. p[1]
		part.Size = Vector3.new(table.unpack(p[2]))
		part.CFrame = CFrame.new(table.unpack(p[3])) * CFrame.Angles(0, 0, math.rad(p[5] or 0))
		part.Color = p[4]
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = isLeg and legSeg or seg
		local w = Instance.new("WeldConstraint")
		w.Part0 = isLeg and legRoot or root
		w.Part1 = part
		w.Parent = part
	end
	local joint = Instance.new("Motor6D")
	joint.Name = "RootJoint"
	joint.Part0 = hrp
	joint.Part1 = root
	joint.C0 = CFrame.new()
	joint.C1 = CFrame.new()
	joint.Parent = root
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = L.hip
	hum.Parent = m
	return m
end

-- returns an unparented prey Model of the given kind ("Compy" / "Chicken" / "Crab"), or nil for an unknown kind
function PreyModels.build(kind)
	local st = PreyModels.STATS[kind]
	if not st then return nil end
	local m = kind == "Compy" and buildCompy() or buildSnack(kind)
	m.Name = kind
	flags(m, kind)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then setupHumanoid(hum, st.walk) end
	return m
end

return PreyModels
