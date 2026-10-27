-- DeadPose v1.1 (Dino Arcade) — a dino that is clearly dead (user: "dead dinos should also be clearly dead so maybe make
-- a dead animation for the ones laying down"; answers: dead pose only; carcasses + KO'd bots + dead players).
-- Static per-joint offsets (C0 = restC0 * offset) for every rig joint: body root left as it is (the body itself lies
-- on its side: BotServer's KO roll / the Humanoid's death fall), legs stiff and sticking out (hips swung forward, knees
-- straightened, toes pointed), arms stiff, neck and head drooped, jaw hanging open, tail limp. No breathing or motion.
-- Used by IdleAnimation 1.21 (every client: Humanoid dead or DummyState "ko", blended in at DeadBlendRate) and by
-- SurvivalServer 1.1 (carcasses: the same offsets written once to the carcass's Motor6D C0, server side, replicated).
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front / swings a leg
-- forward), about Y = yaw, about X = roll; Jaw: negative Z opens; Tail: positive pitch = lower.
-- v1.1 (user: "they just lay on their side eyes open not even obvious that theyre dead"; answers: X eyes, stronger
--   pose, flies): stronger defaults (legs swung 75 and straightened at the knees, feet pointed 35, arms 70, jaw 50
--   open, neck / head drooped further, tail nearly flat; v1.0: 38 / -18 / 25 / 45 / 32 / 6) and X eyes:
--   DeadPose.markEyes(model) on the model's Head segment: every visible part named *_pupil* / *_shine* is hidden
--   (Transparency 1), every part named *_eye* takes the head's skin colour (the biggest other visible head part:
--   eye shut) and gets a dark X of two thin bars (DeadEyeX, EYE_X_COLOR) laid on its outer face (the thinnest axis,
--   on the side away from the head's centre), welded to it. Returns a handle; DeadPose.unmarkEyes(handle) puts
--   everything back and removes the bars. IdleAnimation 1.22 calls it on every client while the dead pose is on;
--   SurvivalServer 1.3 calls it once on each carcass (server, replicated).
-- Settings (model attributes, defaults below; read by DeadPose.settings).

local DeadPose = {}

DeadPose.Version = "1.1"
DeadPose.Defaults = {
	DeadPoseEnabled = true,
	DeadBlendRate   = 4,   -- how fast the pose blends in (per second)
	DeadLegSwing    = 75,  -- degrees the legs swing forward (stiff, sticking out); v1.0: 38
	DeadKnee        = 20,  -- degrees added at the knees (positive straightens the rest bend); v1.0: -18
	DeadAnkle       = 35,  -- degrees the feet point; v1.0: 25
	DeadArm         = 70,  -- degrees the arms stick forward; v1.0: 45
	DeadNeck        = -25, -- degrees the neck droops; v1.0: -18
	DeadHead        = -15, -- degrees the head droops; v1.0: -12
	DeadHeadRoll    = 10,  -- degrees the head lolls to the side
	DeadJaw         = -50, -- degrees the jaw hangs open; v1.0: -32
	DeadTail        = 2,   -- degrees each tail segment goes limp (lower); v1.0: 6
	DeadEyesEnabled = true, -- v1.1: X eyes
}

local rad = math.rad

function DeadPose.get(s)
	s = s or DeadPose.Defaults
	local out = {}
	out.RootJoint = CFrame.identity
	out.LegL = CFrame.Angles(0, 0, rad(s.DeadLegSwing))
	out.LegR = CFrame.Angles(0, 0, rad(s.DeadLegSwing * 0.85))
	out.KneeL = CFrame.Angles(0, 0, rad(s.DeadKnee))
	out.KneeR = CFrame.Angles(0, 0, rad(s.DeadKnee))
	out.AnkleL = CFrame.Angles(0, 0, rad(s.DeadAnkle))
	out.AnkleR = CFrame.Angles(0, 0, rad(s.DeadAnkle))
	out.ArmL = CFrame.Angles(0, 0, rad(s.DeadArm))
	out.ArmR = CFrame.Angles(0, 0, rad(s.DeadArm * 0.8))
	out.Neck = CFrame.Angles(0, 0, rad(s.DeadNeck))
	out.Head = CFrame.Angles(rad(s.DeadHeadRoll), 0, rad(s.DeadHead))
	out.Jaw = CFrame.Angles(0, 0, rad(s.DeadJaw))
	for i = 1, 5 do
		out["Tail" .. i] = CFrame.Angles(0, 0, rad(s.DeadTail))
	end
	return out
end

-- v1.1: X eyes ------------------------------------------------------------------------------------------------------
DeadPose.EYE_X_COLOR = Color3.fromRGB(25, 25, 25)

local function isEye(n) return n:find("_eye") ~= nil end
local function isHidden(n) return n:find("_pupil") ~= nil or n:find("_shine") ~= nil end

function DeadPose.markEyes(model)
	local head = model and model:FindFirstChild("Head")
	if not head then return nil end
	local parts, skin, skinVol = {}, nil, 0
	local sum, count = Vector3.zero, 0
	for _, p in ipairs(head:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "DeadEyeX" then
			table.insert(parts, p)
			if p.Transparency < 1 then
				sum += p.Position
				count += 1
				if not isEye(p.Name) and not isHidden(p.Name) then
					local v = p.Size.X * p.Size.Y * p.Size.Z
					if v > skinVol then skin, skinVol = p.Color, v end
				end
			end
		end
	end
	if count == 0 then return nil end
	local center = sum / count
	local handle = {changed = {}, made = {}}
	for _, p in ipairs(parts) do
		if p.Transparency < 1 and isHidden(p.Name) then
			table.insert(handle.changed, {p, "Transparency", p.Transparency})
			p.Transparency = 1
		elseif p.Transparency < 1 and isEye(p.Name) then
			table.insert(handle.changed, {p, "Color", p.Color})
			if skin then p.Color = skin end
			local sz = p.Size
			local lc = p.CFrame:PointToObjectSpace(center)
			local axis = (sz.X <= sz.Y and sz.X <= sz.Z) and "X" or ((sz.Y <= sz.Z) and "Y" or "Z")
			local face = axis == "X" and math.min(sz.Y, sz.Z) or (axis == "Y" and math.min(sz.X, sz.Z) or math.min(sz.X, sz.Y))
			local L, T, D = face * 1.25, face * 0.22, 0.08
			local out = -(lc[axis] >= 0 and 1 or -1) -- the face away from the head's centre
			for _, a in ipairs({45, -45}) do
				local r = math.rad(a)
				local rot, size, off
				if axis == "Z" then
					rot, size, off = CFrame.Angles(0, 0, r), Vector3.new(L, T, D), Vector3.new(0, 0, out * (sz.Z + D) / 2)
				elseif axis == "X" then
					rot, size, off = CFrame.Angles(r, 0, 0), Vector3.new(D, T, L), Vector3.new(out * (sz.X + D) / 2, 0, 0)
				else
					rot, size, off = CFrame.Angles(0, r, 0), Vector3.new(L, D, T), Vector3.new(0, out * (sz.Y + D) / 2, 0)
				end
				local bar = Instance.new("Part")
				bar.Name = "DeadEyeX"
				bar.Size = size
				bar.CFrame = p.CFrame * CFrame.new(off) * rot
				bar.Color = DeadPose.EYE_X_COLOR
				bar.Material = Enum.Material.SmoothPlastic
				bar.TopSurface, bar.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				bar.CanCollide, bar.CanQuery, bar.CanTouch = false, false, false
				bar.CastShadow = false
				bar.Massless = true
				bar.Anchored = p.Anchored
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = p, bar
				weld.Parent = bar
				bar.Parent = p
				table.insert(handle.made, bar)
			end
		end
	end
	return handle
end

function DeadPose.unmarkEyes(handle)
	if not handle then return end
	for _, b in ipairs(handle.made) do b:Destroy() end
	for _, c in ipairs(handle.changed) do
		if c[1].Parent then c[1][c[2]] = c[3] end
	end
end

function DeadPose.settings(model)
	local s = {}
	for k, v in pairs(DeadPose.Defaults) do
		local a = model and model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return DeadPose
