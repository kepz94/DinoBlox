-- BotServer v1.4 (Dino Arcade) — TEST bot dinosaurs on the island (Workspace.DinoIsland, tools/island_install.luau).
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
-- v1.4 (user: "there should be a pack of raptors ... traveling in groups of 3. they should try to avoid the t-rex
--   unless attacked then they gang up on him", raptors "would prefer side swipes or latches not head", "they keep
--   jumping into the water try to make this avoidable"; answers: 2 packs = 6 raptors; only the bitten raptor's pack,
--   20 s; keep ~40 studs from any T-Rex, raptor players attacked as before; flank + latch mix):
--   * Packs (script attribute BotPacksEnabled, default true; false = v1.3, one raptor per marker): PACK_COUNT packs
--     of PACK_SIZE raptors. Raptor markers sorted by name; pack k spawns at the k-th, its members on a
--     PACK_SPAWN_RING-stud ring around it (slot 1..PACK_SIZE); raptor markers after the last pack get no bot (marker
--     attribute BotPackUnused = true, false on the used ones). The T-Rex marker is unchanged. A member that is removed
--     respawns at its pack's marker in its own slot after BotRespawnTime. Bot attributes BotPack ("Pack1" ...),
--     BotPackSlot, BotPackRole ("leader" / "follower"; leader = the lowest slot that is up: not removed, KO'd, lying
--     down, pouncing or latched). Script attribute BotPacks (packs spawned).
--   * Travel together: the leader wanders as before; each other up member walks to its formation spot behind the
--     leader (follower 1 back-left, follower 2 back-right: FORMATION studs back, 0.7 x FORMATION to the side, turned
--     with the leader) at 1.15 x MoveWalkSpeed, or MoveRunSpeed when farther than CATCH_UP studs; within FOLLOW_STOP
--     studs it stands ("idle"). BotState "follow". A follower with a chase target chases it as before.
--   * Avoid the T-Rex: a pack member with a T-Rex (a player character with Species "TRex" that is not hidden, or a
--     T-Rex bot that is not KO'd) within AVOID_RADIUS studs (flat; once avoiding, until it is farther than
--     AVOID_RADIUS + AVOID_HOLD, so it does not stop and turn back at the edge) runs (MoveRunSpeed) AVOID_FLEE studs away from it:
--     of the directions 0 / +-45 / +-90 / +-135 degrees off straight away (each cut short of water), the goal that
--     ends farthest from it. BotState "avoid", BotAvoiding (its name, "" otherwise), BotTarget "". Pack members never
--     pick or keep a T-Rex player as a chase target; raptor players are chased and bitten as before. A pack leader's
--     wander goal is redrawn when it lies within AVOID_RADIUS + AVOID_HOLD of a T-Rex (diagnostic BotWanderRexSkips).
--   * Grudge: when a T-Rex player's BiteHitAt changes (BiteServer, set last on a landed bite) and its BiteHitTarget is
--     a pack member (within GRUDGE_MATCH s of server time), that pack only takes a grudge against him for GRUDGE_TIME
--     (20) s; every new bite on a member restarts it, the newest biter replaces an older one. Ends early when he dies
--     or leaves. Member attributes BotPackGrudge (player name / ""), BotPackGrudgeUntil (server time / 0).
--   * Gang up (grudge; never the head: hitbox segments Head / Neck / Jaw are left out of every reach, hit and latch
--     test): run (MoveRunSpeed x BotChaseSpeedMul) to the member's flank spot - slot 1 left / slot 2 right of his
--     Torso hitbox (FLANK_SIDE studs out from its side), slot 3 behind his Tail1 hitbox (FLANK_REAR studs back);
--     BotState "flank". Any time its snout is in reach of an allowed hitbox and the bite cooldown is over: a side bite
--     (BotState "bite"; it keeps on him for BITE_HIT_DELAY s), then it dashes RETREAT_DIST studs straight out from
--     him for RETREAT_TIME s ("retreat") and goes back to the flank spot. At the spot (within FLANK_NEAR studs, he is
--     not in water): pounce when its pounce cooldown is over, fewer than LATCH_MAX members of its pack are latched on
--     him or pouncing at him and his nearest Torso / Tail1 / Tail2 point (seen from POUNCE_AIM_UP studs above it) is
--     within BOT_POUNCE_RANGE[2] studs: the lunge flies (3D) at that point and can only latch onto his Torso /
--     Tail1-5 hitboxes (LATCH_SEGMENTS: back, flank, tail; it passes through the legs); otherwise, when the bite cooldown is over, it darts in ("dart") at his
--     nearest allowed hitbox for up to DART_MAX s.
--   * Water (raptor bots; script attribute BotAvoidWater, default true): a spot is water when the ground ray there
--     (DinoIsland.Ground only, cached per WATER_CELL-stud cell) hits "Shallows" / "Seabed", ends below WATER_Y (-0.8,
--     the water surface) or hits nothing. Every goal (wander, follow, flee, chase, search, flank, dart, retreat) is
--     cut at the last dry sample (WATER_STEP studs apart, SHORE_MARGIN samples back) before the first water on the
--     straight way there; a wander goal whose way crosses water is redrawn (up to 8 times, then the cut way home;
--     diagnostic BotWanderWetSkips). A chase / follow / flank / dart whose way is cut waits there (BotState
--     "shore"); when the cut is within DETOUR_NEAR studs of the bot and the goal itself is dry, it takes a dry
--     DETOUR_STEP-stud step instead: on one side, the smallest turn off the straight way (DETOUR_TURN .. 180
--     degrees) that is dry, so it follows the shore around a lake; the side (the smaller turn) is kept DETOUR_KEEP s
--     after each step (BotState "detour", BotDetourSide 1 / -1). No
--     pounce at a target in water or whose lunge would end in water. A leap off a latch goes the first way (0 / +-45
--     ... 180 degrees off the v1.3 way) whose LEAP_LAND-stud landing spot and way are dry. A raptor bot standing in
--     water runs to the nearest dry spot ("leaveWater"). Diagnostic BotWaterAvoids (times BotState turned "shore" /
--     "detour" / "leaveWater").
--   * Ram toss distance (user: "when i ram into a tree when latched the raptors fly so far. lets keep it nearby
--     relevant to the player"): the toss landing point was clamped to |X|, |Z| <= TOSS_LIMIT (230, the v1.0 island);
--     on the current island (IslandHalfSize 940) that dragged a raptor tossed farther out up to hundreds of studs
--     toward the middle. The clamp now uses the island's IslandWanderLimit (TOSS_LIMIT only when it is missing), so
--     the raptor lands StunTossDistance (15) studs from where it was, away from the tree. A raptor bot whose landing
--     point is water lands at the last dry point on the way (dryLine).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local VERSION = "1.4"
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
-- v1.4: raptor packs, T-Rex avoidance, grudge, flank attack, water
DEFAULTS.BotPacksEnabled = true
DEFAULTS.BotAvoidWater = true
local PACK_COUNT, PACK_SIZE, PACK_SPAWN_RING = 2, 3, 6
local FORMATION, CATCH_UP, FOLLOW_STOP = 7, 20, 3
local AVOID_RADIUS, AVOID_FLEE, AVOID_HOLD = 40, 35, 15
local GRUDGE_TIME, GRUDGE_MATCH = 20, 1
local FLANK_SIDE, FLANK_REAR, FLANK_NEAR = 7.5, 6, 6
local LATCH_MAX, POUNCE_AIM_UP = 2, 4
local DART_MAX = 2.5
local RETREAT_DIST, RETREAT_TIME = 10, 0.9
local NO_HEAD = {Head = true, Neck = true, Jaw = true} -- hitbox segments raptors leave alone on a T-Rex
local AIM_SEGMENTS = {Torso = true, Tail1 = true, Tail2 = true} -- what a flank pounce flies at
local LATCH_SEGMENTS = {Torso = true, Tail1 = true, Tail2 = true, Tail3 = true, Tail4 = true, Tail5 = true} -- what it can latch onto
local WATER_Y, WATER_CELL, WATER_STEP, SHORE_MARGIN = -0.8, 2, 4, 1
local LEAP_LAND = 12
local DETOUR_STEP, DETOUR_NEAR, DETOUR_TURN, DETOUR_KEEP = 20, 6, 20, 3
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
local function distanceTo(char, p, skip) -- v1.4: skip = set of HitboxSegment names left out
	local best = math.huge
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, part in ipairs(hb:GetChildren()) do
			if part:IsA("BasePart") and not (skip and skip[part:GetAttribute("HitboxSegment")]) then
				best = math.min(best, (closestPoint(part, p) - p).Magnitude)
			end
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

-- v1.4: water --------------------------------------------------------------------------------------------------------
local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.FilterDescendantsInstances = {island:FindFirstChild("Ground") or island}
local waterCache = {}
local function groundHit(x, z)
	return workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), waterParams)
