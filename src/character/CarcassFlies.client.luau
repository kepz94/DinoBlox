-- CarcassFlies v1.0 (Dino Arcade) — flies buzzing over carcasses (LocalScript, this client only).
-- User: dead dinos "not even obvious that theyre dead"; answer: flies / stink lines (with X eyes and a stronger pose).
-- Every carcass in Workspace.DinoCarcasses (SurvivalServer 1.x) within FLY_RANGE studs of the camera gets FLY_COUNT small
-- dark specks that circle above its top, each on its own radius, speed, height and bob, with a fast jitter so they
-- read as buzzing. The specks are local parts (anchored, no collision / query / touch / shadow) in
-- Workspace.CarcassFliesLocal; a swarm is removed when its carcass goes (eaten / expired) or leaves the range.
-- The carcass's top and centre are measured from its parts once (SETTLE s after it appears, when the joints have
-- placed the dead pose) and kept (carcasses do not move).
-- Off with the player attribute CarcassFliesEnabled = false.
-- Diagnostics (character attributes, this client): CarcassFliesVersion, CarcassFliesSwarms (swarms shown).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FLY_COUNT = 6
local FLY_SIZE = 0.22
local FLY_RANGE = 160
local SETTLE = 0.3
local FLY_COLOR = Color3.fromRGB(20, 20, 20)

local char = script.Parent
local player = Players.LocalPlayer
char:SetAttribute("CarcassFliesVersion", VERSION)

local old = workspace:FindFirstChild("CarcassFliesLocal")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "CarcassFliesLocal"
folder.Parent = workspace

local swarms = {} -- [carcass] = {flies = {{part, r, w, phase, h, bob}}, center, top, born}

local function box(c)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			local r = d.CFrame
			local ext = Vector3.new(
				math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
				math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
				math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
			lo = lo:Min(d.Position - ext)
			hi = hi:Max(d.Position + ext)
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end

local function remove(c)
	local s = swarms[c]
	if not s then return end
	for _, f in ipairs(s.flies) do f.part:Destroy() end
	swarms[c] = nil
end

local function make(c, lo, hi)
	local rng = Random.new(#c.Name * 7919 + math.floor(lo.X * 13))
	local span = math.max(hi.X - lo.X, hi.Z - lo.Z)
	local rMax = math.clamp(span * 0.35, 1.5, 5)
	local s = {flies = {}, center = Vector3.new((lo.X + hi.X) / 2, hi.Y, (lo.Z + hi.Z) / 2)}
	for i = 1, FLY_COUNT do
		local p = Instance.new("Part")
		p.Name = "Fly"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(FLY_SIZE, FLY_SIZE, FLY_SIZE)
		p.Color = FLY_COLOR
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.Parent = folder
		table.insert(s.flies, {part = p, r = rng:NextNumber(0.4, 1) * rMax, w = rng:NextNumber(2.2, 4.5) * (rng:NextInteger(0, 1) * 2 - 1),
			phase = rng:NextNumber(0, 2 * math.pi), h = rng:NextNumber(0.8, 2.6), bob = rng:NextNumber(5, 9)})
	end
	swarms[c] = s
end

local seen = {} -- [carcass] = os.clock() first seen
local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		folder:Destroy()
		return
	end
	local enabled = player:GetAttribute("CarcassFliesEnabled") ~= false
	local cf = workspace:FindFirstChild("DinoCarcasses")
	local cam = workspace.CurrentCamera
	local now = os.clock()
	local live = {}
	if enabled and cf and cam then
		for _, c in ipairs(cf:GetChildren()) do
			live[c] = true
			seen[c] = seen[c] or now
			if not swarms[c] and now - seen[c] >= SETTLE then
				local lo, hi = box(c)
				if lo and (Vector3.new((lo.X + hi.X) / 2, hi.Y, (lo.Z + hi.Z) / 2) - cam.CFrame.Position).Magnitude <= FLY_RANGE then
					make(c, lo, hi)
				end
			end
		end
	end
	for c, s in pairs(swarms) do
		if not live[c] or not c.Parent or (s.center - cam.CFrame.Position).Magnitude > FLY_RANGE + 20 then
			remove(c)
		else
			for i, f in ipairs(s.flies) do
				local a = f.phase + now * f.w
				local jitter = Vector3.new(math.sin(now * 37 + i) * 0.12, math.sin(now * 29 + i * 2) * 0.12, math.cos(now * 31 + i) * 0.12)
				f.part.CFrame = CFrame.new(s.center + Vector3.new(math.cos(a) * f.r, f.h + math.sin(now * f.bob + i) * 0.35, math.sin(a) * f.r) + jitter)
			end
		end
	end
	for c in pairs(seen) do
		if not live[c] then seen[c] = nil end
	end
	local n = 0
	for _ in pairs(swarms) do n += 1 end
	if char:GetAttribute("CarcassFliesSwarms") ~= n then char:SetAttribute("CarcassFliesSwarms", n) end
end)
