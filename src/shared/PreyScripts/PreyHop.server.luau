-- PreyHop v1.0 (Dino Arcade) — hop / peck animation for the snack prey (Chicken, Crab), on every player's client.
-- DINO-12, plan docs/plans/PREY_v1.0.md Task 2. A Script with RunContext Client (it runs inside a Workspace model on
--   every client; a LocalScript would not). Template: ServerStorage.DinoArcade.PreyScripts.PreyHop (does not run
--   there); PreyServer 1.0 clones it into each Chicken / Crab.
-- Every RenderStepped: speed = flat HumanoidRootPart velocity.
--   * moving (> MOVE_MIN 1 stud/s): RootJoint C0 = rest + up |sin(t x 2 pi x HOP_RATE 3)| x HOP_HEIGHT (0.35 x model
--     height), tilted HOP_TILT 8 degrees forward (body front: Chicken -Z, Crab +X, so the crab tips sideways);
--   * standing: a peck every 2-4 s (tilt PECK_TILT 25 degrees forward for PECK_TIME 0.25 s);
--   * knocked out / pinned (DummyState "ko" or PinnedAt set): rest pose (PreyServer rolls the whole body).
-- Diagnostic (client-side model attribute): PreyHopState ("hop" / "peck" / "idle" / "still"), PreyHopVersion.
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local model = script.Parent
if not model:IsA("Model") then return end
local MOVE_MIN, HOP_RATE, HOP_FRAC, HOP_TILT = 1, 3, 0.35, 8
local PECK_TILT, PECK_TIME = 25, 0.25

local hrp = model:WaitForChild("HumanoidRootPart", 10)
local torso = model:WaitForChild("Torso", 10)
local root = torso and torso:WaitForChild("Root", 10)
local joint = root and root:WaitForChild("RootJoint", 10)
if not (hrp and joint) then return end
model:SetAttribute("PreyHopVersion", VERSION)
local rest = joint.C0
local height = model:GetExtentsSize().Y
local sideways = model:GetAttribute("PreyKind") == "Crab"

local function tilt(deg)
	-- nose (or claws) down by deg
	if sideways then return CFrame.Angles(0, 0, -math.rad(deg)) end
	return CFrame.Angles(-math.rad(deg), 0, 0)
end

local shown
local function show(v)
	if shown ~= v then
		shown = v
		model:SetAttribute("PreyHopState", v)
	end
end

local t0 = os.clock()
local nextPeck = os.clock() + 2 + math.random() * 2
local peckUntil = 0
local conn
conn = RunService.RenderStepped:Connect(function()
	if not model.Parent or not joint.Parent then
		conn:Disconnect()
		return
	end
	if model:GetAttribute("DummyState") == "ko" or model:GetAttribute("PinnedAt") ~= nil then
		joint.C0 = rest
		show("still")
		return
	end
	local v = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local now = os.clock()
	if speed > MOVE_MIN then
		local up = math.abs(math.sin((now - t0) * 2 * math.pi * HOP_RATE)) * HOP_FRAC * height
		joint.C0 = rest * CFrame.new(0, up, 0) * tilt(HOP_TILT)
		nextPeck = now + 2 + math.random() * 2
		show("hop")
	elseif now < peckUntil then
		joint.C0 = rest * tilt(PECK_TILT)
		show("peck")
	elseif now >= nextPeck then
		peckUntil = now + PECK_TIME
		nextPeck = now + 2 + math.random() * 2
		joint.C0 = rest * tilt(PECK_TILT)
		show("peck")
	else
		joint.C0 = rest
		show("idle")
	end
end)
