-- BotServer v1.3 (Dino Arcade) — TEST bot dinosaurs on the island (Workspace.DinoIsland, tools/island_install.luau).
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
-- v1.1: hiding spots are read from DinoIsland.TallGrass too (island 1.1 tall-grass patches, DinoBush = true), as well
--   as DinoIsland.Bushes.
-- v1.2 (user: unbitable raptor in front, raptor flung when the T-Rex jumps, T-Rex shake-off by tree ram / water):
--   * bite dip: a bot's bite swings its mouth down (0 .. 60 degrees about the neck, like BiteTest 1.3) to reach a low
--     target; the angle is written to BiteDip before BiteStartedAt (BitePose 1.1 lowers the head) and the hit check
--     uses the dipped snout. So the T-Rex bot can bite a raptor.
--   * fling guard: every Heartbeat a free (not anchored) bot's velocity is capped (horizontal 1.5 x MoveRunSpeed,
--     up 30, down 80 studs/s) and its spin to 10 rad/s, so a T-Rex landing on a raptor bot no longer launches it.
--     Diagnostic BotFlingClamps (times capped).
--   * raptor bot pounce: a raptor bot chasing a dino at least PounceSizeRatio (1.5) x its size, 8-22 studs away,
--     every BotPounceCooldown (6) s: PounceStartedAt (crouch BOT_POUNCE_WINDUP s), then a kinematic 70 studs/s lunge
--     (anchored, 2.7-stud arc) toward the target; a sphere at its snout touching one of the target's hitboxes latches
--     it there (up = surface normal, PounceTest's latch frame) and it rides that hitbox (part.CFrame * offset every
--     Heartbeat). Latched: PounceLatched / PounceLatchedAt / PounceMode "latch" / PounceLatchTarget / ObjectValue
--     PounceLatchPart (read by ShakeOffServer 1.0), damage 8 then 4 every 0.5 s to the target's Humanoid
--     (PounceHitDamage / PounceBiteAt: PounceFX 1.0 is cloned into raptor bots for the chomp + numbers). It leaps off
--     after BotLatchTime (6.7 s = a player's 100 stamina at 15/s), when the target dies, or when shaken off.
--   * shake-off (ShakeOffServer 1.0 sets ShakeOffReason / ShakeOffAt on the latched raptor): "water" = leap off;
--     "rammed" = drops off and is stunned until StunnedUntil (3 s), lying on its side like a pin, then gets up.
--     A bot with StunnedUntil in the future lies down and does nothing ("stunned").
--   * T-Rex bot shake run: while a player raptor is latched on it, the T-Rex bot runs (chase speed) for the nearest
--     tree trunk (aiming 6 studs past it, so it rams) or the nearest shore, whichever is closer ("shake").
--   Ground under a bot for lying down is found by a ray (dinos ignored), so a bot knocked off a T-Rex drops to it.
-- v1.3 (user: dedicated tree-ram button, raptors "tossed off a reasonable distance with the stun animation"):
--   * StunFX 1.0 is cloned into every bot (dizzy stars while StunnedUntil).
--   * T-Rex bot ram: while a player raptor is latched on it, when RamEnabled is true, BOT_RAM.cooldown s have passed
--     since its last ram and a tree trunk (Trunk1 / palm Trunk) is within BOT_RAM.range studs, it rams like a player:
--     RamTargetTree, RamCount + 1, RamStartedAt = server time (the ram pose on every client, IdleAnimation 1.19), stops
--     and turns to the trunk for BOT_RAM.windup s, then runs at it (Humanoid:Move, MoveRunSpeed x BOT_RAM.speedMul).
--     Contact (HumanoidRootPart or a blocking hitbox grown BOT_RAM.reach studs overlapping the tree's Trunk* / Root
--     parts, or blocked: slower than 0.3 x the charge speed after 0.25 s within 14 studs) -> RamImpactPoint,
--     RamImpactCount + 1, RamImpactAt, RamResult "hit", RamEndedAt (ShakeOffServer 1.1 knocks the raptors off),
--     a short push back and BOT_RAM.recoil s standing. No contact within BOT_RAM.maxCharge s -> RamResult "miss",
--     RamEndedAt. Cancelled (KO / pinned / stunned / tree gone) -> RamResult "cancel", RamEndedAt. Otherwise
--     (cooldown, no tree in range) the v1.2 shake run. BotState "ram"; BotRamPhase "windup" / "charge" / "recoil" /
--     "none".
--   * Raptor bot tossed: a "rammed" release with StunTossFrom / StunTossDistance / StunTossAt (ShakeOffServer 1.1) flings
--     the bot like StunClient 1.1: anchored, TOSS_TIME s along a TOSS_HEIGHT arc to StunTossDistance studs farther
--     from StunTossFrom (inside TOSS_LIMIT), facing the tree, one backward flip and a roll onto its side as it lands;
--     it then lies there until StunnedUntil and gets up as before. BotState "tossed" in the air, then "stunned".
--     Diagnostic BotTossDist (studs, 0.1 steps). Without toss attributes: the v1.2 drop.
--   * Latched bots do not collide: while a raptor bot is latched (anchored, moved onto the target every Heartbeat) its
--     colliding parts have CanCollide = false, put back when the latch ends. Before, the anchored body sat in the
--     target's way and a T-Rex player with a raptor bot on it could barely move (a 42-stud ram charge took 2.7 s
--     instead of ~0.8 s). Diagnostic BotLatchNoCollide (parts switched off for the current latch, 0 after it).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local VERSION = "1.3"
local TICK = 0.1
local BITE_HIT_DELAY = 0.25
local ROLL_TIME = 0.4
local GETUP_TIME = 0.5
local BUSH_MARGIN = 0.5
local DEFAULTS = {BotSightRange = 60, BotLoseRange = 90, BotHiddenLoseTime = 2, BotWanderRadius = 60,
	BotChaseSpeedMul = 0.9, BotRespawnTime = 10, BotKORemoveTime = 2.5}
