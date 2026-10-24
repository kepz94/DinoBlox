-- DinoModelBuilder v1.0 (Dino Arcade) — rebuilds a rigged dino Model from a model-data table
-- (e.g. Models/TRexModelData). The data is a snapshot taken from Studio, so the rebuilt model is the
-- same blocks, joints, Humanoid settings and attributes as the original.
--
-- Usage (Studio command bar, or any server script):
--   local Builder = require(game.ServerStorage.DinoArcade.DinoModelBuilder)
--   local data = require(game.ServerStorage.DinoArcade.Models.TRexModelData)
--   local m = Builder.build(data, {name = "StarterCharacter"})         -- player character
--   m.Parent = game.StarterPlayer
--   local d = Builder.build(data, {name = "TRex_Display", pivot = CFrame.new(0, 7.65, 40), anchored = true})
--   d.Parent = workspace                                               -- pinned display model
--
-- Structure produced (matches the live rig):
--   Model
--     HumanoidRootPart (invisible hitbox, PrimaryPart)
--     Humanoid
--     <Segment> Model x17 (Torso, Neck, Head, Jaw, ArmL/R, Tail1-5, LegL/R, ShinL/R, FootL/R)
--       Root (invisible joint part) + visual Parts, each welded to Root with a WeldConstraint
--     Motor6D per segment, parented to that segment's Root (Part0 = parent segment Root or HRP)
-- Scripts are not part of the data: character scripts live in StarterCharacterScripts.

local Builder = {}

Builder.Version = "1.0"

local FACES = {"Top", "Bottom", "Front", "Back", "Left", "Right"}

local function toCFrame(t)
	return CFrame.new(table.unpack(t))
end

local function toVector3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function applySurfaces(part, surface)
	if type(surface) == "string" then
		for _, f in ipairs(FACES) do
			part[f .. "Surface"] = Enum.SurfaceType[surface]
		end
	else
		for i, f in ipairs(FACES) do
			part[f .. "Surface"] = Enum.SurfaceType[surface[i]]
		end
	end
end

-- data: model-data table; opts: {name = string, pivot = CFrame (HumanoidRootPart world CFrame),
-- anchored = bool (pin the HumanoidRootPart, for display models)}
function Builder.build(data, opts)
	opts = opts or {}
	local pivot = opts.pivot or CFrame.new()

	local model = Instance.new("Model")
	model.Name = opts.name or ("Dino_" .. tostring(data.species))

	-- HumanoidRootPart: invisible hitbox and root of the assembly
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = toVector3(data.hrp.size)
	hrp.CFrame = pivot
	hrp.Color = Color3.fromHex(data.hrp.color)
	applySurfaces(hrp, data.hrp.surface)
	hrp.Transparency = 1
	hrp.CanCollide, hrp.CanQuery, hrp.CanTouch = true, true, true
	hrp.Anchored = opts.anchored == true
	hrp.Parent = model

	local roots = {HRP = hrp}

	-- segments: one Root part per segment + visual parts welded to it
	for _, seg in ipairs(data.segments) do
		local segModel = Instance.new("Model")
		segModel.Name = seg.name
		segModel.Parent = model

		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.CFrame = pivot * toCFrame(seg.root)
		root.Transparency = 1
		root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, false, true
		root.Parent = segModel
		roots[seg.name] = root

		for _, p in ipairs(seg.parts) do
			local part = Instance.new("Part")
			part.Name = p.name
			part.Size = toVector3(p.size)
			part.CFrame = pivot * toCFrame(p.cf)
			part.Color = Color3.fromHex(p.color)
			part.Material = p.material and Enum.Material[p.material] or Enum.Material.Plastic
			part.Transparency = p.transparency or 0
			applySurfaces(part, p.surface)
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
			part.Parent = segModel
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = root, part
			weld.Parent = part
		end
	end

	-- joints
	for _, j in ipairs(data.joints) do
		local p0, p1 = roots[j.part0], roots[j.part1]
		assert(p0 and p1, ("joint %s: missing segment %s or %s"):format(j.name, j.part0, j.part1))
		local motor = Instance.new("Motor6D")
		motor.Name = j.name
		motor.Part0, motor.Part1 = p0, p1
		motor.C0 = toCFrame(j.c0)
		motor.C1 = toCFrame(j.c1)
		motor.Parent = p1
	end

	-- humanoid
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType[data.humanoid.RigType]
	hum.HipHeight = data.humanoid.HipHeight
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType[data.humanoid.DisplayDistanceType]
	hum.Parent = model

	model.PrimaryPart = hrp
	if data.modelStreamingMode then
		model.ModelStreamingMode = Enum.ModelStreamingMode[data.modelStreamingMode]
	end
	for k, v in pairs(data.attributes or {}) do
		model:SetAttribute(k, v)
	end
	return model
end

return Builder
