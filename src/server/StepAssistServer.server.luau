-- StepAssistServer v1.0 (Dino Arcade) — step-up assist for server-owned dinos: every model with a Humanoid and a
-- HumanoidRootPart in Workspace.DinoIsland.Bots (BotServer) and Workspace.DinoIsland.Prey (PreyServer, when present).
-- Same rule as the player's StepAssist 1.0: StarterPlayer.StarterCharacterScripts.StepAssist.StepAssistCore 1.0.
-- BotServer is not changed: this script only lifts a blocked bot onto a ledge (its own MoveTo goals, hop, latch,
-- pin and toss logic stay as they are; an anchored or airborne bot is skipped by the core).
-- Toggle: DinoIsland attribute StepAssistEnabled (default true); StepAssistMax (default 2.6).
-- Bots in BotState "hop" (BotServer 1.5 lake climb-out) or "latched" are left to BotServer (core state reset).
-- Direction: these dinos walk by Humanoid:MoveTo, so the core reads the MoveTo goal (walkTo option).
-- Diagnostics: script attributes StepAssistServerVersion, StepAssistTracked (models followed); per model: see the core.
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.0"
script:SetAttribute("StepAssistServerVersion", VERSION)
local Core = require(StarterPlayer:WaitForChild("StarterCharacterScripts"):WaitForChild("StepAssist"):WaitForChild("StepAssistCore"))
local island = workspace:WaitForChild("DinoIsland", 30)
if not island then
	script:SetAttribute("StepAssistServerState", "noIsland")
	return
end
script:SetAttribute("StepAssistServerState", "running")

local tracked = {} -- [model] = core state
local function folders()
	local list = {}
	for _, name in ipairs({"Bots", "Prey"}) do
		local f = island:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	return list
end

local scanAt = 0
RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	if now >= scanAt then
		scanAt = now + 1
		for m in pairs(tracked) do
			if not m.Parent then tracked[m] = nil end
		end
		for _, f in ipairs(folders()) do
			for _, m in ipairs(f:GetChildren()) do
				if m:IsA("Model") and not tracked[m] then
					local hum = m:FindFirstChildOfClass("Humanoid")
					local hrp = m:FindFirstChild("HumanoidRootPart")
					if hum and hrp then tracked[m] = Core.new(m, hum, hrp, {walkTo = true}) end
				end
			end
		end
		local n = 0
		for _ in pairs(tracked) do n += 1 end
		script:SetAttribute("StepAssistTracked", n)
	end
	local t = workspace:GetServerTimeNow()
	for m, st in pairs(tracked) do
		local bs = m:GetAttribute("BotState")
		if bs == "hop" or bs == "latched" then
			st.lift, st.blockedFor = nil, 0
		elseif m.Parent and st.hrp.Parent and st.hum.Parent then
			local ok, err = pcall(Core.step, st, dt, t)
			if not ok then warn("StepAssistServer: " .. tostring(err)) end
		end
	end
end)