local BOT_POUNCE_WINDUP = 0.1 -- v1.2
local BOT_POUNCE_SPEED = 70   -- v1.2: studs/s
local BOT_POUNCE_RANGE = {8, 22} -- v1.2: studs (flat) to the target's HumanoidRootPart
local BOT_POUNCE_ARC = 2.7    -- v1.2: studs the lunge rises
local LATCH_STANDOFF = 2.4    -- v1.2
local DIP_MAX, DIP_STEP = 60, 5 -- v1.2
DEFAULTS.BotPounceCooldown = 6 -- v1.2
DEFAULTS.BotLatchTime = 6.7    -- v1.2
local BOT_RAM = {windup = 0.4, range = 60, cooldown = 6, speedMul = 1.15, maxCharge = 3.5, reach = 1.5,
	recoil = 0.45, push = 12} -- v1.3 (= RamPose 1.0 / RamTest 1.0)
local TOSS_TIME, TOSS_HEIGHT, TOSS_LIMIT, TOSS_FRESH = 0.6, 6, 230, 1 -- v1.3 (= StunClient 1.1)
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
for _, folderName in ipairs({"Bushes", "TallGrass"}) do -- v1.1: + TallGrass
	local bushFolder = island:FindFirstChild(folderName)
	if bushFolder then
		for _, m in ipairs(bushFolder:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("DinoBush") == true then
				local cf, size = m:GetBoundingBox()
				table.insert(bushes, {cf = cf, half = size / 2 + Vector3.new(BUSH_MARGIN, BUSH_MARGIN, BUSH_MARGIN)})
			end
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

local groundParams = RaycastParams.new() -- v1.2: ground below a bot (dinos and grass ignored)
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(hrp, hum)
	local ignore = {botFolder}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	local tg = island:FindFirstChild("TallGrass")
	if tg then table.insert(ignore, tg) end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -80, 0), groundParams)
	if hit then return hit.Position.Y end
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
local startRam -- v1.3: forward

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
	for _, name in ipairs({"IdleAnimation", "StatusBadges", "PounceFX", "StunFX"}) do -- v1.2: + PounceFX; v1.3: + StunFX
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
	local lv = Instance.new("ObjectValue") -- v1.2: what it is latched onto (ShakeOffServer)
	lv.Name = "PounceLatchPart"
	lv.Parent = model
	table.insert(bots, {model = model, hrp = hrp, hum = hum, species = species, cfg = cfg, marker = marker,
		home = flat(base), nextBite = 0, nextPounce = 0, shown = {}})
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

