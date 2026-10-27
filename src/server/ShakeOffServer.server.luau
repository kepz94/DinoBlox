-- ShakeOffServer v1.0 (Dino Arcade) — TEST. Two ways for a big dino (T-Rex) to get rid of raptors latched onto it
-- (user: "ram into a tree which stuns the animal that was latched long enough for the t-rex to bite ... the other way
-- to rid a raptor is to step in water, it automatically makes a raptor jump off").
-- Latched raptors: player characters and bots with PounceLatched = true whose ObjectValue PounceLatchPart points into
--   another model (PounceServer 1.2 latches / BotServer 1.2 bot latches). Pins (PounceMode "pin") are not shaken.
-- Every TICK s, per dino that has raptors latched on it:
--   * water: a ray down from its HumanoidRootPart (dinos and tall grass ignored) hits DinoIsland's Shallows / Seabed
--     or lands below the water top (DinoIsland.Ground.Water) - 0.3 -> every latched raptor gets ShakeOffReason
--     "water" (it leaps off: PounceTest 1.3 / BotServer 1.2).
--   * tree ram: its fastest flat speed over the last RAM_WINDOW s is at least RAM_SPEED_MUL (0.75) x its MoveRunSpeed
--     (running, not walking) AND one of its blocking hitboxes (HitboxBlocks: torso, neck, head, tail) or its
--     HumanoidRootPart, grown by RAM_REACH studs, touches a tree trunk or root (DinoIsland.Trees parts named Trunk* /
--     Root) -> every latched raptor gets ShakeOffReason "rammed" and StunnedUntil = now + STUN_TIME (3 s): it drops
--     off and lies stunned (StunClient 1.0 for players, BotServer 1.2 for bots). One ram per RAM_COOLDOWN s.
--   Shaking sets on the raptor: ShakeOffReason, ShakeOffAt (server time; PounceServer / BotServer release a latch made
--   before it), and for a ram StunnedUntil.
-- Diagnostics: on the shaking dino ShakeOffCount, ShakeOffLast ("water" / "rammed"), ShakeOffLastAt, RamSpeed (studs/s,
--   whole, the windowed max while raptors are on it), InWater; script attribute ShakeOffServerVersion.
local Players = game:GetService("Players")

local VERSION = "1.0"
local TICK = 0.05
local RAM_WINDOW = 0.5
local RAM_SPEED_MUL = 0.75
local RAM_REACH = 1.5
local RAM_COOLDOWN = 1
local STUN_TIME = 3

script:SetAttribute("ShakeOffServerVersion", VERSION)

local island = workspace:WaitForChild("DinoIsland", 10)
local waterTop = -0.8
local trunkParams = OverlapParams.new()
trunkParams.FilterType = Enum.RaycastFilterType.Include
local function refreshTrunks()
	local list = {}
	local trees = island and island:FindFirstChild("Trees")
	if trees then
		for _, d in ipairs(trees:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name:find("^Trunk") or d.Name == "Root") then table.insert(list, d) end
		end
	end
	trunkParams.FilterDescendantsInstances = list
	return #list
end
if island then
	local ground = island:FindFirstChild("Ground")
	local water = ground and ground:FindFirstChild("Water")
	if water then waterTop = water.Position.Y + water.Size.Y / 2 end
	script:SetAttribute("ShakeOffTrunks", refreshTrunks())
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local speedLog = {} -- [model] = {{t, speed}, ...}
local lastRam = {}

local function inWater(model, hrp)
	local ignore = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	if island then
		for _, n in ipairs({"Bots", "TallGrass", "Bushes"}) do
			local f = island:FindFirstChild(n)
			if f then table.insert(ignore, f) end
		end
	end
	table.insert(ignore, model)
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -80, 0), rayParams)
	if not hit then return false end
	if hit.Instance.Name == "Shallows" or hit.Instance.Name == "Seabed" then return true end
	return hit.Position.Y < waterTop - 0.3
end

local function touchesTrunk(model, hrp)
	local parts = {hrp}
	local hb = model:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxBlocks") == true then table.insert(parts, p) end
		end
	end
	for _, p in ipairs(parts) do
		local hits = workspace:GetPartBoundsInBox(p.CFrame, p.Size + Vector3.new(RAM_REACH, RAM_REACH, RAM_REACH) * 2, trunkParams)
		if #hits > 0 then return true end
	end
	return false
end

local function shake(latcher, target, reason, now)
	latcher:SetAttribute("ShakeOffReason", reason)
	if reason == "rammed" then latcher:SetAttribute("StunnedUntil", now + STUN_TIME) end
	latcher:SetAttribute("ShakeOffAt", now) -- last: the latch owners react to this one
	target:SetAttribute("ShakeOffCount", (target:GetAttribute("ShakeOffCount") or 0) + 1)
	target:SetAttribute("ShakeOffLast", reason)
	target:SetAttribute("ShakeOffLastAt", now)
end

-- latched raptors -> {[target model] = {latcher, ...}}
local function collect()
	local byTarget = {}
	local function consider(m)
		if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return end
		local v = m:FindFirstChild("PounceLatchPart")
		local part = v and v.Value
		if not part or not part:IsDescendantOf(workspace) then return end
		local folder = part.Parent
		local target = folder and folder.Name == "Hitboxes" and folder.Parent or part:FindFirstAncestorWhichIsA("Model")
		if not target or target == m then return end
		byTarget[target] = byTarget[target] or {}
		table.insert(byTarget[target], m)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then consider(pl.Character) end
	end
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do consider(m) end
	end
	return byTarget
end

while true do
	task.wait(TICK)
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local ok, err = pcall(function()
		local byTarget = collect()
		for model in pairs(speedLog) do
			if not byTarget[model] then speedLog[model] = nil end
		end
		for target, latchers in pairs(byTarget) do
			local hrp = target:FindFirstChild("HumanoidRootPart")
			if hrp then
				local v = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local log = speedLog[target] or {}
				speedLog[target] = log
				table.insert(log, {clock, speed})
				while log[1] and clock - log[1][1] > RAM_WINDOW do table.remove(log, 1) end
				local maxSpeed = 0
				for _, e in ipairs(log) do maxSpeed = math.max(maxSpeed, e[2]) end
				target:SetAttribute("RamSpeed", math.floor(maxSpeed + 0.5))
				local wet = inWater(target, hrp)
				target:SetAttribute("InWater", wet)
				if wet then
					for _, l in ipairs(latchers) do shake(l, target, "water", now) end
				elseif maxSpeed >= (target:GetAttribute("MoveRunSpeed") or 28) * RAM_SPEED_MUL
					and clock - (lastRam[target] or -math.huge) >= RAM_COOLDOWN and touchesTrunk(target, hrp) then
					lastRam[target] = clock
					for _, l in ipairs(latchers) do shake(l, target, "rammed", now) end
				end
			end
		end
	end)
	if not ok then warn("ShakeOffServer: " .. tostring(err)) end
end
