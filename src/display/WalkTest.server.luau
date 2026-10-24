-- WalkTest v1.1 (Dino Arcade) — TEST ONLY. Walks this model back and forth on each player's client
-- so the walk animation can be seen. Not gameplay movement; delete or disable when no longer needed.
-- v1.1: moves on RunService.PreSimulation (same step the animator measures), so speed reads steadily.
-- Loop: pause -> walk WalkTestDistance -> pause -> turn 180° -> walk back -> pause -> turn -> ...
-- Attributes: WalkTestEnabled (true/false), WalkTestSpeed (studs/s), WalkTestDistance (studs).
-- Diagnostic: WalkTestState = "off" / "pause" / "walk" / "turn". Disabling returns the model to its start spot.
local RunService = game:GetService("RunService")
local model = script.Parent

local DEFAULTS = {WalkTestEnabled = true, WalkTestSpeed = 16, WalkTestDistance = 40}
for k, v in pairs(DEFAULTS) do
	if model:GetAttribute(k) == nil then model:SetAttribute(k, v) end
end

local PAUSE_TIME = 1.5
local TURN_TIME = 1.4

model:WaitForChild("HumanoidRootPart")
local home = model:GetPivot()
local state, t0 = nil, os.clock()
local afterPause = "walk"
local travelled, turned = 0, 0

local function setState(s)
	state, t0 = s, os.clock()
	model:SetAttribute("WalkTestState", s)
end
setState("pause")

RunService.PreSimulation:Connect(function(dt)
	if not model:GetAttribute("WalkTestEnabled") then
		if state ~= "off" then
			model:PivotTo(home)
			travelled, turned, afterPause = 0, 0, "walk"
			setState("off")
		end
		return
	end
	if state == "off" then
		setState("pause")
	end

	local piv = model:GetPivot()
	if state == "pause" then
		if os.clock() - t0 >= PAUSE_TIME then
			if afterPause == "walk" then
				travelled = 0
				setState("walk")
			else
				turned = 0
				setState("turn")
			end
		end
	elseif state == "walk" then
		local dist = model:GetAttribute("WalkTestDistance") or DEFAULTS.WalkTestDistance
		local step = math.min((model:GetAttribute("WalkTestSpeed") or DEFAULTS.WalkTestSpeed) * dt, dist - travelled)
		model:PivotTo(piv + piv.RightVector * step) -- model faces +X
		travelled += step
		if travelled >= dist - 1e-3 then
			afterPause = "turn"
			setState("pause")
		end
	elseif state == "turn" then
		local step = math.min(math.pi / TURN_TIME * dt, math.pi - turned)
		model:PivotTo(piv * CFrame.Angles(0, step, 0))
		turned += step
		if turned >= math.pi - 1e-3 then
			travelled = 0
			setState("walk")
		end
	end
end)