-- v1.2: snout point swung down by dip degrees about the neck (rest pose)
local function dippedSnout(model, dip)
	local p = snoutPoint(model)
	if dip <= 0 then return p end
	local neck = model:FindFirstChild("Neck")
	local pivotPart = neck and neck:FindFirstChild("Root")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not (pivotPart and hrp) then return p end
	local fwd = flat(hrp.CFrame.LookVector)
	if fwd.Magnitude < 1e-3 then return p end
	local rot = CFrame.fromAxisAngle(fwd.Unit:Cross(Vector3.yAxis), -math.rad(dip))
	return pivotPart.Position + rot:VectorToWorldSpace(p - pivotPart.Position)
end

-- v1.2: smallest dip (degrees) that brings the snout within reach of the target; nil when none does
local function dipFor(b, char)
	for deg = 0, DIP_MAX, DIP_STEP do
		if distanceTo(char, dippedSnout(b.model, deg)) <= b.cfg.biteReach then return deg end
	end
	return nil
end

local function bite(b, player, dip)
	local now = workspace:GetServerTimeNow()
	dip = dip or 0
	b.nextBite = os.clock() + b.cfg.biteCooldown
	b.model:SetAttribute("BiteDip", dip) -- v1.2: before the start stamp
	b.model:SetAttribute("BiteStartedAt", now)
	show(b, "BotState", "bite")
	task.delay(BITE_HIT_DELAY, function()
		if b.removed or not b.model.Parent or b.down then return end
		local char, hum = aliveChar(player)
		if not char then return end
		if distanceTo(char, dippedSnout(b.model, dip)) > b.cfg.biteReach + 1 then return end -- v1.2: dipped
		hum:TakeDamage(b.cfg.biteDamage)
		local at = workspace:GetServerTimeNow()
		b.model:SetAttribute("BiteHitAt", at)
		b.model:SetAttribute("BotBites", (b.model:GetAttribute("BotBites") or 0) + 1)
		char:SetAttribute("LastHitBy", b.model.Name)
		char:SetAttribute("LastHitDamage", b.cfg.biteDamage)
		char:SetAttribute("LastHitAt", at)
	end)
end

-- v1.2: trunks (ram goals) and shore goal for the T-Rex bot's shake run
local trunks = {}
do
	local trees = island:FindFirstChild("Trees")
	if trees then
		for _, d in ipairs(trees:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "Trunk1" or (d.Name == "Trunk" and d.Parent.Name:find("^Palm"))) then
				table.insert(trunks, d)
			end
		end
	end
end
local function shakeGoal(b)
	local pos = flat(b.hrp.Position)
	local best, bestD = nil, math.huge
	for _, t in ipairs(trunks) do
		if t.Parent and t.Parent.Name:find("^JungleTree") or t.Name == "Trunk" then
			local d = (flat(t.Position) - pos).Magnitude
			if d < bestD then best, bestD = t, d end
		end
	end
	local out = pos.Magnitude > 1 and pos.Unit or Vector3.new(0, 0, 1)
	local shore = out * 222
	local shoreD = (shore - pos).Magnitude
	if best and bestD < shoreD then
		local tp = flat(best.Position)
		local dir = (tp - pos).Magnitude > 1 and (tp - pos).Unit or out
		return tp + dir * 6, "tree"
	end
	return shore, "water"
end

-- v1.2: is a player raptor latched onto this bot?
local function latchedByPlayer(b)
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local v = c and c:FindFirstChild("PounceLatchPart")
		if c and c:GetAttribute("PounceLatched") == true and v and v.Value and v.Value:IsDescendantOf(b.model) then return true end
	end
	return false
end

-- v1.2: raptor bot pounce
local function canPounce(b, char)
	if b.species ~= "Raptor" or os.clock() < b.nextPounce then return false end
	local thrp = char:FindFirstChild("HumanoidRootPart")
	if not thrp or not char:FindFirstChild("Hitboxes") then return false end
	if char:GetExtentsSize().Magnitude < b.model:GetExtentsSize().Magnitude * (b.model:GetAttribute("PounceSizeRatio") or 1.5) then return false end
	local d = flat(thrp.Position - b.hrp.Position).Magnitude
	return d >= BOT_POUNCE_RANGE[1] and d <= BOT_POUNCE_RANGE[2]
end

local function startPounce(b, char)
	b.pounce = {phase = "windup", t0 = os.clock(), char = char}
	b.hum:Move(Vector3.zero)
	b.model:SetAttribute("PounceStartedAt", workspace:GetServerTimeNow())
	show(b, "BotState", "pounce")
