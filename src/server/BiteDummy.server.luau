-- BiteDummy v1.1 (Dino Arcade) — TEST. Builds a brick training dummy to bite (if Workspace has none) and
-- runs its health: BiteServer subtracts BiteDamage from DummyHealth on each hit.
-- Model "BiteDummy" at DUMMY_POSITION: base slab, post, straw body with a red band, head, and a floating
-- name + health bar. Attributes: BiteDummy = true (BiteServer only damages models with this),
--   DummyMaxHealth (200), DummyHealth.
-- At 0 health: DummyState = "ko", the dummy tips over for RESET_TIME seconds, then stands back up at full
--   health (DummyState = "ready"). Diagnostics: DummyState, DummyKOs (times knocked out).
-- v1.1: builds nothing while Workspace.DinoIsland exists (the island has no training dummy); BiteDummyState = "island".
local DUMMY_POSITION = Vector3.new(0, 0, -45) -- ground point under the dummy
local MAX_HEALTH = 200
local RESET_TIME = 2
local KO_TILT = 75 -- degrees

local COLORS = {
	dark = Color3.fromHex("50523A"), wood = Color3.fromRGB(110, 86, 58), straw = Color3.fromHex("B2A278"),
	band = Color3.fromHex("6E342E"), bar = Color3.fromRGB(120, 200, 80), barBack = Color3.fromRGB(40, 30, 20),
}

local function block(model, name, size, pos, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(DUMMY_POSITION + pos)
	p.Color = color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
	for _, f in ipairs({"Top", "Bottom", "Front", "Back", "Left", "Right"}) do p[f .. "Surface"] = Enum.SurfaceType.Studs end
	p.Parent = model
	return p
end

local dummy = workspace:FindFirstChild("BiteDummy")
-- v1.1: no training dummy on the island (tools/island_install.luau moves the test area to ServerStorage)
if not dummy and workspace:FindFirstChild("DinoIsland") then
	script:SetAttribute("BiteDummyState", "island")
	return
end
if not dummy then
	dummy = Instance.new("Model")
	dummy.Name = "BiteDummy"
	local base = block(dummy, "Base", Vector3.new(8, 1, 8), Vector3.new(0, 0.5, 0), COLORS.dark)
	block(dummy, "Post", Vector3.new(2, 10, 2), Vector3.new(0, 6, 0), COLORS.wood)
	block(dummy, "Body", Vector3.new(6, 8, 5), Vector3.new(0, 14, 0), COLORS.straw)
	block(dummy, "Band", Vector3.new(6.2, 1.2, 5.2), Vector3.new(0, 14, 0), COLORS.band)
	local head = block(dummy, "Head", Vector3.new(4, 4, 4), Vector3.new(0, 20, 0), COLORS.straw)
	dummy.PrimaryPart = base
	-- floating name + health bar
	local gui = Instance.new("BillboardGui")
	gui.Name = "DummyBar"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = "Training Dummy"
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
	gui.Parent = head
	dummy.Parent = workspace
end

dummy:SetAttribute("BiteDummy", true)
dummy:SetAttribute("DummyMaxHealth", MAX_HEALTH)
dummy:SetAttribute("DummyHealth", MAX_HEALTH)
dummy:SetAttribute("DummyState", "ready")
dummy:SetAttribute("DummyKOs", 0)

local home = dummy:GetPivot()
local function refreshBar()
	local head = dummy:FindFirstChild("Head")
	local fill = head and head:FindFirstChild("DummyBar") and head.DummyBar.Back.Fill
	if fill then
		local hp, max = dummy:GetAttribute("DummyHealth") or 0, dummy:GetAttribute("DummyMaxHealth") or MAX_HEALTH
		fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	end
end

dummy:GetAttributeChangedSignal("DummyHealth"):Connect(function()
	refreshBar()
	if (dummy:GetAttribute("DummyHealth") or 0) <= 0 and dummy:GetAttribute("DummyState") == "ready" then
		dummy:SetAttribute("DummyState", "ko")
		dummy:SetAttribute("DummyKOs", (dummy:GetAttribute("DummyKOs") or 0) + 1)
		-- tip over about the front edge of the base
		local hinge = home * CFrame.new(0, -0.5, -4)
		dummy:PivotTo(hinge * CFrame.Angles(math.rad(-KO_TILT), 0, 0) * hinge:ToObjectSpace(home))
		task.delay(RESET_TIME, function()
			dummy:PivotTo(home)
			dummy:SetAttribute("DummyHealth", dummy:GetAttribute("DummyMaxHealth") or MAX_HEALTH)
			dummy:SetAttribute("DummyState", "ready")
		end)
	end
end)
refreshBar()
