-- BotServer v1.0 (Dino Arcade) — TEST bot dinosaurs on the island (Workspace.DinoIsland, tools/island_install.luau).
-- Bots: one per marker in DinoIsland.BotSpawns (attribute Species: 3 x "Raptor", 1 x "TRex"), parented to
--   DinoIsland.Bots as "Bot_<Species>_<n>".
--   Raptor = DinoModelBuilder build of ServerStorage.DinoArcade.Models.RaptorModelData (as SpeciesServer 1.0 does);
--   TRex = a clone of StarterPlayer.StarterCharacter. Each gets clones of StarterCharacterScripts.IdleAnimation and
--   StatusBadges (animation + badges on every client, like the display dinos), and the attributes IsBot = true,
--   BotSpecies, Bitable = true, DummyMaxHealth (Raptor 60, TRex 200), DisplayName ("Raptor Bot" / "T-Rex Bot") and
--   BiteEnabled = true (so IdleAnimation shows the bot's bites). DinoHitboxes 1.1 / BiteTargetHealth 1.1 give it
--   hitboxes and the health bar, so player bites (BiteServer) and pounces (PounceServer: latch onto the T-Rex bot,
--   pin a raptor bot) work on bots as on the display dinos. Movement: Humanoid:MoveTo, server-owned physics.
-- Behaviour (every TICK s):
--   wander  - walk (MoveWalkSpeed) to a random point within BotWanderRadius of its spawn (inside the island's
--             IslandWanderLimit), pause 1-3 s ("idle"), repeat.
--   chase   - the nearest player dino within BotSightRange that is not hidden: run at MoveRunSpeed x BotChaseSpeedMul.
--             Lost when farther than BotLoseRange, dead, or hidden for longer than BotHiddenLoseTime (while hidden
--             it heads for the last seen spot).
--   bite    - when the bot's snout (front of Head_mouth) is within the species bite reach of the target's nearest
--             hitbox and the cooldown is over: BiteStartedAt = server time (the bite pose on every client); after
--             BITE_HIT_DELAY s (wind-up + strike) the reach is checked again (+1 stud) and the target's Humanoid
--             takes the bite damage; BiteHitAt = server time (head thrash).
--   pinned  - while PinnedAt is set (PounceServer 1.1): the bot stops, its HumanoidRootPart is anchored and it rolls
--             onto its side over ROLL_TIME; when the pin ends it rolls back up (GETUP_TIME) and carries on.
--   ko      - DummyState = "ko" (BiteTargetHealth): it rolls onto its side and stays down (also through a
--             BiteTargetHealth reset), is removed BotKORemoveTime s later (or when a pin on it ends, whichever is
--             later), and a new bot of the same species spawns at the same marker after BotRespawnTime s.
-- Hiding: a player whose HumanoidRootPart is inside a bush (DinoIsland.Bushes models with DinoBush = true; the
--   bush's bounding box + 0.5 studs) is hidden: character attribute Hidden = true (shown by HealthBar 1.0). Bots
--   neither see nor keep chasing (after BotHiddenLoseTime) a hidden player.
-- Species settings (bite damage / cooldown / reach, health, lying half width): SPECIES below. Tunables: attributes
--   on this script override BotSightRange 60, BotLoseRange 90, BotHiddenLoseTime 2, BotWanderRadius 60,
--   BotChaseSpeedMul 0.9, BotRespawnTime 10, BotKORemoveTime 2.5.
-- Diagnostics: bot attributes BotState (wander/idle/chase/search/bite/pinned/ko/getup), BotTarget (player name or
--   ""), BotBites (hits landed), BotSpawnedAt; player character Hidden, LastHitBy, LastHitDamage, LastHitAt;
--   script attributes BotServerVersion, BotServerState ("running" / "noIsland" / "noTemplates"), BotCount.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local TICK = 0.1
local BITE_HIT_DELAY = 0.25
local ROLL_TIME = 0.4
local GETUP_TIME = 0.5
local BUSH_MARGIN = 0.5
local DEFAULTS = {BotSightRange = 60, BotLoseRange = 90, BotHiddenLoseTime = 2, BotWanderRadius = 60,
	BotChaseSpeedMul = 0.9, BotRespawnTime = 10, BotKORemoveTime = 2.5}
local SPECIES = {
	Raptor = {health = 60, biteDamage = 8, biteCooldown = 1.0, biteReach = 3, halfWidth = 0.9, displayName = "Raptor Bot"},
	TRex = {health = 200, biteDamage = 25, biteCooldown = 1.6, biteReach = 6, halfWidth = 4.5, displayName = "T-Rex Bot"},
}

script:SetAttribute("BotServerVersion", VERSION)

local function get(k)
	local v = script:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local island = workspace:WaitForChild("DinoIsland", 10)
if not island then
	script:SetAttribute("BotServerState", "noIsland")
	return
end
local botFolder = island:FindFirstChild("Bots")
if not botFolder then
	botFolder = Instance.new("Folder")
	botFolder.Name = "Bots"
	botFolder.Parent = island
end
local wanderLimit = island:GetAttribute("IslandWanderLimit") or 165

-- templates
local templates = {}
do
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("RaptorModelData"))
		templates.Raptor = Builder.build(data, {name = "Raptor"})
	end)
	if not ok then warn("BotServer: raptor template: " .. tostring(err)) end
	local sc = StarterPlayer:FindFirstChild("StarterCharacter")
	if sc then
		local was = sc.Archivable
		sc.Archivable = true
		templates.TRex = sc:Clone()
		sc.Archivable = was
	end