end

-- v1.3: T-Rex bot ram
local function treeParts(tree)
	local list = {}
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name:find("^Trunk") or d.Name == "Root") then table.insert(list, d) end
	end
	return list
end

startRam = function(b)
	local model, hrp = b.model, b.hrp
	if model:GetAttribute("RamEnabled") ~= true or os.clock() < (b.nextRam or 0) then return false end
	local pos = flat(hrp.Position)
	local best, bestD = nil, BOT_RAM.range
	for _, t in ipairs(trunks) do
		if t.Parent then
			local d = (flat(t.Position) - pos).Magnitude
			if d <= bestD then best, bestD = t, d end
		end
	end
	if not best then return false end
	local look = flat(hrp.CFrame.LookVector)
	b.ram = {phase = "windup", t0 = os.clock(), trunk = best, parts = treeParts(best.Parent),
		face = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)}
	b.nextRam = os.clock() + BOT_RAM.cooldown
	b.hum:Move(Vector3.zero)
	model:SetAttribute("RamTargetTree", best.Parent.Name)
	model:SetAttribute("RamCount", (model:GetAttribute("RamCount") or 0) + 1)
	model:SetAttribute("RamStartedAt", workspace:GetServerTimeNow())
	show(b, "BotState", "ram")
	show(b, "BotRamPhase", "windup")
	return true
end

local function ramTouching(b)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = b.ram.parts
	local parts = {b.hrp}
	local hb = b.model:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxBlocks") == true then table.insert(parts, p) end
		end
	end
	local r = BOT_RAM.reach
	for _, p in ipairs(parts) do
		if #workspace:GetPartBoundsInBox(p.CFrame, p.Size + Vector3.new(r, r, r) * 2, op) > 0 then return true end
	end
	return false
end

local function endRam(b, result)
	local model = b.model
	local now = workspace:GetServerTimeNow()
	if result == "hit" then
		local tp = b.ram.trunk.Position
		model:SetAttribute("RamImpactPoint", Vector3.new(tp.X, b.hrp.Position.Y, tp.Z))
		model:SetAttribute("RamImpactCount", (model:GetAttribute("RamImpactCount") or 0) + 1)
		model:SetAttribute("RamImpactAt", now)
	end
	model:SetAttribute("RamResult", result)
	model:SetAttribute("RamEndedAt", now)
end

-- v1.3: raptor bot flung away from the tree (like StunClient 1.1); returns true when tossed
local function tossOff(b)
	local model, hrp = b.model, b.hrp
	local at, from, dist = model:GetAttribute("StunTossAt"), model:GetAttribute("StunTossFrom"), model:GetAttribute("StunTossDistance")
	if typeof(at) ~= "number" or typeof(from) ~= "Vector3" or typeof(dist) ~= "number"
		or math.abs(workspace:GetServerTimeNow() - at) > TOSS_FRESH then return false end
	local start = hrp.Position
	local away = flat(start - from)
	if away.Magnitude < 0.5 then away = -flat(hrp.CFrame.LookVector) end
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local land = flat(start) + away * dist
	land = Vector3.new(math.clamp(land.X, -TOSS_LIMIT, TOSS_LIMIT), 0, math.clamp(land.Z, -TOSS_LIMIT, TOSS_LIMIT))
	local ignore = {botFolder}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	local tg = island:FindFirstChild("TallGrass")
	if tg then table.insert(ignore, tg) end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(land.X, start.Y + 40, land.Z), Vector3.new(0, -140, 0), groundParams)
	local ground = hit and hit.Position.Y or (start.Y - (hrp.Size.Y / 2 + b.hum.HipHeight))
	local landPos = Vector3.new(land.X, ground + b.cfg.halfWidth, land.Z)
	local rot = CFrame.lookAt(Vector3.zero, -away)
	b.down = true
	b.hum:Move(Vector3.zero)
	b.downFrom = CFrame.new(Vector3.new(land.X, ground, land.Z)) * rot
	b.downGround = ground
	hrp.Anchored = true
	show(b, "BotTossDist", math.floor((flat(landPos) - flat(start)).Magnitude * 10 + 0.5) / 10)
	show(b, "BotState", "tossed")
	local t0 = os.clock()
	local token = {}
	b.rollToken = token
	task.spawn(function()
		while b.rollToken == token and model.Parent do
			local u = math.min(1, (os.clock() - t0) / TOSS_TIME)
			local e = u * u * (3 - 2 * u)
			local pos = start:Lerp(landPos, u) + Vector3.new(0, 4 * TOSS_HEIGHT * u * (1 - u), 0)
			hrp.CFrame = CFrame.new(pos) * rot * CFrame.Angles(0, 0, math.pi / 2 * e) * CFrame.Angles(2 * math.pi * e, 0, 0)
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if b.rollToken == token and model.Parent then
			hrp.CFrame = rollCF(b, 1)
			show(b, "BotState", "stunned")
		end
	end)
	return true
