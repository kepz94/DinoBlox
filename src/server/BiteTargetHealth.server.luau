-- BiteTargetHealth v1.1 (Dino Arcade) — TEST. Health for bitable dinos (Workspace models with the
-- attribute Bitable = true, e.g. the display T-Rex). BiteServer subtracts BiteDamage from DummyHealth.
-- Per target: DummyMaxHealth (default 200, kept if already set), DummyHealth, a floating name + health bar
-- over the head ("Display T-Rex" or the model's DisplayName attribute).
-- At 0 health: DummyState = "ko" and DummyKOAt = server time (WalkTest 1.2 lays the dino on its side and
-- stops its walk); after RESET_TIME it stands up with full health, DummyState = "ready".
-- Diagnostics (model attributes): DummyState, DummyKOs.
-- v1.1: Bitable models added to Workspace later (BotServer 1.0 bots) are set up when they appear (DescendantAdded),
--   once per model.
local MAX_HEALTH = 200
local RESET_TIME = 3

local COLORS = {bar = Color3.fromRGB(120, 200, 80), barBack = Color3.fromRGB(40, 30, 20)}

local function addBar(model)
	local head = model:FindFirstChild("Head")
	local anchor = head and head:FindFirstChild("Root")
	if not anchor or anchor:FindFirstChild("TargetBar") then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TargetBar"
	gui.Size = UDim2.fromOffset(170, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = model:GetAttribute("DisplayName") or "Display T-Rex"
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = COLORS.barBack
	back.BorderSizePixel = 0
	back.Position = UDim2.new(0, 10, 0, 22)
	back.Size = UDim2.new(1, -20, 0, 12)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = COLORS.bar
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	gui.Parent = anchor
end

local function refreshBar(model)
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("Root") and head.Root:FindFirstChild("TargetBar")
	if gui then
		local hp, max = model:GetAttribute("DummyHealth") or 0, model:GetAttribute("DummyMaxHealth") or MAX_HEALTH
		gui.Back.Fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	end
end

local function setup(model)
	if model:GetAttribute("DummyMaxHealth") == nil then model:SetAttribute("DummyMaxHealth", MAX_HEALTH) end
	model:SetAttribute("DummyHealth", model:GetAttribute("DummyMaxHealth"))
	model:SetAttribute("DummyState", "ready")
	model:SetAttribute("DummyKOs", 0)
	addBar(model)
	refreshBar(model)
	model:GetAttributeChangedSignal("DummyHealth"):Connect(function()
		refreshBar(model)
		if (model:GetAttribute("DummyHealth") or 0) <= 0 and model:GetAttribute("DummyState") == "ready" then
			model:SetAttribute("DummyKOAt", workspace:GetServerTimeNow())
			model:SetAttribute("DummyKOs", (model:GetAttribute("DummyKOs") or 0) + 1)
			model:SetAttribute("DummyState", "ko")
			task.delay(RESET_TIME, function()
				model:SetAttribute("DummyHealth", model:GetAttribute("DummyMaxHealth") or MAX_HEALTH)
				model:SetAttribute("DummyState", "ready")
			end)
		end
	end)
end

local done = {} -- v1.1: set up once per model
local function trySetup(d)
	if d:IsA("Model") and d:GetAttribute("Bitable") == true and not done[d] then
		done[d] = true
		d.Destroying:Connect(function() done[d] = nil end)
		setup(d)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do trySetup(d) end
workspace.DescendantAdded:Connect(trySetup) -- v1.1
