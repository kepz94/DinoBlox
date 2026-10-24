-- Dino Arcade: T-Rex generator v3 (rigged)
-- Version 1.0 = preset B geometry (unchanged from StylePreview_v2) + rig
-- Version 1.1 = Version 1.0 + cream throat-to-belly stripe + square eye with highlight
-- Builds into Workspace.DinoArcade_TRex (additive; StylePreview_v2 untouched)

local old = workspace:FindFirstChild("DinoArcade_TRex")
if old then old:Destroy() end

local C = {
	body  = Color3.fromRGB(102, 106, 74),
	dark  = Color3.fromRGB(80, 82, 58),
	belly = Color3.fromRGB(178, 162, 120),
	mouth = Color3.fromRGB(110, 52, 46),
	tooth = Color3.fromRGB(232, 226, 210),
	eye   = Color3.fromRGB(17, 17, 17),
	shine = Color3.fromRGB(245, 245, 240),
}
local FACES = {"Top","Bottom","Front","Back","Left","Right"}
local V = Vector3.new
local rad = math.rad

local function makeTRex(name, origin, P, opts)
	local model = Instance.new("Model")
	model.Name = name
	local segs, roots, count = {}, {}, 0
	local joints = {} -- segName -> {parent = segName|"HRP", cf = CFrame}

	local function seg(segName)
		local s = segs[segName]
		if not s then
			s = Instance.new("Model"); s.Name = segName; s.Parent = model; segs[segName] = s
		end
		return s
	end
	local function part(segName, size, cf, colorKey, noStuds)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
		p.Material = Enum.Material.Plastic
		p.Size = size
		p.CFrame = cf
		p.Color = C[colorKey]
		if colorKey ~= "eye" and colorKey ~= "shine" and not noStuds then
			for _, f in ipairs(FACES) do p[f .. "Surface"] = Enum.SurfaceType.Studs end
		end
		p.Name = segName .. "_" .. colorKey
		p.Parent = seg(segName)
		count += 1
		return p
	end
	local function joint(segName, parentSeg, cf)
		joints[segName] = {parent = parentSeg, cf = cf}
	end

	local bs, hs, lt, ll, ts, tl, es, as = P.bs, P.hs, P.lt, P.ll, P.ts, P.tl, P.es, P.as
	local hipY = 9 * ll
	local O = CFrame.new(origin + V(0, hipY, 0))
	local function B(x, y, z) return V(x * bs.X, y * bs.Y, z * bs.Z) end

	-- TORSO
	joint("Torso", "HRP", O)
	part("Torso", B(4.5, 5.5, 6.5), O * CFrame.new(B(-2.5, 0.3, 0)), "body")
	part("Torso", B(8, 6, 6), O * CFrame.new(B(1, 0, 0)) * CFrame.Angles(0, 0, rad(-6)), "body")
	part("Torso", B(4.5, 5.5, 5.6), O * CFrame.new(B(4.5, 0.9, 0)) * CFrame.Angles(0, 0, rad(14)), "body")
	part("Torso", B(7, 1.6, 5), O * CFrame.new(B(1.5, -2.6, 0)) * CFrame.Angles(0, 0, rad(-6)), "belly")
	for i, x in ipairs({-4.2, -2.2, -0.2, 1.8, 3.8}) do
		part("Torso", B(1.6, 0.9, 1.8), O * CFrame.new(B(x, 3.15 + i * 0.12, 0)) * CFrame.Angles(0, 0, rad(-6)), "dark")
	end

	-- NECK
	local neckCF = O * CFrame.new(B(6.3, 2.2, 0))
	joint("Neck", "Torso", neckCF)
	part("Neck", B(3.6, 4.2, 3.8), neckCF * CFrame.new(B(0.8, 1.2, 0)) * CFrame.Angles(0, 0, rad(35)), "body")
	part("Neck", B(2.6, 2, 3), neckCF * CFrame.new(B(1.3, 0.2, 0)) * CFrame.Angles(0, 0, rad(35)), "belly")

	-- HEAD
	local headCF = neckCF * CFrame.new(B(2.4, 3.2, 0)) * CFrame.Angles(0, 0, rad(P.headTilt))
	joint("Head", "Neck", headCF)
	local function H(x, y, z) return V(x * hs, y * hs, z * hs) end
	part("Head", H(4, 3.8, 4.6), headCF * CFrame.new(H(1.5, 0.6, 0)), "body")
	part("Head", H(3.2, 3.2, 4), headCF * CFrame.new(H(4.5, 0.4, 0)), "body")
	part("Head", H(3.4, 2.4, 3.2), headCF * CFrame.new(H(7.4, 0.1, 0)), "body")
	part("Head", H(2.4, 0.7, 4.8), headCF * CFrame.new(H(2.8, 2.6, 0)), "dark")
	part("Head", H(1.2, 0.5, 2.4), headCF * CFrame.new(H(8.2, 1.45, 0)), "dark")
	part("Head", H(6.5, 0.6, 3), headCF * CFrame.new(H(5, -1.4, 0)), "mouth")
	for _, s in ipairs({1, -1}) do
		if opts.eyeStyle == "square_highlight" then
			-- square eye flat on the side of the skull, with a highlight in the upper-front corner
			local d = 0.8 * es
			local eyeCF = headCF * CFrame.new(H(3, 1.3, 0) + V(0, 0, s * (H(0, 0, 2.3).Z + 0.1)))
			part("Head", V(d, d, 0.2), eyeCF, "eye")
			part("Head", V(d * 0.38, d * 0.38, 0.22), eyeCF * CFrame.new(d * 0.22, d * 0.22, s * 0.02), "shine")
		else
			-- Version 1.0 eye (as approved in preset B)
			part("Head", V(0.2, 0.8 * es, 0.8 * es), headCF * CFrame.new((H(3, 1.3, 2.31) + V(0, 0, 0.1)) * V(1, 1, s)), "eye")
		end
	end
	for _, x in ipairs({4.4, 5.7, 7.0, 8.2}) do
		for _, s in ipairs({1, -1}) do
			part("Head", H(0.5, 0.7, 0.5), headCF * CFrame.new(H(x, -1.45, 1.3 * s)), "tooth")
		end
	end

	-- JAW
	local jawCF = headCF * CFrame.new(H(0.8, -1.6, 0)) * CFrame.Angles(0, 0, rad(-P.jawOpen))
	joint("Jaw", "Head", jawCF)
	part("Jaw", H(7.6, 1.2, 3.4), jawCF * CFrame.new(H(3.8, -0.3, 0)), "dark")
	part("Jaw", H(2.6, 1.8, 4.2), jawCF * CFrame.new(H(0.9, 0.1, 0)), "body")
	part("Jaw", H(5.5, 0.5, 2.6), jawCF * CFrame.new(H(3.6, -1.0, 0)), "belly")
	for _, x in ipairs({3.2, 4.6, 6.0}) do
		for _, s in ipairs({1, -1}) do
			part("Jaw", H(0.5, 0.6, 0.5), jawCF * CFrame.new(H(x, 0.55, 1.2 * s)), "tooth")
		end
	end

	-- STRIPE (Version 1.1 only): continuous cream from throat to belly
	if opts.stripe then
		part("Head",  H(2.6, 1.4, 3.0), headCF * CFrame.new(H(0.9, -2.2, 0)), "belly")
		part("Neck",  B(1.0, 4.4, 3.0), neckCF * CFrame.new(B(2.0, 2.0, 0)) * CFrame.Angles(0, 0, rad(35)), "belly")
		part("Neck",  B(3.0, 2.8, 3.6), neckCF * CFrame.new(B(1.2, -0.3, 0)) * CFrame.Angles(0, 0, rad(35)), "belly")
		part("Torso", B(1.2, 5.0, 3.8), O * CFrame.new(B(6.25, 1.34, 0)) * CFrame.Angles(0, 0, rad(14)), "belly")
		part("Torso", B(2.2, 1.8, 4.2), O * CFrame.new(B(5.2, -2.1, 0)) * CFrame.Angles(0, 0, rad(30)), "belly")
		part("Torso", B(7.2, 1.0, 4.2), O * CFrame.new(B(1.5, -3.3, 0)) * CFrame.Angles(0, 0, rad(-6)), "belly")
	end

	-- ARMS
	local function A(x, y, z) return V(x * as, y * as, z * as) end
	for _, s in ipairs({1, -1}) do
		local sn = s == 1 and "ArmL" or "ArmR"
		local armCF = O * CFrame.new(B(5.4, -1.2, 2.5 * s))
		joint(sn, "Torso", armCF)
		part(sn, A(1.8, 0.8, 0.8), armCF * CFrame.new(A(0.5, -0.4, 0)) * CFrame.Angles(0, 0, rad(-50)), "body")
		part(sn, A(1.5, 0.6, 0.6), armCF * CFrame.new(A(1.4, -1.2, 0)) * CFrame.Angles(0, 0, rad(15)), "body")
		part(sn, A(0.5, 0.35, 0.35), armCF * CFrame.new(A(2.25, -1.15, 0)), "tooth")
	end

	-- TAIL
	local cursor = (O * CFrame.new(B(-4.6, 0.6, 0))).Position
	local lens = {4.5, 4.5, 4, 3.5, 3}
	local hts  = {4.6, 3.6, 2.7, 1.9, 1.2}
	local angs = {4, 6, 6, 4, 0}
	for k = 1, 5 do
		local L = lens[k] * tl
		local h = hts[k] * ts * bs.Y
		local w = (hts[k] + 0.2) * ts * bs.Z
		local a = rad(angs[k])
		local dir = V(-math.cos(a), math.sin(a), 0)
		local sn = "Tail" .. k
		joint(sn, k == 1 and "Torso" or ("Tail" .. (k - 1)), CFrame.new(cursor) * CFrame.Angles(0, 0, -a))
		local center = cursor + dir * (L / 2)
		local cf = CFrame.new(center) * CFrame.Angles(0, 0, -a)
		part(sn, V(L, h, w), cf, k == 5 and "dark" or "body")
		if k <= 3 then
			part(sn, V(1.4, 0.7, math.max(1, w * 0.3)), cf * CFrame.new(0, h / 2 + 0.3, 0), "dark")
		end
		cursor = cursor + dir * (L * 0.85)
	end

	-- LEGS
	local function Lg(x, y, z) return V(x * lt, y * ll, z * lt) end
	for _, s in ipairs({1, -1}) do
		local sn = s == 1 and "LegL" or "LegR"
		local hipCF = O * CFrame.new(B(-2.5, 0, 3.4 * s))
		joint(sn, "Torso", hipCF)
		part(sn, Lg(4.4, 6, 2.8), hipCF * CFrame.new(Lg(0.6, -2.4, 0)) * CFrame.Angles(0, 0, rad(18)), "body")
		part(sn, Lg(2.4, 4.2, 2.4), hipCF * CFrame.new(Lg(-0.6, -6.0, 0)) * CFrame.Angles(0, 0, rad(-22)), "body")
		part(sn, Lg(4.2, 1, 3), hipCF * CFrame.new(Lg(0.9, -8.5, 0)), "dark")
		for _, z in ipairs({-0.9, 0, 0.9}) do
			part(sn, V(0.9 * lt, 0.6 * ll, 0.6 * lt), hipCF * CFrame.new(Lg(3.35, -8.7, z)), "tooth")
		end
	end

	-- RIG ---------------------------------------------------------------
	-- HumanoidRootPart = invisible hitbox, root of the assembly
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = B(12, 8, 8)
	hrp.CFrame = O
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CanQuery = true
	hrp.CanTouch = true
	hrp.Anchored = true -- preview only: keeps the model standing in place; unanchor when spawned as a player/NPC
	hrp.Parent = model
	roots.HRP = hrp

	-- one invisible Root part per segment, at its joint pivot
	for segName, j in pairs(joints) do
		local r = Instance.new("Part")
		r.Name = "Root"
		r.Size = V(0.2, 0.2, 0.2)
		r.CFrame = j.cf
		r.Transparency = 1
		r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.Massless = false, false, false, false, true
		r.Parent = seg(segName)
		roots[segName] = r
	end
	-- weld every visual part to its segment Root
	for segName, s in pairs(segs) do
		local r = roots[segName]
		for _, p in ipairs(s:GetChildren()) do
			if p:IsA("BasePart") and p ~= r then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = r, p
				w.Parent = p
				p.Anchored = false
			end
		end
	end
	-- Motor6D joints between segment Roots (named after the child segment)
	for segName, j in pairs(joints) do
		local p0, p1 = roots[j.parent], roots[segName]
		local m = Instance.new("Motor6D")
		m.Name = segName == "Torso" and "RootJoint" or segName
		m.Part0, m.Part1 = p0, p1
		m.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
		m.C1 = CFrame.new()
		m.Parent = p1
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = (O.Position.Y - hrp.Size.Y / 2) - origin.Y
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = hrp
	model:SetAttribute("Species", "TRex")
	model:SetAttribute("StyleVersion", opts.version)
	return model, count
end

local PRESET_B = {bs = V(1, 1.18, 1.2), hs = 1.45, lt = 1.35, ll = 0.85, ts = 1.2, tl = 0.8, es = 1.7, as = 0.75, headTilt = -2, jawOpen = 10}

local root = Instance.new("Folder")
root.Name = "DinoArcade_TRex"
local m10, n10 = makeTRex("TRex_v1.0", V(-22, 0.5, 45), PRESET_B, {version = "1.0", stripe = false, eyeStyle = "v1"})
m10.Parent = root
local m11, n11 = makeTRex("TRex_v1.1_StripeEye", V(22, 0.5, 45), PRESET_B, {version = "1.1", stripe = true, eyeStyle = "square_highlight"})
m11.Parent = root
root.Parent = workspace
return ("Built v1.0=%d visual parts, v1.1=%d visual parts"):format(n10, n11)
