-- WalkTest v1.2 (Dino Arcade) — TEST ONLY. Walks this display model back and forth.
-- v1.1: moves on RunService.PreSimulation (same step the animator measures), so speed reads steadily.
-- v1.2: the walk is a pure function of a shared clock, so the server and every client put the model in
--   the same place (needed now that the display dino can be bitten: the server checks hits against its
--   own copy). The same source runs in two Script instances inside the model:
--     "WalkTest"       RunContext Client — moves the model on each client every PreSimulation (smooth)
--     "WalkTestServer" RunContext Server — owns the clock and moves the server copy every Heartbeat
--   Clock (model attributes, written by the server): WalkTestClock (seconds of walking done before
--   WalkTestClockAt), WalkTestClockAt (server time), WalkTestRunning (true/false).
--   elapsed = WalkTestClock + (running and now - WalkTestClockAt or 0).
--   The clock stops while the model is knocked out (DummyState = "ko", BiteTargetHealth) and restarts
--   when it is "ready" again; WalkTestEnabled = false stops it and returns the model to its start spot.
--   Knocked out: the model rolls onto its side over KO_ROLL_TIME seconds from DummyKOAt.
-- Loop: pause -> walk WalkTestDistance -> pause -> turn 180° -> walk back -> pause -> turn -> ...
-- Attributes: WalkTestEnabled (true/false), WalkTestSpeed (studs/s), WalkTestDistance (studs).
-- Diagnostic: WalkTestState = "off" / "pause" / "walk" / "turn" / "ko" (written by the server copy).
local RunService = game:GetService("RunService")
local model = script.Parent
local IS_SERVER = RunService:IsServer()

local DEFAULTS = {WalkTestEnabled = true, WalkTestSpeed = 16, WalkTestDistance = 40}
local PAUSE_TIME = 1.5
local TURN_TIME = 1.4
local KO_ROLL = math.rad(80)  -- degrees the body rolls onto its side when knocked out
local KO_ROLL_TIME = 0.35     -- seconds to fall over
local HALF_WIDTH = 4.5        -- studs from the centre line to the side it lands on

local function get(k)
	local v = model:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

model:WaitForChild("HumanoidRootPart")
-- start spot: stored once by the server so every copy uses the same one
if IS_SERVER then
	for k, v in pairs(DEFAULTS) do
		if model:GetAttribute(k) == nil then model:SetAttribute(k, v) end
	end
	if model:GetAttribute("WalkTestHome") == nil then model:SetAttribute("WalkTestHome", model:GetPivot()) end
end
local home = model:GetAttribute("WalkTestHome")
while not home do
	model:GetAttributeChangedSignal("WalkTestHome"):Wait()
	home = model:GetAttribute("WalkTestHome")
end

-- pose on the loop after `t` seconds of walking time; returns the pivot and the phase name
local function pathPose(t)
	local speed, dist = get("WalkTestSpeed"), get("WalkTestDistance")
	if t < PAUSE_TIME or speed <= 0 then return home, "pause" end
	t -= PAUSE_TIME
	local walkTime = dist / speed
	local leg = walkTime + PAUSE_TIME + TURN_TIME
	local i = math.floor(t / leg)
	local u = t - i * leg
	local odd = i % 2 == 1
	local start = odd and (home + home.RightVector * dist) or home -- model faces +X (RightVector)
	start = start * CFrame.Angles(0, odd and math.pi or 0, 0)
	if u < walkTime then
		return start + start.RightVector * (speed * u), "walk"
	end
	local finish = start + start.RightVector * dist
	if u < walkTime + PAUSE_TIME then return finish, "pause" end
	return finish * CFrame.Angles(0, math.pi * math.clamp((u - walkTime - PAUSE_TIME) / TURN_TIME, 0, 1), 0), "turn"
end

local function elapsed()
	local clock = model:GetAttribute("WalkTestClock") or 0
	if model:GetAttribute("WalkTestRunning") then
		clock += workspace:GetServerTimeNow() - (model:GetAttribute("WalkTestClockAt") or workspace:GetServerTimeNow())
	end
	return clock
end

-- full pose: path pose, rolled onto its side while knocked out
local function pose()
	if not get("WalkTestEnabled") then return home, "off" end
	local piv, phase = pathPose(elapsed())
	if model:GetAttribute("DummyState") == "ko" then
		local koAt = model:GetAttribute("DummyKOAt") or workspace:GetServerTimeNow()
		local k = math.clamp((workspace:GetServerTimeNow() - koAt) / KO_ROLL_TIME, 0, 1)
		local hip = model:GetAttribute("RigHipHeight") or 9.68
		local hinge = piv * CFrame.new(0, -hip, HALF_WIDTH) -- ground, under its right side
		piv = hinge * CFrame.Angles(KO_ROLL * k * k, 0, 0) * hinge:ToObjectSpace(piv)
		phase = "ko"
	end
	return piv, phase
end

if IS_SERVER then
	-- clock owner
	local function setRunning(run)
		local now = workspace:GetServerTimeNow()
		if model:GetAttribute("WalkTestRunning") then
			model:SetAttribute("WalkTestClock", elapsed())
		end
		model:SetAttribute("WalkTestClockAt", now)
		model:SetAttribute("WalkTestRunning", run)
	end
	local function refresh()
		local enabled = get("WalkTestEnabled")
		if not enabled then
			model:SetAttribute("WalkTestRunning", false)
			model:SetAttribute("WalkTestClock", 0)
			model:SetAttribute("WalkTestClockAt", workspace:GetServerTimeNow())
			return
		end
		local run = model:GetAttribute("DummyState") ~= "ko"
		if run ~= (model:GetAttribute("WalkTestRunning") == true) then setRunning(run) end
	end
	model:SetAttribute("WalkTestClock", 0)
	model:SetAttribute("WalkTestClockAt", workspace:GetServerTimeNow())
	model:SetAttribute("WalkTestRunning", false)
	refresh()
	model:GetAttributeChangedSignal("WalkTestEnabled"):Connect(refresh)
	model:GetAttributeChangedSignal("DummyState"):Connect(refresh)
	local lastPhase
	RunService.Heartbeat:Connect(function()
		local piv, phase = pose()
		model:PivotTo(piv)
		if phase ~= lastPhase then
			lastPhase = phase
			model:SetAttribute("WalkTestState", phase)
		end
	end)
else
	RunService.PreSimulation:Connect(function()
		model:PivotTo((pose()))
	end)
end
