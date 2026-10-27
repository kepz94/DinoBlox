-- BushView v1.1 (Dino Arcade) — on the player's own screen, a bush the player is hiding in turns see-through
-- (LocalScript; other players still see the bush solid).
-- Bushes: Workspace.DinoIsland.Bushes models with DinoBush = true (tools/island_install.luau). "Inside" = the
-- HumanoidRootPart in the bush's bounding box + MARGIN studs (the same test BotServer 1.0 uses for Hidden).
-- Inside: every part of that bush gets LocalTransparencyModifier = SEE_THROUGH; leaving puts it back to 0.
-- Diagnostic (character attribute, this client): BushInside (bush name or "").
-- v1.1: tall-grass patches (DinoIsland.TallGrass, island 1.1) are read too, as well as DinoIsland.Bushes. With
--   streaming on, patches arrive and leave as the player moves (they stream whole: ModelStreamingMode Atomic), so the
--   list follows ChildAdded / ChildRemoved of both folders.
local RunService = game:GetService("RunService")

local char = script.Parent
local hrp = char:WaitForChild("HumanoidRootPart")
local MARGIN = 0.5
local SEE_THROUGH = 0.65
local CHECK_EVERY = 0.15

local island = workspace:WaitForChild("DinoIsland", 10)
if not island then return end

local bushes = {}
local function addBush(m)
	if m:IsA("Model") and m:GetAttribute("DinoBush") == true and #m:GetChildren() > 0 then
		local cf, size = m:GetBoundingBox()
		table.insert(bushes, {model = m, cf = cf, half = size / 2 + Vector3.new(MARGIN, MARGIN, MARGIN)})
	end
end
local function removeBush(m)
	for i = #bushes, 1, -1 do
		if bushes[i].model == m then table.remove(bushes, i) end
	end
end
for _, folderName in ipairs({"Bushes", "TallGrass"}) do -- v1.1: + TallGrass
	task.spawn(function()
		local folder = island:WaitForChild(folderName, 10)
		if folder then
			for _, m in ipairs(folder:GetChildren()) do addBush(m) end
			folder.ChildAdded:Connect(addBush) -- v1.1: streamed in
			folder.ChildRemoved:Connect(removeBush) -- v1.1: streamed out
		end
	end)
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