end
if not templates.Raptor and not templates.TRex then
	script:SetAttribute("BotServerState", "noTemplates")
	return
end

-- bushes (static): bounding boxes
local bushes = {}
local bushFolder = island:FindFirstChild("Bushes")
if bushFolder then
	for _, m in ipairs(bushFolder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("DinoBush") == true then
			local cf, size = m:GetBoundingBox()
			table.insert(bushes, {cf = cf, half = size / 2 + Vector3.new(BUSH_MARGIN, BUSH_MARGIN, BUSH_MARGIN)})
		end
	end
end
local function inBush(pos)
	for _, b in ipairs(bushes) do
		local p = b.cf:PointToObjectSpace(pos)
		if math.abs(p.X) <= b.half.X and math.abs(p.Y) <= b.half.Y and math.abs(p.Z) <= b.half.Z then return true end
	end
	return false
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

-- the bot's snout point (front of the mouth; the server sees the rest pose)
local function snoutPoint(model)
	local head = model:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	if mouth and mouth:IsA("BasePart") then return mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0) end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or model:GetPivot().Position
end

-- distance from a point to a player character's nearest hitbox (HumanoidRootPart if it has none)
local function distanceTo(char, p)
	local best = math.huge
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, part in ipairs(hb:GetChildren()) do
			if part:IsA("BasePart") then best = math.min(best, (closestPoint(part, p) - p).Magnitude) end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if best == math.huge and hrp then best = (closestPoint(hrp, p) - p).Magnitude end
	return best
end

