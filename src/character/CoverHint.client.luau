-- CoverHint v1.0 (Dino Arcade) — "Too tall to hide here · hold C to creep" while standing in / next to grass that would hide
--   this dino if it crept (LocalScript). DINO-27, plan docs/plans/AMBUSH_v1.0.md Task 4, ADR-004; user: "Show the hint".
-- Reads the character attribute CoverHint (BotServer 1.7, from GrassCover 1.0); writes nothing the server reads.
-- Layout: ScreenGui "CoverHint" (ResetOnSpawn, DisplayOrder 5); label AnchorPoint (0.5, 1) at (0.5, 0, 1, -250), above
--   GrowthBar (holder -198, 44 tall: top at -242); 26 px tall, width fits the text + 24 px; panel rgb(20,20,26) at 0.2,
--   10 px corners; FredokaOne 15 white, RichText, "C" in rgb(255,210,60). Fades in / out over FADE_TIME 0.15 s.
-- Shown while CoverHint is true and the character attribute CoverHintEnabled is not false.
-- Diagnostics (this client, character): CoverHintVersion, CoverHintShown (true / false).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local VERSION = "1.0"
local char = script.Parent
if not char:IsA("Model") then return end
local player = Players.LocalPlayer
local FADE_TIME = 0.15
local PLAIN = "Too tall to hide here · hold C to creep"
local RICH = 'Too tall to hide here · hold <font color="rgb(255,210,60)">C</font> to creep'

char:SetAttribute("CoverHintVersion", VERSION)

local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("CoverHint")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "CoverHint"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local w = TextService:GetTextSize(PLAIN, 15, Enum.Font.FredokaOne, Vector2.new(1000, 26)).X + 24
local label = Instance.new("TextLabel")
label.Name = "Hint"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -250)
label.Size = UDim2.fromOffset(w, 26)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
label.BackgroundTransparency = 1
label.Font = Enum.Font.FredokaOne
label.TextSize = 15
label.TextColor3 = Color3.new(1, 1, 1)
label.RichText = true
label.Text = RICH
label.TextTransparency = 1
label.TextStrokeTransparency = 1
label.Visible = false
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label
gui.Parent = pg

local alpha = 0 -- 0 hidden .. 1 shown
local shown
RunService.RenderStepped:Connect(function(dt)
	local want = char:GetAttribute("CoverHint") == true and char:GetAttribute("CoverHintEnabled") ~= false
	if shown ~= want then
		shown = want
		char:SetAttribute("CoverHintShown", want)
	end
	local target = want and 1 or 0
	if alpha ~= target then
		local step = dt / FADE_TIME
		alpha = target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step)
		label.Visible = alpha > 0
		label.BackgroundTransparency = 1 - 0.8 * alpha
		label.TextTransparency = 1 - alpha
		label.TextStrokeTransparency = 1 - 0.6 * alpha
	end
end)
