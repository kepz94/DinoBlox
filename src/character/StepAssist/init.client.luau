-- StepAssist v1.0 (Dino Arcade) — step-up assist for the player's own dino (LocalScript, owner client: it owns the
-- character's physics). Rule and diagnostics: the child module StepAssistCore 1.0 (shared with StepAssistServer 1.0,
-- which does the same for bots and prey). Toggle: DinoIsland attribute StepAssistEnabled (default true); height limit:
-- DinoIsland attribute StepAssistMax (default 2.6 studs). User (DINO-7 terrain gate): step-up assist, all dinos.
-- Diagnostic: character attribute StepAssistVersion (this client).
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local char = script.Parent -- a LocalScript in a character only runs on its owner's client
local Core = require(script:WaitForChild("StepAssistCore"))
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
char:SetAttribute("StepAssistVersion", VERSION)

local st = Core.new(char, hum, hrp)
local conn
conn = RunService.PreSimulation:Connect(function(dt)
	if not char.Parent or not hrp.Parent then
		conn:Disconnect()
		return
	end
	Core.step(st, dt, workspace:GetServerTimeNow())
end)