end

local function step(b)
	local model, hum, hrp = b.model, b.hum, b.hrp
	if b.removed then return end
	if not model.Parent then b.removed = true return end
	if b.pounce or b.latch then return end -- v1.2: the Heartbeat drives a pounce / latch
	if b.ram then return end -- v1.3: the Heartbeat drives a ram
	if model:GetAttribute("DummyState") == "ko" and not b.koAt then b.koAt = os.clock() end
	local ko = b.koAt ~= nil -- once knocked out it stays down (BiteTargetHealth's reset is ignored) until removed
	local pinned = model:GetAttribute("PinnedAt") ~= nil
	local stunned = (model:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() -- v1.2
	if ko or pinned or stunned then
		lieDown(b)
		b.target = nil
		show(b, "BotTarget", "")
		show(b, "BotState", pinned and "pinned" or (ko and "ko" or "stunned"))
		if ko and not pinned and os.clock() - b.koAt >= get("BotKORemoveTime") then despawn(b) end
		return
	end
	if b.down then
		if not b.gettingUp then standUp(b) end
		show(b, "BotState", "getup")
		return
	end
	local now = os.clock()
	-- v1.2: T-Rex bot with a player raptor on it runs for a tree or the water
	if b.species == "TRex" and latchedByPlayer(b) then
		if startRam(b) then return end -- v1.3: dedicated ram when a tree is in range and it is ready
		local goal, kind = shakeGoal(b)
		hum.WalkSpeed = (model:GetAttribute("MoveRunSpeed") or 28) * get("BotChaseSpeedMul")
		hum:MoveTo(goal)
		b.goal, b.waitUntil = nil, nil
		show(b, "BotState", "shake")
		show(b, "BotShakeGoal", kind)
		return
	end
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
			local dip = (now >= b.nextBite and char) and dipFor(b, char) or nil -- v1.2: dipped bite
			if dip then
				bite(b, target, dip)
			elseif char and canPounce(b, char) then -- v1.2
				startPounce(b, char)
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

-- v1.2: latch release (leap off, or drop + stun)
local function endLatch(b, reason)
	local l = b.latch
	b.latch = nil
	if b.noCollide then -- v1.3: collide again
		for _, part in ipairs(b.noCollide) do
			if part.Parent then part.CanCollide = true end
		end
		b.noCollide = nil
		show(b, "BotLatchNoCollide", 0)
	end
	local model, hrp = b.model, b.hrp
	if model.Parent then
		model.PounceLatchPart.Value = nil
		model:SetAttribute("PounceLatched", false)
		model:SetAttribute("PounceReleasedAt", workspace:GetServerTimeNow())
		model:SetAttribute("PounceReleaseReason", reason)
	end
	b.nextPounce = os.clock() + get("BotPounceCooldown")
	if reason == "rammed" and tossOff(b) then return end -- v1.3: flung away from the tree, then lies stunned
	if reason == "rammed" then
		-- stunned: drop to the ground and lie on its side (step() keeps it down until StunnedUntil)
		b.down = false
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + (flat(hrp.CFrame.LookVector).Magnitude > 1e-3 and flat(hrp.CFrame.LookVector).Unit or Vector3.zAxis))
		lieDown(b)
		show(b, "BotState", "stunned")
		return
	end
	local up = l and (l.part.CFrame * l.offset).UpVector or Vector3.yAxis
	local away = flat(up).Magnitude > 1e-3 and flat(up).Unit or -flat(hrp.CFrame.LookVector).Unit
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + away)
	hrp.Anchored = false
	pcall(function() hrp:SetNetworkOwner(nil) end)
	hrp.AssemblyLinearVelocity = away * 30 + Vector3.new(0, 35, 0)
	show(b, "BotState", "leapoff")
