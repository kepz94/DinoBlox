-- display_raptor_install v1.0 (Dino Arcade) — Edit-mode builder for the display raptor (run once with execute_luau on
-- the Edit datamodel; not synced by Rojo). Builds Workspace.DinoArcade_Raptor.Raptor_v1.0_Display from
-- ServerStorage.DinoArcade.Models.RaptorModelData with DinoModelBuilder, like the display T-Rex:
--   * anchored HumanoidRootPart; PrimaryPart.PivotOffset = CFrame.Angles(0, pi / 2, 0) so the model pivot's
--     RightVector is the raptor's forward (WalkTest walks along the pivot's RightVector);
--   * scripts copied in: IdleAnimation (with its pose modules) and StatusBadges from
--     StarterPlayer.StarterCharacterScripts, WalkTest (Client) + WalkTestServer (Server) from the display T-Rex;
--   * attributes on top of the model data: Bitable true, DummyMaxHealth 60, DisplayName "Display Raptor",
--     WalkTestSpeed 30 (walk out), WalkTestReturnSpeed 52 (run back), WalkTestDistance 100, WalkTestTurnTime 0.5,
--     WalkTestKOHalfWidth 0.9, DisplayRaptorVersion "1.0".
-- DinoHitboxes 1.0 and BiteTargetHealth 1.0 pick it up at Play start (they scan Workspace for Species / Bitable
-- models), so the T-Rex can bite it and the raptor can pounce on nothing smaller than itself.
-- Re-running replaces an existing DinoArcade_Raptor folder.
local HOME = Vector3.new(-60, 0, 120) -- ground point of the start spot (walks +X for WalkTestDistance studs)
local VERSION = "1.0"

local SS = game:GetService("ServerStorage")
local SCS = game:GetService("StarterPlayer").StarterCharacterScripts
local folderSrc = SS:FindFirstChild("DinoArcade")
assert(folderSrc, "ServerStorage.DinoArcade missing")
local Builder = require(folderSrc.DinoModelBuilder)
local data = require(folderSrc.Models.RaptorModelData)
local trex = workspace:FindFirstChild("DinoArcade_TRex") and workspace.DinoArcade_TRex:FindFirstChild("TRex_v1.1_StripeEye")
assert(trex and trex:FindFirstChild("WalkTest") and trex:FindFirstChild("WalkTestServer"), "display T-Rex WalkTest scripts missing")
assert(SCS:FindFirstChild("IdleAnimation") and SCS:FindFirstChild("StatusBadges"), "StarterCharacterScripts copies missing")

local old = workspace:FindFirstChild("DinoArcade_Raptor")
if old then old:Destroy() end

local hipCentre = data.humanoid.HipHeight + data.hrp.size[2] / 2 -- HRP centre above the ground
local pivot = CFrame.lookAt(HOME + Vector3.new(0, hipCentre, 0), HOME + Vector3.new(1, hipCentre, 0)) -- faces +X
local model = Builder.build(data, {name = "Raptor_v1.0_Display", pivot = pivot, anchored = true})
model.PrimaryPart.PivotOffset = CFrame.Angles(0, math.pi / 2, 0)

model:SetAttribute("Bitable", true)
model:SetAttribute("DummyMaxHealth", 60)
model:SetAttribute("DisplayName", "Display Raptor")
model:SetAttribute("WalkTestSpeed", 30)
model:SetAttribute("WalkTestReturnSpeed", 52)
model:SetAttribute("WalkTestDistance", 100)
model:SetAttribute("WalkTestTurnTime", 0.5)
model:SetAttribute("WalkTestKOHalfWidth", 0.9)
model:SetAttribute("DisplayRaptorVersion", VERSION)

SCS.IdleAnimation:Clone().Parent = model
SCS.StatusBadges:Clone().Parent = model
trex.WalkTest:Clone().Parent = model
trex.WalkTestServer:Clone().Parent = model

local folder = Instance.new("Folder")
folder.Name = "DinoArcade_Raptor"
model.Parent = folder
folder.Parent = workspace

local scripts = {}
for _, c in ipairs(model:GetChildren()) do
	if c:IsA("LuaSourceContainer") then table.insert(scripts, c.Name .. ":" .. tostring(c.RunContext)) end
end
return ("built %s at %s, forward %s, extents %s, scripts %s"):format(model:GetFullName(), tostring(model.PrimaryPart.Position),
	tostring(model:GetPivot().RightVector), tostring(model:GetExtentsSize()), table.concat(scripts, ", "))