local function aliveChar(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if char and char.Parent and hum and hum.Health > 0 and hrp then return char, hum, hrp end
	return nil
end

local bots = {} -- list of bot records
local nextIndex = {}

local function groundY(hrp, hum)
	return hrp.Position.Y - (hrp.Size.Y / 2 + hum.HipHeight)
end

-- anchored roll between standing (k = 0) and lying on its side (k = 1)
local function rollCF(b, k)
	local hrp, hum = b.hrp, b.hum
	local look = flat(b.downFrom.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local stand = CFrame.lookAt(b.downFrom.Position, b.downFrom.Position + look.Unit)
	local ground = b.downGround
	local lyingPos = Vector3.new(stand.X, ground + b.cfg.halfWidth, stand.Z)
	local standPos = Vector3.new(stand.X, ground + hrp.Size.Y / 2 + hum.HipHeight, stand.Z)
	local pos = standPos:Lerp(lyingPos, k)
	return CFrame.new(pos) * stand.Rotation * CFrame.Angles(0, 0, math.pi / 2 * k)
end

local function animateRoll(b, from, to, duration, done)
	local t0 = os.clock()
	local token = {}
	b.rollToken = token
	task.spawn(function()
		while b.rollToken == token and b.model.Parent do
			local u = math.min(1, (os.clock() - t0) / duration)
			local s = u * u * (3 - 2 * u)
			b.hrp.CFrame = rollCF(b, from + (to - from) * s)
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if b.rollToken == token and done then done() end
	end)
end

local function lieDown(b)
	if b.down then return end
	b.down = true
	b.hum:Move(Vector3.zero)
	b.downFrom = b.hrp.CFrame
	b.downGround = groundY(b.hrp, b.hum)
	b.hrp.Anchored = true
	animateRoll(b, 0, 1, ROLL_TIME)
end

local function standUp(b)
	b.gettingUp = true
	animateRoll(b, 1, 0, GETUP_TIME, function()
		b.hrp.Anchored = false
		pcall(function() b.hrp:SetNetworkOwner(nil) end)
		b.down, b.gettingUp = false, false
	end)
end

local spawnBot -- forward

local function despawn(b)
	b.removed = true
	b.rollToken = nil
	if b.model then b.model:Destroy() end
	task.delay(get("BotRespawnTime"), function()
		if b.marker and b.marker.Parent then spawnBot(b.marker) end
	end)
end

function spawnBot(marker)
	local species = marker:GetAttribute("Species")
	local template = templates[species]
	local cfg = SPECIES[species]
	if not template or not cfg then return end
	nextIndex[species] = (nextIndex[species] or 0) + 1
	local model = template:Clone()
	model.Name = ("Bot_%s_%d"):format(species, nextIndex[species])
	for _, name in ipairs({"IdleAnimation", "StatusBadges"}) do
		local s = StarterPlayer.StarterCharacterScripts:FindFirstChild(name)
		if s then s:Clone().Parent = model end
	end
	model:SetAttribute("IsBot", true)
	model:SetAttribute("BotSpecies", species)
	model:SetAttribute("Bitable", true)
	model:SetAttribute("DummyMaxHealth", cfg.health)
	model:SetAttribute("DisplayName", cfg.displayName)
	model:SetAttribute("BiteEnabled", true)
	model:SetAttribute("BotBites", 0)
	model:SetAttribute("BotState", "idle")
	model:SetAttribute("BotTarget", "")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then model:Destroy() return end
	hrp.Anchored = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.AutoRotate = true
	hum.WalkSpeed = model:GetAttribute("MoveWalkSpeed") or 16
	-- stand at the marker, random facing
	local yaw = math.rad(math.random(0, 359))
	local base = marker.Position - Vector3.new(0, marker.Size.Y / 2, 0)
	local want = CFrame.new(base + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight + 0.2, 0)) * CFrame.Angles(0, yaw, 0)
	local offset = model:GetPivot():ToObjectSpace(hrp.CFrame)
	model:PivotTo(want * offset:Inverse())
	model:SetAttribute("BotSpawnedAt", workspace:GetServerTimeNow())
	model.Parent = botFolder
	pcall(function() hrp:SetNetworkOwner(nil) end)
	table.insert(bots, {model = model, hrp = hrp, hum = hum, species = species, cfg = cfg, marker = marker,
		home = flat(base), nextBite = 0, shown = {}})
	script:SetAttribute("BotCount", #botFolder:GetChildren())
end

local function show(b, k, v)
	if b.shown[k] ~= v then
		b.shown[k] = v
		b.model:SetAttribute(k, v)
	end
end

local function randomGoal(b)
	local r = get("BotWanderRadius")
	for _ = 1, 8 do
		local a = math.random() * 2 * math.pi
		local d = math.sqrt(math.random()) * r
		local p = b.home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if math.abs(p.X) <= wanderLimit and math.abs(p.Z) <= wanderLimit then return p end
	end
	return b.home
end

local function bite(b, player)
	local now = workspace:GetServerTimeNow()
	b.nextBite = os.clock() + b.cfg.biteCooldown
	b.model:SetAttribute("BiteStartedAt", now)
	show(b, "BotState", "bite")
	task.delay(BITE_HIT_DELAY, function()
		if b.removed or not b.model.Parent or b.down then return end
		local char, hum = aliveChar(player)
		if not char then return end
		if distanceTo(char, snoutPoint(b.model)) > b.cfg.biteReach + 1 then return end
		hum:TakeDamage(b.cfg.biteDamage)
		local at = workspace:GetServerTimeNow()
		b.model:SetAttribute("BiteHitAt", at)
		b.model:SetAttribute("BotBites", (b.model:GetAttribute("BotBites") or 0) + 1)
		char:SetAttribute("LastHitBy", b.model.Name)
		char:SetAttribute("LastHitDamage", b.cfg.biteDamage)
		char:SetAttribute("LastHitAt", at)
	end)
end

local function step(b)
	local model, hum, hrp = b.model, b.hum, b.hrp
	if b.removed then return end
	if not model.Parent then b.removed = true return end
	if model:GetAttribute("DummyState") == "ko" and not b.koAt then b.koAt = os.clock() end
	local ko = b.koAt ~= nil -- once knocked out it stays down (BiteTargetHealth's reset is ignored) until removed
	local pinned = model:GetAttribute("PinnedAt") ~= nil
	if ko or pinned then
		lieDown(b)
		b.target = nil
		show(b, "BotTarget", "")
		show(b, "BotState", pinned and "pinned" or "ko")
		if ko and not pinned and os.clock() - b.koAt >= get("BotKORemoveTime") then despawn(b) end
		return
	end
	if b.down then
		if not b.gettingUp then standUp(b) end
		show(b, "BotState", "getup")
		return
	end
	local now = os.clock()
	-- keep / lose the current target
	local target = b.target
	if target then
		local char, _, thrp = aliveChar(target)
		if not char or flat(thrp.Position - hrp.Position).Magnitude > get("BotLoseRange") then
			target = nil
		elseif char:GetAttribute("Hidden") == true then
			b.hiddenSince = b.hiddenSince or now
			if now - b.hiddenSince > get("BotHiddenLoseTime") then target = nil end
		else
			b.hiddenSince = nil
			b.lastSeen = thrp.Position
		end
	end
	-- look for one
	if not target then
		b.hiddenSince = nil
		local best, bestD = nil, get("BotSightRange")
		for _, player in ipairs(Players:GetPlayers()) do
			local char, _, thrp = aliveChar(player)
			if char and char:GetAttribute("Hidden") ~= true then
				local d = flat(thrp.Position - hrp.Position).Magnitude
				if d <= bestD then best, bestD = player, d end
			end
		end
		target = best
		if target then
			local _, _, thrp = aliveChar(target)
			b.lastSeen = thrp.Position
		end
	end
	b.target = target
	show(b, "BotTarget", target and target.Name or "")
	if target then
		b.goal, b.waitUntil = nil, nil
		local run = model:GetAttribute("MoveRunSpeed") or 28
		hum.WalkSpeed = run * get("BotChaseSpeedMul")
		local char = aliveChar(target)
		if b.hiddenSince then
			hum:MoveTo(b.lastSeen)
			if os.clock() >= b.nextBite - b.cfg.biteCooldown + 0.6 then show(b, "BotState", "search") end
		else
			local _, _, thrp = aliveChar(target)
			hum:MoveTo(thrp.Position)
			if now >= b.nextBite and char and distanceTo(char, snoutPoint(model)) <= b.cfg.biteReach then
				bite(b, target)
			elseif now >= b.nextBite - b.cfg.biteCooldown + 0.6 then
				show(b, "BotState", "chase")
			end
		end
		return
	end
	-- wander
	hum.WalkSpeed = model:GetAttribute("MoveWalkSpeed") or 16
	if b.goal and (flat(hrp.Position - b.goal).Magnitude < 5 or now > b.goalUntil) then
		b.goal = nil
		b.waitUntil = now + 1 + math.random() * 2
		hum:Move(Vector3.zero)
	end
	if not b.goal then
		if not b.waitUntil or now >= b.waitUntil then
			b.goal = randomGoal(b)
			b.goalUntil = now + 12
			b.waitUntil = nil
		else
			show(b, "BotState", "idle")
			return
		end
	end
	hum:MoveTo(b.goal)
	show(b, "BotState", "wander")
end

-- spawn one bot per marker
local spawnFolder = island:FindFirstChild("BotSpawns")
if spawnFolder then
	for _, marker in ipairs(spawnFolder:GetChildren()) do
		if marker:IsA("BasePart") then spawnBot(marker) end
	end
end
script:SetAttribute("BotServerState", "running")

while true do
	task.wait(TICK)
	-- who is hidden
	for _, player in ipairs(Players:GetPlayers()) do
		local char, _, thrp = aliveChar(player)
		if char then
			local hidden = inBush(thrp.Position)
			if char:GetAttribute("Hidden") ~= hidden then char:SetAttribute("Hidden", hidden) end
		end
	end
	-- bots
	for i = #bots, 1, -1 do
		local b = bots[i]
		local ok, err = pcall(step, b)
		if not ok then warn("BotServer step: " .. tostring(err)) end
		if b.removed then table.remove(bots, i) end
	end
	script:SetAttribute("BotCount", #botFolder:GetChildren())
end