end
local function isWater(p)
	local cx, cz = math.floor(p.X / WATER_CELL), math.floor(p.Z / WATER_CELL)
	local key = cx .. ":" .. cz
	local v = waterCache[key]
	if v == nil then
		local hit = groundHit((cx + 0.5) * WATER_CELL, (cz + 0.5) * WATER_CELL)
		v = (hit == nil) or hit.Instance.Name == "Shallows" or hit.Instance.Name == "Seabed" or hit.Position.Y < WATER_Y
		waterCache[key] = v
	end
	return v
end
-- (point, clear): `to` and true when the straight way from -> to is dry; else the dry sample SHORE_MARGIN samples
-- before the first water (flat) and false
local function dryLine(from, to)
	local a = flat(from)
	local d = flat(to) - a
	local len = d.Magnitude
	if len < 1e-3 then return to, not isWater(to) end
	local dir = d / len
	local kept = {a}
	local s = 0
	while s < len do
		s = math.min(len, s + WATER_STEP)
		local q = a + dir * s
		if isWater(q) then return kept[math.max(1, #kept - SHORE_MARGIN)], false end
		table.insert(kept, q)
	end
	return to, true
end
local function nearestDry(p)
	for r = WATER_STEP, 120, WATER_STEP do
		for i = 0, 15 do
			local a = i * math.pi / 8
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local q = flat(p) + dir * r
			if not isWater(q) then return q + dir * WATER_STEP end
		end
	end
	return nil
end
local function avoidsWater(b)
	return b.species == "Raptor" and get("BotAvoidWater") ~= false
end
local function dryLeapDir(pos, away)
	for _, deg in ipairs({0, 45, -45, 90, -90, 135, -135, 180}) do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(away)
		local q = flat(pos) + dir * LEAP_LAND
		local _, clear = dryLine(pos, q)
		if clear then return dir end
	end
	local q = nearestDry(pos)
	if q and flat(q - pos).Magnitude > 1e-3 then return flat(q - pos).Unit end
	return away
end
-- a dry DETOUR_STEP-stud step around water toward a dry `to`: on one side, the smallest turn off the straight way
-- (DETOUR_TURN .. 180 degrees in DETOUR_TURN steps) whose step is dry, so it follows the shore. The side is the one
-- needing the smaller turn, kept by the bot (b.detourSide) for DETOUR_KEEP s after each detour step so it does not
-- swap sides along the way; nil when no step is dry
local function detour(from, to, b)
	local base = flat(to - from)
	if base.Magnitude < 1e-3 then return nil end
	base = base.Unit
	local function first(side)
		for deg = DETOUR_TURN, 180, DETOUR_TURN do
			local dir = CFrame.Angles(0, math.rad(deg * side), 0):VectorToWorldSpace(base)
			local q = flat(from) + dir * DETOUR_STEP
			local _, clear = dryLine(from, q)
			if clear then return q, deg end
		end
		return nil, nil
	end
	local side = b and b.detourSide and os.clock() < (b.detourUntil or 0) and b.detourSide or nil
	local q = side and first(side) or nil
	if not q then
		local qa, da = first(1)
		local qb, db = first(-1)
		if qa and (not qb or da <= db) then q, side = qa, 1 else q, side = qb, -1 end
	end
	if q and b then
		b.detourSide, b.detourUntil = side, os.clock() + DETOUR_KEEP
		if b.shown.BotDetourSide ~= side then -- (show() is declared further down)
			b.shown.BotDetourSide = side
			b.model:SetAttribute("BotDetourSide", side)
		end
	end
	return q
end
-- (goal, clear, detoured): dryLine; when the way is cut within DETOUR_NEAR studs of `from` and `to` itself is dry,
-- a detour step instead of standing at the shore
local function dryGoal(from, to, b)
	local goal, clear = dryLine(from, to)
	if clear then return goal, true, false end
	if flat(goal - from).Magnitude < DETOUR_NEAR and not isWater(to) then
		local d = detour(from, to, b)
		if d then return d, false, true end
	end
	return goal, false, false
end

local bots = {} -- list of bot records
local nextIndex = {}
local packs = {} -- v1.4: {name, members = {[slot] = record}, grudge = Player?, grudgeUntil (os.clock), grudgeUntilServer}

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
		if b.marker and b.marker.Parent then spawnBot(b.marker, b.pack, b.slot) end -- v1.4: + pack, slot
	end)
end

function spawnBot(marker, pack, slot) -- v1.4: + pack, slot (nil: v1.3)
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
	local home = flat(base) -- v1.4: a pack's home is its marker
	if pack and slot then -- v1.4: members stand on a ring around the marker
		local a = (slot - 1) * 2 * math.pi / PACK_SIZE
		local q = flat(base) + Vector3.new(math.cos(a), 0, math.sin(a)) * PACK_SPAWN_RING
		local hit = groundHit(q.X, q.Z)
		if hit and not isWater(q) then base = hit.Position end
		model:SetAttribute("BotPack", pack.name)
		model:SetAttribute("BotPackSlot", slot)
	end
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
	if pack then -- v1.4
		local rec = bots[#bots]
		rec.home, rec.pack, rec.slot = home, pack, slot
		pack.members[slot] = rec
	end
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

-- v1.4: is a T-Rex (player not hidden / bot not KO'd) within r studs (flat) of p?
local function rexNear(p, r)
	for _, pl in ipairs(Players:GetPlayers()) do
		local char, _, thrp = aliveChar(pl)
		if char and char:GetAttribute("Species") == "TRex" and char:GetAttribute("Hidden") ~= true
			and flat(thrp.Position - p).Magnitude <= r then return true end
	end
	for _, o in ipairs(bots) do
		if o.species == "TRex" and not o.removed and o.model.Parent and not o.koAt and flat(o.hrp.Position - p).Magnitude <= r then
			return true
		end
	end
	return false
end

-- v1.4: a wander goal whose straight way is dry (pack members: and not within AVOID_RADIUS + AVOID_HOLD of a T-Rex)
local function randomDryGoal(b)
	for _ = 1, 8 do
		local p = randomGoal(b)
		local _, clear = dryLine(b.hrp.Position, p)
		if clear and b.pack and rexNear(p, AVOID_RADIUS + AVOID_HOLD) then
			clear = false
			b.model:SetAttribute("BotWanderRexSkips", (b.model:GetAttribute("BotWanderRexSkips") or 0) + 1)
		elseif not clear then
			b.model:SetAttribute("BotWanderWetSkips", (b.model:GetAttribute("BotWanderWetSkips") or 0) + 1)
		end
		if clear then return p end
	end
	local cut = dryLine(b.hrp.Position, b.home)
	return cut
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
local function dipFor(b, char, skip) -- v1.4: + skip
	for deg = 0, DIP_MAX, DIP_STEP do
		if distanceTo(char, dippedSnout(b.model, deg), skip) <= b.cfg.biteReach then return deg end
	end
	return nil
end

local function bite(b, player, dip, skip) -- v1.4: + skip
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
		if distanceTo(char, dippedSnout(b.model, dip), skip) > b.cfg.biteReach + 1 then return end -- v1.2: dipped; v1.4: skip
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
	if avoidsWater(b) and d > 1e-3 then -- v1.4: not at a target in water, nor a lunge that would end in water
		if isWater(thrp.Position) then return false end
		local _, clear = dryLine(b.hrp.Position, b.hrp.Position + flat(thrp.Position - b.hrp.Position).Unit * math.min(d + 4, BOT_POUNCE_RANGE[2] + 4))
		if not clear then return false end
	end
	return d >= BOT_POUNCE_RANGE[1] and d <= BOT_POUNCE_RANGE[2]
end

local function startPounce(b, char, skip) -- v1.4: + skip (flank pounce: hitbox segments left out)
	b.pounce = {phase = "windup", t0 = os.clock(), char = char, skip = skip}
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
	local tossLimit = island:GetAttribute("IslandWanderLimit") or TOSS_LIMIT -- v1.4: the current island, not 230
	land = Vector3.new(math.clamp(land.X, -tossLimit, tossLimit), 0, math.clamp(land.Z, -tossLimit, tossLimit))
	if avoidsWater(b) and isWater(land) then land = flat((dryLine(start, land))) end -- v1.4: not into water
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

-- v1.4: packs ---------------------------------------------------------------------------------------------------------
local function waterState(b, st)
	if b.shown.BotState ~= st then
		b.model:SetAttribute("BotWaterAvoids", (b.model:GetAttribute("BotWaterAvoids") or 0) + 1)
	end
	show(b, "BotState", st)
end

local function upMember(m)
	return m ~= nil and not m.removed and m.model.Parent ~= nil and not m.koAt and not m.down and not m.pounce and not m.latch
end

local function packLeader(pk)
	for slot = 1, PACK_SIZE do
		local m = pk.members[slot]
		if upMember(m) then return m end
	end
	return nil
end

local function showPack(pk)
	for _, m in pairs(pk.members) do
		if not m.removed and m.model.Parent then
			show(m, "BotPackGrudge", pk.grudge and pk.grudge.Name or "")
			show(m, "BotPackGrudgeUntil", pk.grudge and math.floor(pk.grudgeUntilServer * 10 + 0.5) / 10 or 0)
		end
	end
end

-- nearest point on a character's hitboxes: only segments in `only` (when given), never those in `skip`
local function nearestAllowed(char, p, only, skip)
	local hb = char:FindFirstChild("Hitboxes")
	if not hb then return nil end
	local best, bestD = nil, math.huge
	for _, part in ipairs(hb:GetChildren()) do
		if part:IsA("BasePart") then
			local seg = part:GetAttribute("HitboxSegment")
			if (only == nil or only[seg]) and not (skip and skip[seg]) then
				local cp = closestPoint(part, p)
				local d = (cp - p).Magnitude
				if d < bestD then best, bestD = cp, d end
			end
		end
	end
	return best, bestD
end

local function hitboxOf(char, seg)
	local hb = char:FindFirstChild("Hitboxes")
	if not hb then return nil end
	for _, part in ipairs(hb:GetChildren()) do
		if part:IsA("BasePart") and part:GetAttribute("HitboxSegment") == seg then return part end
	end
	return nil
end

local function halfAlong(part, dir) -- half extent of a part's box along a world direction
	local cf, h = part.CFrame, part.Size / 2
	return math.abs(cf.RightVector:Dot(dir)) * h.X + math.abs(cf.UpVector:Dot(dir)) * h.Y + math.abs(cf.LookVector:Dot(dir)) * h.Z
end

-- slot 1 left / slot 2 right of his Torso, slot 3 behind his Tail1 (flat)
local function flankSpot(b, char, thrp)
	local look = flat(thrp.CFrame.LookVector)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	if b.slot == 3 then
		local tail = hitboxOf(char, "Tail1") or thrp
		return flat(tail.Position) - look * (halfAlong(tail, look) + FLANK_REAR)
	end
	local torso = hitboxOf(char, "Torso") or thrp
	local side = b.slot == 1 and -right or right
	return flat(torso.Position) + side * (halfAlong(torso, side) + FLANK_SIDE)
end

local function nearestRex(b)
	local pos = b.hrp.Position
	local best, bestD, bestPos = nil, AVOID_RADIUS + (b.avoiding and AVOID_HOLD or 0), nil
	for _, pl in ipairs(Players:GetPlayers()) do
		local char, _, thrp = aliveChar(pl)
		if char and char:GetAttribute("Species") == "TRex" and char:GetAttribute("Hidden") ~= true then
			local d = flat(thrp.Position - pos).Magnitude
			if d <= bestD then best, bestD, bestPos = char.Name, d, thrp.Position end
		end
	end
	for _, o in ipairs(bots) do
		if o.species == "TRex" and not o.removed and o.model.Parent and not o.koAt then
			local d = flat(o.hrp.Position - pos).Magnitude
			if d <= bestD then best, bestD, bestPos = o.model.Name, d, o.hrp.Position end
		end
	end
	return best, bestPos
end

local function clampLimit(p)
	return Vector3.new(math.clamp(p.X, -wanderLimit, wanderLimit), p.Y, math.clamp(p.Z, -wanderLimit, wanderLimit))
end

local function canFlankPounce(b, char)
	if os.clock() < b.nextPounce or not char:FindFirstChild("Hitboxes") then return false end
	local n = 0
	for _, m in pairs(b.pack.members) do
		if not m.removed and ((m.latch and m.latch.char == char) or (m.pounce and m.pounce.char == char)) then n += 1 end
	end
	if n >= LATCH_MAX then return false end
	local pt = nearestAllowed(char, b.hrp.Position + Vector3.new(0, POUNCE_AIM_UP, 0), AIM_SEGMENTS)
	return pt ~= nil and (pt - b.hrp.Position).Magnitude <= BOT_POUNCE_RANGE[2]
end

local function flankStep(b, player, char, thrp, now)
	local model, hum, hrp = b.model, b.hum, b.hrp
	b.target = player
	show(b, "BotTarget", player.Name)
	b.goal, b.waitUntil = nil, nil
	hum.WalkSpeed = (model:GetAttribute("MoveRunSpeed") or 28) * get("BotChaseSpeedMul")
	local f = b.flank or {phase = "spot", t0 = now}
	b.flank = f
	local wet = isWater(thrp.Position)
	if f.phase == "bite" then -- keep on him while the bite lands, then dash out
		hum:MoveTo(nearestAllowed(char, snoutPoint(model), nil, NO_HEAD) or thrp.Position)
		if now >= f.t0 + BITE_HIT_DELAY + 0.05 then
			local out = flat(hrp.Position - thrp.Position)
			out = out.Magnitude > 1e-3 and out.Unit or -flat(hrp.CFrame.LookVector).Unit
			local goal = clampLimit(flat(hrp.Position) + out * RETREAT_DIST)
			if avoidsWater(b) then goal = dryLine(hrp.Position, goal) end
			f.phase, f.t0, f.goal = "retreat", now, goal
		end
		return true
	end
	if f.phase == "retreat" then
		hum:MoveTo(f.goal)
		show(b, "BotState", "retreat")
		if now >= f.t0 + RETREAT_TIME then f.phase, f.t0 = "spot", now end
		return true
	end
	-- a side bite whenever the snout is in reach of an allowed hitbox
	if now >= b.nextBite then
		local dip = dipFor(b, char, NO_HEAD)
		if dip then
			bite(b, player, dip, NO_HEAD)
			f.phase, f.t0 = "bite", now
			return true
		end
	end
	if f.phase == "dart" then
		local pt = nearestAllowed(char, snoutPoint(model), nil, NO_HEAD)
		if not pt or wet or now > f.t0 + DART_MAX then
			f.phase, f.t0 = "spot", now
		else
			local goal, clear, detoured = pt, true, false
			if avoidsWater(b) then goal, clear, detoured = dryGoal(hrp.Position, pt, b) end
			hum:MoveTo(goal)
			if clear then show(b, "BotState", "dart") else waterState(b, detoured and "detour" or "shore") end
			return true
		end
	end
	local spot = clampLimit(flankSpot(b, char, thrp))
	local goal, clear, detoured = spot, true, false
	if avoidsWater(b) then goal, clear, detoured = dryGoal(hrp.Position, spot, b) end
	hum:MoveTo(goal)
	if flat(spot - hrp.Position).Magnitude <= FLANK_NEAR and not wet then
		if canFlankPounce(b, char) then
			startPounce(b, char, NO_HEAD)
			return true
		end
		if now >= b.nextBite then f.phase, f.t0 = "dart", now end
	end
	if clear then show(b, "BotState", "flank") else waterState(b, detoured and "detour" or "shore") end
	return true
end

-- grudge -> flank; a T-Rex near -> avoid; returns true when it handled this tick
local function packStep(b, now)
	local model, hum, hrp = b.model, b.hum, b.hrp
	local pk = b.pack
	if pk.grudge then
		local gChar, _, gHrp = aliveChar(pk.grudge)
		if gChar then
			show(b, "BotAvoiding", "")
			return flankStep(b, pk.grudge, gChar, gHrp, now)
		end
		pk.grudge = nil
	end
	b.flank = nil
	local rex, rexPos = nearestRex(b)
	b.avoiding = rex
	show(b, "BotAvoiding", rex or "")
	if not rex then return false end
	local away = flat(hrp.Position - rexPos)
	if away.Magnitude < 1e-3 then away = -flat(hrp.CFrame.LookVector) end
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local best, bestScore = nil, -math.huge
	for _, deg in ipairs({0, 45, -45, 90, -90, 135, -135}) do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(away)
		local goal = clampLimit(flat(hrp.Position) + dir * AVOID_FLEE)
		if avoidsWater(b) then goal = dryLine(hrp.Position, goal) end
		local score = flat(goal - rexPos).Magnitude
		if score > bestScore + 0.5 then best, bestScore = goal, score end
	end
	b.goal, b.waitUntil, b.target = nil, nil, nil
	show(b, "BotTarget", "")
	hum.WalkSpeed = model:GetAttribute("MoveRunSpeed") or 28
	hum:MoveTo(best)
	show(b, "BotState", "avoid")
	return true
end

-- a follower walks to its spot behind the leader
local function followStep(b, leader)
	local hum, hrp = b.hum, b.hrp
	local look = flat(leader.hrp.CFrame.LookVector)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local rank = 0
	for slot = 1, PACK_SIZE do
		local m = b.pack.members[slot]
		if m == b then break end
		if m ~= leader and upMember(m) then rank += 1 end
	end
	local side = (rank % 2 == 0) and -1 or 1
	local back = 1 + math.floor(rank / 2)
	local spot = clampLimit(flat(leader.hrp.Position) - look * (FORMATION * back) + right * (side * FORMATION * 0.7))
	local goal, clear, detoured = spot, true, false
	if avoidsWater(b) then goal, clear, detoured = dryGoal(hrp.Position, spot, b) end
	b.goal, b.waitUntil = nil, nil
	local d = flat(goal - hrp.Position).Magnitude
	if d <= FOLLOW_STOP then
		hum:Move(Vector3.zero)
		show(b, "BotState", "idle")
		return
	end
	local walk = b.model:GetAttribute("MoveWalkSpeed") or 16
	hum.WalkSpeed = d > CATCH_UP and (b.model:GetAttribute("MoveRunSpeed") or 28) or walk * 1.15
	hum:MoveTo(goal)
	if clear then show(b, "BotState", "follow") else waterState(b, detoured and "detour" or "shore") end
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
	-- v1.4: a raptor bot in water gets out; pack members gang up (grudge) or keep away from a T-Rex
	if avoidsWater(b) and isWater(hrp.Position) then
		local p = nearestDry(hrp.Position) or b.home
		hum.WalkSpeed = model:GetAttribute("MoveRunSpeed") or 28
		hum:MoveTo(p)
		b.goal, b.waitUntil, b.target, b.flank = nil, nil, nil, nil
		show(b, "BotTarget", "")
		waterState(b, "leaveWater")
		return
	end
	if b.pack and get("BotPacksEnabled") then
		show(b, "BotPackRole", packLeader(b.pack) == b and "leader" or "follower")
		if packStep(b, now) then return end
	end
	-- keep / lose the current target
	local target = b.target
	if target then
		local char, _, thrp = aliveChar(target)
		if not char or flat(thrp.Position - hrp.Position).Magnitude > get("BotLoseRange") then
			target = nil
		elseif b.pack and get("BotPacksEnabled") and char:GetAttribute("Species") == "TRex" then -- v1.4: packs leave a T-Rex alone
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
			if char and char:GetAttribute("Hidden") ~= true
				and not (b.pack and get("BotPacksEnabled") and char:GetAttribute("Species") == "TRex") then -- v1.4
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
			hum:MoveTo(avoidsWater(b) and (dryLine(hrp.Position, b.lastSeen)) or b.lastSeen) -- v1.4: not into water
			if os.clock() >= b.nextBite - b.cfg.biteCooldown + 0.6 then show(b, "BotState", "search") end
		else
			local _, _, thrp = aliveChar(target)
			local goal, clear, detoured = thrp.Position, true, false -- v1.4: not into water
			if avoidsWater(b) then goal, clear, detoured = dryGoal(hrp.Position, thrp.Position, b) end
			hum:MoveTo(goal)
			local dip = (now >= b.nextBite and char) and dipFor(b, char) or nil -- v1.2: dipped bite
			if dip then
				bite(b, target, dip)
			elseif char and canPounce(b, char) then -- v1.2
				startPounce(b, char)
			elseif now >= b.nextBite - b.cfg.biteCooldown + 0.6 then
				if clear then show(b, "BotState", "chase") else waterState(b, detoured and "detour" or "shore") end -- v1.4
			end
		end
		return
	end
	-- v1.4: pack followers keep formation behind their leader
	if b.pack and get("BotPacksEnabled") then
		local leader = packLeader(b.pack)
		if leader and leader ~= b then
			followStep(b, leader)
			return
		end
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
			b.goal = avoidsWater(b) and randomDryGoal(b) or randomGoal(b) -- v1.4: dry
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
	if avoidsWater(b) then away = dryLeapDir(hrp.Position, away) end -- v1.4: leap toward dry land
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
						if p.skip then -- v1.4: flank pounce: no head / neck / jaw; flies (3D) at his back / flank / tail
							local kept = {}
							for _, hb in ipairs(p.targets) do
								local seg = hb:GetAttribute("HitboxSegment")
								if not p.skip[seg] and LATCH_SEGMENTS[seg] then table.insert(kept, hb) end
							end
							p.targets = kept
							local aim = nearestAllowed(char, from + Vector3.new(0, POUNCE_AIM_UP, 0), AIM_SEGMENTS)
							if aim and (aim - from).Magnitude > 1e-3 then
								p.dir = (aim - from).Unit
								p.len = math.min((aim - from).Magnitude + 2, BOT_POUNCE_RANGE[2] + 4)
								p.dur = p.len / BOT_POUNCE_SPEED
							end
						end
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
	local raptorMarkers = {} -- v1.4: packs
	for _, marker in ipairs(spawnFolder:GetChildren()) do
		if marker:IsA("BasePart") and get("BotPacksEnabled") and marker:GetAttribute("Species") == "Raptor" then
			table.insert(raptorMarkers, marker)
		elseif marker:IsA("BasePart") then spawnBot(marker) end
	end
	table.sort(raptorMarkers, function(x, y) return x.Name < y.Name end)
	for k, marker in ipairs(raptorMarkers) do
		if k <= PACK_COUNT then
			local pack = {name = "Pack" .. k, members = {}, grudge = nil, grudgeUntil = 0, grudgeUntilServer = 0}
			table.insert(packs, pack)
			marker:SetAttribute("BotPackUnused", false)
			for slot = 1, PACK_SIZE do spawnBot(marker, pack, slot) end
		else
			marker:SetAttribute("BotPackUnused", true)
		end
	end
	script:SetAttribute("BotPacks", #packs)
end
script:SetAttribute("BotServerState", "running")

local lastBiteSeen = {} -- v1.4: [player] = BiteHitAt last looked at
Players.PlayerRemoving:Connect(function(pl) lastBiteSeen[pl] = nil end)

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
	-- v1.4: grudges (a T-Rex player's bite landed on a pack member: only that pack)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = aliveChar(player)
		local at = char and char:GetAttribute("BiteHitAt")
		if char and typeof(at) == "number" and at ~= lastBiteSeen[player] then
			lastBiteSeen[player] = at
			if char:GetAttribute("Species") == "TRex" and math.abs(workspace:GetServerTimeNow() - at) <= GRUDGE_MATCH then
				local name = char:GetAttribute("BiteHitTarget")
				for _, b in ipairs(bots) do
					if b.pack and not b.removed and b.model.Name == name then
						b.pack.grudge = player
						b.pack.grudgeUntil = os.clock() + GRUDGE_TIME
						b.pack.grudgeUntilServer = workspace:GetServerTimeNow() + GRUDGE_TIME
					end
				end
			end
		end
	end
	for _, pk in ipairs(packs) do
		if pk.grudge and (os.clock() > pk.grudgeUntil or not aliveChar(pk.grudge)) then pk.grudge = nil end
		showPack(pk)
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