end

local function latchOn(b, part, front, dir)
	local cp = closestPoint(part, front)
	local n = front - cp
	n = n.Magnitude > 1e-3 and n.Unit or -dir
	local pos = cp + n * LATCH_STANDOFF
	local f = Vector3.yAxis - n * n.Y
	if f.Magnitude < 0.3 then f = dir end
	local cf = CFrame.lookAt(pos, pos + f.Unit, n)
	local now = workspace:GetServerTimeNow()
	local char = b.pounce.char
	b.pounce = nil
	b.latch = {part = part, offset = part.CFrame:ToObjectSpace(cf), char = char, at = now, nextTick = now + 0.5,
		endAt = now + get("BotLatchTime")}
	local model = b.model
	model.PounceLatchPart.Value = part
	model:SetAttribute("PounceMode", "latch")
	model:SetAttribute("PounceLatchTarget", char.Name)
	model:SetAttribute("PounceLatchedAt", now)
	model:SetAttribute("PounceLatched", true)
	b.hrp.CFrame = cf
	b.noCollide = {} -- v1.3: out of the target's way while riding it
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			d.CanCollide = false
			table.insert(b.noCollide, d)
		end
	end
	show(b, "BotLatchNoCollide", #b.noCollide)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:TakeDamage(8) end
	model:SetAttribute("PounceHitDamage", 8)
	model:SetAttribute("PounceBiteAt", now)
	char:SetAttribute("LastHitBy", model.Name)
	char:SetAttribute("LastHitDamage", 8)
	char:SetAttribute("LastHitAt", now)
	show(b, "BotState", "latched")
end

local flingClamps = 0
RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for _, b in ipairs(bots) do
		local model, hrp = b.model, b.hrp
		if b.removed or not model.Parent then continue end
		local ok, err = pcall(function()
			-- fling guard (free bots only)
			if not hrp.Anchored and not b.pounce and not b.latch then
				local v = hrp.AssemblyLinearVelocity
				local h = flat(v)
				local maxH = (model:GetAttribute("MoveRunSpeed") or 28) * 1.5
				local clamped = false
				if h.Magnitude > maxH then h = h.Unit * maxH; clamped = true end
				local vy = v.Y
				if vy > 30 then vy = 30; clamped = true elseif vy < -80 then vy = -80; clamped = true end
				if clamped then
					hrp.AssemblyLinearVelocity = Vector3.new(h.X, vy, h.Z)
					flingClamps += 1
					model:SetAttribute("BotFlingClamps", (model:GetAttribute("BotFlingClamps") or 0) + 1)
				end
				local w = hrp.AssemblyAngularVelocity
				if w.Magnitude > 10 then hrp.AssemblyAngularVelocity = w.Unit * 10 end
			end
			-- v1.3: T-Rex bot ram
			local r = b.ram
			if r then
				local hum = b.hum
				local stunned = (model:GetAttribute("StunnedUntil") or 0) > now
				if model:GetAttribute("DummyState") == "ko" or model:GetAttribute("PinnedAt") ~= nil or stunned
					or hum.Health <= 0 or not r.trunk.Parent then
					if r.phase ~= "recoil" then endRam(b, "cancel") end
					b.ram = nil
					show(b, "BotRamPhase", "none")
					return
				end
				local d = flat(r.trunk.Position - hrp.Position)
				local dir = d.Magnitude > 1e-3 and d.Unit or r.face
				local t = os.clock() - r.t0
				if r.phase == "windup" then
					hum:Move(Vector3.zero)
					local f = r.face:Lerp(dir, math.min(1, dt * 12))
					r.face = f.Magnitude > 1e-3 and f.Unit or dir
					hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + r.face)
					if t >= BOT_RAM.windup then
						r.phase, r.t0, r.speed = "charge", os.clock(), (model:GetAttribute("MoveRunSpeed") or 28) * BOT_RAM.speedMul
						hum.WalkSpeed = r.speed
						show(b, "BotRamPhase", "charge")
					end
				elseif r.phase == "charge" then
					hum.WalkSpeed = r.speed
					hum:Move(dir)
					local v = flat(hrp.AssemblyLinearVelocity).Magnitude
					local hitIt = ramTouching(b) or (t > 0.25 and v < r.speed * 0.3 and d.Magnitude < 14)
					if hitIt then
						endRam(b, "hit")
						r.phase, r.t0 = "recoil", os.clock()
						hum:Move(Vector3.zero)
						hrp.AssemblyLinearVelocity = -dir * BOT_RAM.push + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
						show(b, "BotRamPhase", "recoil")
					elseif t > BOT_RAM.maxCharge then
						endRam(b, "miss")
						b.ram = nil
						show(b, "BotRamPhase", "none")
					end
				else
					hum:Move(Vector3.zero)
					if t >= BOT_RAM.recoil then
						b.ram = nil
						show(b, "BotRamPhase", "none")
					end
				end
				return
			end
			-- pounce
			local p = b.pounce
			if p then
				local char = p.char
				local thrp = char and char.Parent and char:FindFirstChild("HumanoidRootPart")
				local thum = char and char:FindFirstChildOfClass("Humanoid")
				if not thrp or not thum or thum.Health <= 0 or model:GetAttribute("DummyState") == "ko" or model:GetAttribute("PinnedAt") ~= nil then
					b.pounce = nil
					hrp.Anchored = false
					b.nextPounce = os.clock() + get("BotPounceCooldown")
					return
				end
				local t = os.clock() - p.t0
				if p.phase == "windup" then
					if t >= BOT_POUNCE_WINDUP then
						local from = hrp.Position
						local to = flat(thrp.Position) + Vector3.new(0, from.Y, 0)
						local d = flat(to - from)
						local len = math.min(d.Magnitude + 4, BOT_POUNCE_RANGE[2] + 4)
						p.dir = d.Magnitude > 1e-3 and d.Unit or flat(hrp.CFrame.LookVector).Unit
						p.from, p.len, p.dur, p.t1 = from, len, len / BOT_POUNCE_SPEED, os.clock()
						p.phase = "lunge"
						p.targets = {}
						for _, hb in ipairs(char.Hitboxes:GetChildren()) do if hb:IsA("BasePart") then table.insert(p.targets, hb) end end
						hrp.Anchored = true
					end
				else
					local u = math.min(1, (os.clock() - p.t1) / p.dur)
					local pos = p.from + p.dir * (p.len * u) + Vector3.new(0, 4 * BOT_POUNCE_ARC * u * (1 - u), 0)
					hrp.CFrame = CFrame.lookAt(pos, pos + p.dir)
					local front = pos + p.dir * (model:GetExtentsSize().Magnitude * 0.3)
					local op = OverlapParams.new()
					op.FilterType = Enum.RaycastFilterType.Include
					op.FilterDescendantsInstances = p.targets
					local touching = workspace:GetPartBoundsInRadius(front, 2.2, op)
					if #touching == 0 then touching = workspace:GetPartBoundsInRadius(pos, 2.6, op) end
					if #touching > 0 then
						latchOn(b, touching[1], front, p.dir)
					elseif u >= 1 then
						b.pounce = nil
						hrp.Anchored = false
						pcall(function() hrp:SetNetworkOwner(nil) end)
						b.nextPounce = os.clock() + get("BotPounceCooldown")
						show(b, "BotState", "chase")
					end
				end
				return
			end
			-- latched
			local l = b.latch
			if l then
				local char = l.char
				local thum = char and char:FindFirstChildOfClass("Humanoid")
				local shakeAt = model:GetAttribute("ShakeOffAt")
				if typeof(shakeAt) == "number" and shakeAt >= l.at then
					endLatch(b, model:GetAttribute("ShakeOffReason") or "shaken")
				elseif not (char and char.Parent and l.part.Parent and thum and thum.Health > 0) then
					endLatch(b, "gone")
				elseif model:GetAttribute("DummyState") == "ko" then
					endLatch(b, "ko")
				elseif now >= l.endAt then
					endLatch(b, "tired")
				else
					hrp.CFrame = l.part.CFrame * l.offset
					if now >= l.nextTick then
						l.nextTick += 0.5
						thum:TakeDamage(4)
						model:SetAttribute("PounceHitDamage", 4)
						model:SetAttribute("PounceBiteAt", now)
						char:SetAttribute("LastHitBy", model.Name)
						char:SetAttribute("LastHitDamage", 4)
						char:SetAttribute("LastHitAt", now)
					end
				end
			end
		end)
		if not ok then warn("BotServer heartbeat: " .. tostring(err)) end
	end
end)

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
