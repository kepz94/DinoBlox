-- BushView v1.0 (Dino Arcade) — on the player's own screen, a bush the player is hiding in turns see-through
-- (LocalScript; other players still see the bush solid).
-- Bushes: Workspace.DinoIsland.Bushes models with DinoBush = true (tools/island_install.luau). "Inside" = the
-- HumanoidRootPart in the bush's bounding box + MARGIN studs (the same test BotServer 1.0 uses for Hidden).
-- Inside: every part of that bush gets LocalTransparencyModifier = SEE_THROUGH; leaving puts it back to 0.
-- Diagnostic (character attribute, this client): BushInside (bush name or "").
local RunService = game:GetService("RunService")

local char = script.Parent
local hrp = char:WaitForChild("HumanoidRootPart")
local MARGIN = 0.5
local SEE_THROUGH = 0.65
local CHECK_EVERY = 0.15

local island = workspace:WaitForChild("DinoIsland", 10)
local folder = island and island:FindFirstChild("Bushes")
if not folder then return end

local bushes = {}
for _, m in ipairs(folder:GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("DinoBush") == true then
		local cf, size = m:GetBoundingBox()
		table.insert(bushes, {model = m, cf = cf, half = size / 2 + Vector3.new(MARGIN, MARGIN, MARGIN)})
	end
end

local function setSeeThrough(m, on)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = on and SEE_THROUGH or 0 end
	end
end

local current
local last = 0
local conn
conn = RunService.Heartbeat:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		if current then setSeeThrough(current, false) end
		return
	end
	if os.clock() - last < CHECK_EVERY then return end
	last = os.clock()
	local inside
	for _, b in ipairs(bushes) do
		local p = b.cf:PointToObjectSpace(hrp.Position)
		if math.abs(p.X) <= b.half.X and math.abs(p.Y) <= b.half.Y and math.abs(p.Z) <= b.half.Z then
			inside = b.model
			break
		end
	end
	if inside ~= current then
		if current then setSeeThrough(current, false) end
		if inside then setSeeThrough(inside, true) end
		current = inside
		char:SetAttribute("BushInside", inside and inside.Name or "")
	end
end)
