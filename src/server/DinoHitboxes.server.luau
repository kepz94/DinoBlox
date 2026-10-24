-- DinoHitboxes v1.0 (Dino Arcade) — gives every dino a hitbox over each body part.
-- Builds a folder "Hitboxes" in each dino model with one invisible box per segment (Torso, Neck, Head,
-- Jaw, Tail1-5, LegL/R, ShinL/R, FootL/R, ArmL/R). Each box is the segment's visual parts' bounding box
-- in the segment's Root frame, welded to that Root, so it follows the animation on every client.
-- Rules per box (attribute HitboxBlocks):
--   blocks (CanCollide = true): Torso, Neck, Head, Tail1-5 — the head/body/tail cannot pass into the
--     world, the training dummy or other dinos.
--   bite-only (CanCollide = false): Jaw, legs, feet, arms — walking/IK on the ground is untouched.
--   Head and Jaw boxes end at the middle of the mouth (Head_mouth centre), so only the front half of
--   the jaws can sink into a target.
-- All boxes: Massless, CanQuery = true (bites find them), CanTouch = false, CollisionGroup "DinoHitbox",
-- attributes HitboxSegment (segment name), HitboxBlocks (true/false).
-- Who gets them: every player character (CharacterAdded) and every Workspace model with a Species
-- attribute (display dinos). A model that already has a "Hitboxes" folder is left as it is.
-- Diagnostics (model attributes): HitboxCount, HitboxVersion.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local VERSION = "1.0"
local GROUP = "DinoHitbox"
local BLOCKS = {Torso = true, Neck = true, Head = true, Tail1 = true, Tail2 = true, Tail3 = true, Tail4 = true, Tail5 = true}
local MOUTH_CLIPPED = {Head = true, Jaw = true}

pcall(function() PhysicsService:RegisterCollisionGroup(GROUP) end)

-- bounding box of a segment's visual parts in its Root frame: returns min, max (Vector3)
local function segmentBounds(seg, root)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	local any = false
	for _, p in ipairs(seg:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local h = p.Size / 2
			for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
				local c = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
				lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
				hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
				any = true
			end end end
		end
	end
	if not any then return nil end
	return lo, hi
end

local function build(model)
	if model:FindFirstChild("Hitboxes") then return end
	local head = model:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	local mouthMid = mouth and mouth.Position
	local folder = Instance.new("Folder")
	folder.Name = "Hitboxes"
	folder.Parent = model
	local count = 0
	for _, seg in ipairs(model:GetChildren()) do
		local root = seg:IsA("Model") and seg:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			local lo, hi = segmentBounds(seg, root)
			if lo then
				if MOUTH_CLIPPED[seg.Name] and mouthMid then
					-- front half of the mouth stays outside the box (forward = Root +X)
					local mx = root.CFrame:PointToObjectSpace(mouthMid).X
					if mx > lo.X then hi = Vector3.new(math.min(hi.X, mx), hi.Y, hi.Z) end
				end
				local blocks = BLOCKS[seg.Name] == true
				local box = Instance.new("Part")
				box.Name = "Hitbox_" .. seg.Name
				box.Size = hi - lo
				box.CFrame = root.CFrame * CFrame.new((lo + hi) / 2)
				box.Transparency = 1
				box.Color = blocks and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(70, 130, 230)
				box.Material = Enum.Material.SmoothPlastic
				box.Anchored = false
				box.Massless = true
				box.CanCollide = blocks
				box.CanQuery = true
				box.CanTouch = false
				box.CollisionGroup = GROUP
				box:SetAttribute("HitboxSegment", seg.Name)
				box:SetAttribute("HitboxBlocks", blocks)
				box.Parent = folder
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = box
				weld.Parent = box
				count += 1
			end
		end
	end
	model:SetAttribute("HitboxCount", count)
	model:SetAttribute("HitboxVersion", VERSION)
end

-- player characters
local function onCharacter(char)
	char:WaitForChild("Head", 10)
	char:WaitForChild("Tail5", 10)
	build(char)
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- display dinos already in the world (models with a Species attribute that are not player characters)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("Species") and not Players:GetPlayerFromCharacter(d) then
		build(d)
	end
end
