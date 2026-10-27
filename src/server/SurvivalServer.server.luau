-- SurvivalServer v1.3 (Dino Arcade) — TEST. Hunger and thirst, linked to health (not stamina).
-- User: "introduce hunger and thirst bars. these will be directly linked to health bar, not stamina" (modelled on The
--   Isle). Answers: damage at 0 only (KillRegen unchanged, no passive regen); Arcade pace; carcass + hold E; hold E in a
--   lake (fresh water only); E only while food / water is in reach (RamTest's E binding is untouched elsewhere);
--   meters 0-100, eat +10/s, drink +15/s; carcass food = the bot's DummyMaxHealth, lasts 90 s; warning at 20%;
--   every new character (spawn, respawn, species swap) starts full.
-- Meters (character attributes, exact numbers, server-owned): Hunger 0..HungerMax, Thirst 0..ThirstMax.
-- Drain per second: Max / DrainTime x SurvivalDrainMul (character attribute, else by Species: TRex 1, Raptor 1.25,
--   else 1). Arcade defaults: Hunger 480 s (8 min), Thirst 360 s (6 min) from full to empty for a T-Rex;
--   raptor 384 s / 288 s.
-- Health link (the only one): while Hunger = 0 the character loses StarveDamageRate x MaxHealth per second; while
--   Thirst = 0 it loses DehydrateDamageRate x MaxHealth per second; both at 0 = both rates (each meter is its own
--   rule). Defaults 0.01 -> 100 s from full health to death with one meter empty, 50 s with both. Damage is set on
--   Humanoid.Health directly (a spawn ForceField does not block it). Health is never raised by this script.
-- Eating: hold E (SurvivalBars) -> DinoSurvivalAction("eat"). Valid while a carcass is in reach of the character's
--   head: flat (X/Z) distance to the carcass's world box <= EatRange and the head within EatHeight studs above its
--   top / below its bottom. Moves min(EatRate x dt, carcass food,
--   HungerMax - Hunger) from the carcass to Hunger each tick. Stops: "released" (key up), "full", "outOfRange" (no
--   carcass in reach; also when the carcass was eaten up or expired), "dead", "disabled", "switched".
-- Drinking: hold E -> DinoSurvivalAction("drink"). Valid while a ray down from the HumanoidRootPart hits a DinoIsland
--   Ground part named "Shallows" whose hit point lies inside a LakeWater part's X/Z (lake = fresh water).
--   Sea shallows / Seabed (outside every LakeWater) = "sea" = salt water: no drinking. Adds DrinkRate x dt.
--   Stops: "released", "full", "notInLake", "dead", "disabled", "switched".
-- Carcasses: a bot (IsBot) that was knocked out (DummyState "ko") or killed (KilledAt) leaves a carcass when
--   BotServer removes it (Destroying, BotKORemoveTime 2.5 s after the KO; BotServer itself is unchanged): a copy of
--   the body taken 0.6 s after the KO (lying pose; moved by the bot's later HumanoidRootPart movement) placed in
--   Workspace.DinoCarcasses, anchored, CanCollide / CanTouch / CanQuery false, no
--   scripts / humanoid / guis / joints / hitboxes, every attribute cleared (not Bitable, not IsBot, no Species).
--   Food = the bot's DummyMaxHealth (Raptor bot 60, T-Rex bot 200). Removed when its food reaches 0 ("eaten") or
--   SurvivalCarcassTime s after it appeared ("expired").
-- Settings (character attributes, defaults below): SurvivalEnabled, HungerMax, ThirstMax, HungerDrainTime,
--   ThirstDrainTime, SurvivalDrainMul, StarveDamageRate, DehydrateDamageRate, EatRate, DrinkRate, EatRange,
--   EatHeight, SurvivalWarnFraction. Script attributes: SurvivalCarcassEnabled (true), SurvivalCarcassTime (90).
-- State (character): Hunger, Thirst; HungerState / ThirstState ("ok" / "warning" below SurvivalWarnFraction x Max /
--   "empty" at 0); SurvivalState ("ok" / "warning" / "starving" / "dehydrating" / "starvingAndDehydrating" /
--   "dead" / "disabled"); SurvivalCanEat, SurvivalNearCarcass (carcass name or ""), SurvivalCanDrink,
--   SurvivalWaterSource ("lake" / "sea" / "none"); SurvivalAction ("none" / "eating" / "drinking").
-- Diagnostics (character): SurvivalVersion, SurvivalLastChange (which meter state changed, from -> to, and the value
--   that triggered it) + SurvivalLastChangeAt, SurvivalActionResult ("started" / stop reason / "badArg"),
--   SurvivalActionStartedAt / SurvivalActionStoppedAt, LastAteAt, LastDrankAt, SurvivalFoodEaten,
--   SurvivalWaterDrunk, StarveDamageTaken / DehydrateDamageTaken (exact), SurvivalDamageTaken (whole),
--   SurvivalDiedOf ("starvation" / "dehydration" / "starvationAndDehydration", set when this script's damage
--   takes health to 0).
-- Diagnostics (script): SurvivalServerVersion, SurvivalCarcasses (now), SurvivalCarcassesMade,
--   SurvivalCarcassesEaten, SurvivalCarcassesExpired, SurvivalCarcassLastRemoved ("<name>:<reason>"),
--   SurvivalCarcassLastSkipped ("<bot>:disabled" / ":noSnapshot" / ":noParts").
-- v1.1 (user: drinking "should take you a little longer to stick your head in the water", "the meter shouldnt start
--   refilling til the mouth is submerged", eating "only refills once the mouth is actually eating and its an animation
--   that takes time to get into rendering the player vulnerable", "dead dinos should also be clearly dead"; answers:
--   move + turn locked, bite / roar / pounce still work and cancel the meal; drink 1 s, eat 1.5 s, up 0.5 s; dead pose):
--   * Phases (character attribute SurvivalPhase, set last; SurvivalPhaseAt = server time the phase began):
--       "none" -> press E -> "lowering" (DrinkEnterTime 1.0 / EatEnterTime 1.5 s: the head goes down, NO refill)
--       -> "drinking" / "eating" (mouth in: the refill of v1.0 runs, only in this phase) -> stop -> "rising"
--       (SurvivalRiseTime 0.5 s: getting back up) -> "none". SurvivalKind ("eat" / "drink") stays set through rising;
--       SurvivalEnterTime / SurvivalRiseTime = the times used (IdleAnimation 1.21 / EatPose 1.1 time the animation
--       from these, so the mouth is in exactly when the refill starts).
--     Stop reasons that go through "rising": released, full, outOfRange, notInLake, switched. Straight to "none":
--     dead, disabled, interrupted. A press during "rising" starts a new "lowering".
--   * Vulnerable: SurvivalLocked = true while SurvivalPhase ~= "none" (SurvivalBars 1.1 holds the body still and its
--     heading fixed on the owner's client).
--   * Interrupted: during lowering / eating / drinking / rising, a BiteStartedAt, RoarStartedAt, PounceStartedAt,
--     JumpStartedAt or RamStartedAt newer than the lock start (SurvivalLockAt), or StunnedUntil in the future, stops
--     the action with "interrupted" (no rising, the lock ends at once). SurvivalInterruptedBy = the attribute name.
--   * Carcass dead pose (DeadPose 1.0, required from StarterPlayer.StarterCharacterScripts.IdleAnimation.DeadPose):
--     the snapshot keeps its Motor6Ds and WeldConstraints whose parts are both inside it (others are removed), only
--     its HumanoidRootPart (and parts with no joint) stays anchored, every Motor6D C0 = C0 x DeadPose offset (the
--     server C0 is the rest pose), so the joints hold the dead pose (replicated). The carcass box is measured again one
--     Heartbeat after it is placed (joints solved). Diagnostic carcass attribute CarcassDeadPose (true / false).
-- v1.2 (bug: "the eating animation hasnt shown up once"): the eat reach measured from Model:GetBoundingBox() of the
--   character's Head segment. On the server that box is cached: it only follows a server-side move (PivotTo), not the
--   walking the owner's client replicates, so after a player walked anywhere the "head" stayed where the character was
--   last placed and SurvivalCanEat stayed false (no prompt, E never bound for eating, no eat phase). Every test of 1.0 /
--   1.1 teleported the character with PivotTo just before eating, which refreshed the box and hid it. headPos now takes
--   the centre of the world box of the Head segment's parts (worldBox, part CFrames are current). Diagnostic character
--   attribute SurvivalHeadPos (Vector3, the point the reach is measured from).
-- v1.3: carcasses get X eyes (DeadPose 1.1 markEyes: eyes shut in skin colour + dark X, pupils / shine hidden) when
--   the snapshot is made (server, replicated). Diagnostic carcass attribute CarcassDeadEyes (true / false).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.3"
local TICK = 0.1
local REMOTE_NAME = "DinoSurvivalAction"
local CARCASS_FOLDER = "DinoCarcasses"
local RAY_DOWN = 80
local DEFAULTS = {
	SurvivalEnabled = true,
	HungerMax = 100, ThirstMax = 100,
	HungerDrainTime = 480, ThirstDrainTime = 360, -- s from full to empty at drain mul 1 (Arcade)
	StarveDamageRate = 0.01, DehydrateDamageRate = 0.01, -- share of MaxHealth per s while the meter is 0
	EatRate = 10, DrinkRate = 15, -- meter points per s while holding E
	EatRange = 8, -- flat studs from the head to the carcass box
	EatHeight = 20, -- head at most this far above the carcass box top (or below its bottom)
	SurvivalWarnFraction = 0.2,
}
DEFAULTS.EatEnterTime = 1.5     -- v1.1: s from the press until the mouth is in the carcass (no refill before)
DEFAULTS.DrinkEnterTime = 1.0   -- v1.1: s from the press until the mouth is in the water
DEFAULTS.SurvivalRiseTime = 0.5 -- v1.1: s getting back up after letting go
local RISE_REASONS = {released = true, full = true, outOfRange = true, notInLake = true, switched = true} -- v1.1
local INTERRUPT_ATTRS = {"BiteStartedAt", "RoarStartedAt", "PounceStartedAt", "JumpStartedAt", "RamStartedAt"} -- v1.1
local DeadPose -- v1.1: DeadPose module (nil = carcasses keep the rest pose)
do
	local ok, mod = pcall(function()
		local ia = game:GetService("StarterPlayer"):WaitForChild("StarterCharacterScripts"):WaitForChild("IdleAnimation", 10)
		return ia and require(ia:WaitForChild("DeadPose", 10))
	end)
	if ok then DeadPose = mod end
end
local DRAIN_MUL_BY_SPECIES = {TRex = 1, Raptor = 1.25}
local SCRIPT_DEFAULTS = {SurvivalCarcassEnabled = true, SurvivalCarcassTime = 90}

script:SetAttribute("SurvivalServerVersion", VERSION)
for k, v in pairs(SCRIPT_DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, k in ipairs({"SurvivalCarcasses", "SurvivalCarcassesMade", "SurvivalCarcassesEaten", "SurvivalCarcassesExpired"}) do
	script:SetAttribute(k, 0)
end
script:SetAttribute("SurvivalCarcassLastRemoved", "")
script:SetAttribute("SurvivalCarcassLastSkipped", "")

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

local carcassFolder = workspace:FindFirstChild(CARCASS_FOLDER)
if not carcassFolder then
	carcassFolder = Instance.new("Folder")
	carcassFolder.Name = CARCASS_FOLDER
	carcassFolder.Parent = workspace
end

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local function sget(k)
	local v = script:GetAttribute(k)
	if v == nil then v = SCRIPT_DEFAULTS[k] end
	return v
end

local function bump(k, n)
	script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1))
end

local function set(inst, k, v)
	if inst:GetAttribute(k) ~= v then inst:SetAttribute(k, v) end
end

local function drainMul(char)
	local m = char:GetAttribute("SurvivalDrainMul")
	if type(m) == "number" then return m end
	return DRAIN_MUL_BY_SPECIES[char:GetAttribute("Species")] or 1
end

---------------------------------------------------------------- carcasses
local carcasses = {} -- [model] = {food, expires, lo, hi (world box)}
local carcassIndex = 0

local function removeCarcass(model, reason)
	if not carcasses[model] then return end
	carcasses[model] = nil
	script:SetAttribute("SurvivalCarcassLastRemoved", model.Name .. ":" .. reason)
	if reason == "eaten" then bump("SurvivalCarcassesEaten") elseif reason == "expired" then bump("SurvivalCarcassesExpired") end
	model:Destroy()
	bump("SurvivalCarcasses", -1)
end

local STRIP = {"LuaSourceContainer", "Humanoid", "AnimationController", "Animator", "LayerCollector", "Sound",
	"ParticleEmitter", "Beam", "Trail", "ProximityPrompt", "Constraint", "JointInstance", "WeldConstraint",
	"NoCollisionConstraint", "BodyMover"}

-- v1.0: a bot's children are already gone when its Destroying fires, so the body is copied SNAPSHOT_DELAY s after
-- the KO (the KO roll takes 0.4 s, BotKORemoveTime is 2.5 s), kept unparented, and placed when the bot is removed
-- (moved by however far the bot's HumanoidRootPart moved since the copy, e.g. dragged by a pin).
local SNAPSHOT_DELAY = 0.6

local function snapshotCarcass(bot)
	bot.Archivable = true
	local ok, c = pcall(function() return bot:Clone() end)
	if not ok or not c then return nil end
	local hb = c:FindFirstChild("Hitboxes")
	if hb then hb:Destroy() end
	local jointed = {} -- v1.1: parts held by a kept joint
	local deadOffsets = DeadPose and DeadPose.get(DeadPose.settings(bot)) or nil -- v1.1
	for _, d in ipairs(c:GetDescendants()) do
		if d.Parent then
			local strip = false
			for _, cls in ipairs(STRIP) do
				if d:IsA(cls) then strip = true break end
			end
			-- v1.1: Motor6Ds / WeldConstraints with both parts inside the carcass are kept (they hold the dead pose)
			if strip and DeadPose and (d:IsA("Motor6D") or d:IsA("WeldConstraint"))
				and d.Part0 and d.Part1 and d.Part0:IsDescendantOf(c) and d.Part1:IsDescendantOf(c) then
				strip = false
				jointed[d.Part0], jointed[d.Part1] = true, true
				if d:IsA("Motor6D") and deadOffsets and deadOffsets[d.Name] then d.C0 = d.C0 * deadOffsets[d.Name] end
			end
			if strip then
				d:Destroy()
			else
				for k in pairs(d:GetAttributes()) do d:SetAttribute(k, nil) end
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
					d.AssemblyLinearVelocity = Vector3.zero
					d.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
	end
	for k in pairs(c:GetAttributes()) do c:SetAttribute(k, nil) end
	-- v1.1: only the root (and parts no joint holds) stays anchored, so the joints place the limbs in the dead pose
	if DeadPose then
		local root = c:FindFirstChild("HumanoidRootPart")
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root and jointed[d] then d.Anchored = false end
		end
	end
	c:SetAttribute("CarcassDeadPose", DeadPose ~= nil and deadOffsets ~= nil)
	-- v1.3: X eyes
	local eyes = DeadPose and DeadPose.markEyes and DeadPose.markEyes(c) or nil
	c:SetAttribute("CarcassDeadEyes", eyes ~= nil)
	return c
end

-- v1.1: world box of a carcass (all parts)
local function worldBox(c)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			local r = d.CFrame
			local ext = Vector3.new(
				math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
				math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
				math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
			lo = lo:Min(d.Position - ext)
			hi = hi:Max(d.Position + ext)
		end
	end
	return lo, hi
end

local function placeCarcass(bot, w)
	if sget("SurvivalCarcassEnabled") ~= true then
		script:SetAttribute("SurvivalCarcassLastSkipped", bot.Name .. ":disabled")
		return
	end
	local c = w.snap
	if not c then
		script:SetAttribute("SurvivalCarcassLastSkipped", bot.Name .. ":noSnapshot")
		return
	end
	w.snap = nil
	if w.snapCF and w.lastCF then
		c:PivotTo((w.lastCF * w.snapCF:Inverse()) * c:GetPivot())
	end
	local food = w.food
	carcassIndex += 1
	c.Name = ("Carcass_%s_%d"):format(w.species, carcassIndex)
	local now = workspace:GetServerTimeNow()
	local life = sget("SurvivalCarcassTime")
	c:SetAttribute("Carcass", true)
	c:SetAttribute("CarcassSpecies", w.species)
	c:SetAttribute("CarcassFood", food)
	c:SetAttribute("CarcassFoodMax", food)
	c:SetAttribute("CarcassFrom", bot.Name)
	c:SetAttribute("CarcassKilledBy", bot:GetAttribute("KilledBy") or w.killedBy or "")
	c:SetAttribute("CarcassCreatedAt", now)
	c:SetAttribute("CarcassExpiresAt", now + life)
	-- world-space box of every part (reach test, see nearestCarcass)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			local r = d.CFrame
			local ext = Vector3.new(
				math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
				math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
				math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
			lo = lo:Min(d.Position - ext)
			hi = hi:Max(d.Position + ext)
		end
	end
	if lo.X == math.huge then
		c:Destroy()
		script:SetAttribute("SurvivalCarcassLastSkipped", bot.Name .. ":noParts")
		return
	end
	carcasses[c] = {food = food, expires = os.clock() + life, lo = lo, hi = hi}
	c.Parent = carcassFolder
	task.spawn(function() -- v1.1: measure the box again once the joints have placed the dead pose
		RunService.Heartbeat:Wait()
		local entry = carcasses[c]
		if entry and c.Parent then entry.lo, entry.hi = worldBox(c) end
	end)
	bump("SurvivalCarcasses")
	bump("SurvivalCarcassesMade")
end

local watchedBots = setmetatable({}, {__mode = "k"})
local downedBots = {} -- [bot] = w (HumanoidRootPart CFrame tracked every tick until removal)
local function watchBot(m)
	if watchedBots[m] or not m:IsA("Model") or m:GetAttribute("IsBot") ~= true then return end
	local w = {downed = false}
	watchedBots[m] = w
	local function onDown()
		if w.downed then return end
		w.downed = true
		w.food = m:GetAttribute("DummyMaxHealth") or 100
		w.species = m:GetAttribute("Species") or m:GetAttribute("BotSpecies") or "Dino"
		w.killedBy = m:GetAttribute("KilledBy")
		w.hrp = m:FindFirstChild("HumanoidRootPart")
		downedBots[m] = w
		task.delay(SNAPSHOT_DELAY, function()
			if m.Parent and not w.snap then
				w.snap = snapshotCarcass(m)
				w.snapCF = w.hrp and w.hrp.CFrame or nil
				w.lastCF = w.snapCF
			end
		end)
	end
	if m:GetAttribute("DummyState") == "ko" or m:GetAttribute("KilledAt") ~= nil then onDown() end
	m:GetAttributeChangedSignal("DummyState"):Connect(function()
		if m:GetAttribute("DummyState") == "ko" then onDown() end
	end)
	m:GetAttributeChangedSignal("KilledAt"):Connect(function()
		if m:GetAttribute("KilledAt") ~= nil then onDown() end
	end)
	m.Destroying:Connect(function()
		downedBots[m] = nil
		if w.downed then placeCarcass(m, w) end
	end)
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") then watchBot(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if not d:IsA("Model") or d:IsDescendantOf(carcassFolder) then return end
	if d:GetAttribute("IsBot") == true then
		watchBot(d)
	else
		-- BotServer sets IsBot right after cloning (same catch as KillRegenServer 1.0)
		local conn
		conn = d:GetAttributeChangedSignal("IsBot"):Connect(function()
			conn:Disconnect()
			watchBot(d)
		end)
		task.delay(2, function() if conn.Connected then conn:Disconnect() end end)
	end
end)

-- v1.0: the head is a segment Model (DinoModelBuilder) whose pivot does not follow its parts -> bounding box centre
-- v1.2: centre of the world box of its parts (Model:GetBoundingBox() is stale on the server for a walking player)
local function headPos(char, root)
	local head = char:FindFirstChild("Head", true)
	local p = root.Position
	if head then
		if head:IsA("BasePart") then
			p = head.Position
		elseif head:IsA("Model") then
			local lo, hi = worldBox(head)
			if lo.X ~= math.huge then p = (lo + hi) / 2 end
		end
	end
	char:SetAttribute("SurvivalHeadPos", p)
	return p
end

-- reach: flat (X/Z) distance from the head to the carcass box <= EatRange, and the head no more than EatHeight
-- studs above the box top (a T-Rex head is ~16 studs up; the bite dips down to the body)
local function nearestCarcass(char, root)
	local p = headPos(char, root)
	local range, height = get(char, "EatRange"), get(char, "EatHeight")
	local best, bestD = nil, math.huge
	for model, c in pairs(carcasses) do
		if c.food > 0 and p.Y <= c.hi.Y + height and p.Y >= c.lo.Y - height then
			local dx = math.max(c.lo.X - p.X, 0, p.X - c.hi.X)
			local dz = math.max(c.lo.Z - p.Z, 0, p.Z - c.hi.Z)
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= range and d < bestD then best, bestD = model, d end
		end
	end
	return best
end

---------------------------------------------------------------- water
local lakeCache = {island = nil, ground = nil, rects = {}}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function lakeInfo()
	local island = workspace:FindFirstChild("DinoIsland")
	local ground = island and island:FindFirstChild("Ground")
	if ground ~= lakeCache.ground then
		lakeCache.island, lakeCache.ground, lakeCache.rects = island, ground, {}
		if ground then
			for _, p in ipairs(ground:GetChildren()) do
				if p.Name == "LakeWater" and p:IsA("BasePart") then
					table.insert(lakeCache.rects, {p.Position.X - p.Size.X / 2, p.Position.Z - p.Size.Z / 2,
						p.Position.X + p.Size.X / 2, p.Position.Z + p.Size.Z / 2})
				end
			end
			rayParams.FilterDescendantsInstances = {ground}
		end
	end
	return lakeCache.ground, lakeCache.rects
end

local function waterSource(root)
	local ground, rects = lakeInfo()
	if not ground then return "none" end
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -RAY_DOWN, 0), rayParams)
	if not hit then return "none" end
	local name = hit.Instance.Name
	if name == "Shallows" then
		local x, z = hit.Position.X, hit.Position.Z
		for _, r in ipairs(rects) do
			if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then return "lake" end
		end
		return "sea"
	elseif name == "Seabed" then
		return "sea"
	end
	return "none"
end

---------------------------------------------------------------- characters
local states = {} -- [char] = {hum, action = "none" / "eat" / "drink"}

local function meterState(v, max, warn)
	if v <= 0 then return "empty" end
	if v < warn * max then return "warning" end
	return "ok"
end

-- v1.1: phase change; SurvivalPhase is written last (clients react to it)
local function setPhase(char, s, phase, at)
	s.phase, s.phaseAt = phase, at
	char:SetAttribute("SurvivalPhaseAt", at)
	set(char, "SurvivalLocked", phase ~= "none")
	char:SetAttribute("SurvivalPhase", phase == "active" and (s.kind == "eat" and "eating" or "drinking") or phase)
end

local function stopAction(char, s, reason)
	s.action = "none"
	set(char, "SurvivalAction", "none")
	char:SetAttribute("SurvivalActionResult", reason)
	char:SetAttribute("SurvivalActionStoppedAt", workspace:GetServerTimeNow())
	-- v1.1: get back up (still locked) unless dead / disabled / interrupted
	if s.phase == "lowering" or s.phase == "active" then
		setPhase(char, s, RISE_REASONS[reason] and "rising" or "none", workspace:GetServerTimeNow())
	end
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	local hMax, tMax = get(char, "HungerMax"), get(char, "ThirstMax")
	char:SetAttribute("SurvivalVersion", VERSION)
	char:SetAttribute("Hunger", hMax)
	char:SetAttribute("Thirst", tMax)
	char:SetAttribute("HungerState", "ok")
	char:SetAttribute("ThirstState", "ok")
	char:SetAttribute("SurvivalState", "ok")
	char:SetAttribute("SurvivalAction", "none")
	char:SetAttribute("SurvivalActionResult", "")
	char:SetAttribute("SurvivalCanEat", false)
	char:SetAttribute("SurvivalNearCarcass", "")
	char:SetAttribute("SurvivalCanDrink", false)
	char:SetAttribute("SurvivalWaterSource", "none")
	char:SetAttribute("SurvivalLastChange", "spawn: full")
	char:SetAttribute("SurvivalLastChangeAt", workspace:GetServerTimeNow())
	char:SetAttribute("SurvivalFoodEaten", 0)
	char:SetAttribute("SurvivalWaterDrunk", 0)
	char:SetAttribute("StarveDamageTaken", 0)
	char:SetAttribute("DehydrateDamageTaken", 0)
	char:SetAttribute("SurvivalDamageTaken", 0)
	states[char] = {hum = hum, action = "none", phase = "none", phaseAt = 0, kind = "", lockAt = 0} -- v1.1: phase
	char:SetAttribute("SurvivalKind", "") -- v1.1
	char:SetAttribute("SurvivalEnterTime", 0)
	char:SetAttribute("SurvivalRiseTime", get(char, "SurvivalRiseTime"))
	char:SetAttribute("SurvivalLockAt", 0)
	char:SetAttribute("SurvivalInterruptedBy", "")
	char:SetAttribute("SurvivalLocked", false)
	char:SetAttribute("SurvivalPhaseAt", 0)
	char:SetAttribute("SurvivalPhase", "none")
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	if player.Character then states[player.Character] = nil end
end)

remote.OnServerEvent:Connect(function(player, what)
	local char = player.Character
	local s = char and states[char]
	if not s then return end
	if what == "stop" then
		if s.action ~= "none" then stopAction(char, s, "released") end
		return
	end
	if what ~= "eat" and what ~= "drink" then
		char:SetAttribute("SurvivalActionResult", "badArg")
		return
	end
	if s.action == what then return end
	if s.action ~= "none" then stopAction(char, s, "switched") end
	s.action = what
	set(char, "SurvivalAction", what == "eat" and "eating" or "drinking")
	char:SetAttribute("SurvivalActionResult", "started")
	char:SetAttribute("SurvivalActionStartedAt", workspace:GetServerTimeNow())
	-- v1.1: lower the head first; the refill starts when the phase becomes eating / drinking
	local now = workspace:GetServerTimeNow()
	s.kind = what
	if s.phase == "none" then s.lockAt = now end -- a press while rising keeps the lock it already has
	char:SetAttribute("SurvivalLockAt", s.lockAt)
	char:SetAttribute("SurvivalKind", what)
	char:SetAttribute("SurvivalEnterTime", get(char, what == "eat" and "EatEnterTime" or "DrinkEnterTime"))
	char:SetAttribute("SurvivalRiseTime", get(char, "SurvivalRiseTime"))
	setPhase(char, s, "lowering", now)
end)

local function update(char, s, dt)
	local hum = s.hum
	if not char.Parent or not hum.Parent then
		states[char] = nil
		return
	end
	if hum.Health <= 0 then
		if s.action ~= "none" then stopAction(char, s, "dead") end
		if s.phase ~= "none" then setPhase(char, s, "none", workspace:GetServerTimeNow()) end -- v1.1
		set(char, "SurvivalCanEat", false)
		set(char, "SurvivalCanDrink", false)
		set(char, "SurvivalState", "dead")
		return
	end
	if get(char, "SurvivalEnabled") ~= true then
		if s.action ~= "none" then stopAction(char, s, "disabled") end
		if s.phase ~= "none" then setPhase(char, s, "none", workspace:GetServerTimeNow()) end -- v1.1
		set(char, "SurvivalCanEat", false)
		set(char, "SurvivalCanDrink", false)
		set(char, "SurvivalState", "disabled")
		return
	end
	local hMax = math.max(1, get(char, "HungerMax"))
	local tMax = math.max(1, get(char, "ThirstMax"))
	local hunger = math.clamp(char:GetAttribute("Hunger") or hMax, 0, hMax)
	local thirst = math.clamp(char:GetAttribute("Thirst") or tMax, 0, tMax)
	local mul = drainMul(char)
	-- 1. drain
	hunger = math.max(0, hunger - hMax / math.max(1, get(char, "HungerDrainTime")) * mul * dt)
	thirst = math.max(0, thirst - tMax / math.max(1, get(char, "ThirstDrainTime")) * mul * dt)
	-- 2. what is in reach
	local root = char:FindFirstChild("HumanoidRootPart")
	local carcass = root and nearestCarcass(char, root) or nil
	local source = root and waterSource(root) or "none"
	set(char, "SurvivalCanEat", carcass ~= nil)
	set(char, "SurvivalNearCarcass", carcass and carcass.Name or "")
	set(char, "SurvivalWaterSource", source)
	set(char, "SurvivalCanDrink", source == "lake")
	-- 3. eat / drink
	local now = workspace:GetServerTimeNow()
	-- v1.1: interruptions (bite / roar / pounce / leap / ram, stun) end the lock at once
	if s.phase ~= "none" then
		local by
		for _, k in ipairs(INTERRUPT_ATTRS) do
			local v = char:GetAttribute(k)
			if typeof(v) == "number" and v > s.lockAt + 1e-3 then by = k break end
		end
		local stun = char:GetAttribute("StunnedUntil")
		if not by and typeof(stun) == "number" and stun > now then by = "StunnedUntil" end
		if by then
			char:SetAttribute("SurvivalInterruptedBy", by)
			if s.action ~= "none" then stopAction(char, s, "interrupted") end
			if s.phase ~= "none" then setPhase(char, s, "none", now) end
		end
	end
	-- v1.1: phase timers
	if s.phase == "lowering" and now - s.phaseAt >= (char:GetAttribute("SurvivalEnterTime") or 0) then
		setPhase(char, s, "active", s.phaseAt + (char:GetAttribute("SurvivalEnterTime") or 0))
	elseif s.phase == "rising" and now - s.phaseAt >= (char:GetAttribute("SurvivalRiseTime") or 0) then
		setPhase(char, s, "none", now)
	end
	if s.action == "eat" then
		if not carcass then
			stopAction(char, s, "outOfRange")
		elseif hunger >= hMax then
			stopAction(char, s, "full")
		elseif s.phase ~= "active" then -- v1.1: still lowering, no refill yet
		else
			local c = carcasses[carcass]
			local amount = math.min(get(char, "EatRate") * dt, c.food, hMax - hunger)
			hunger += amount
			c.food -= amount
			carcass:SetAttribute("CarcassFood", math.max(0, c.food))
			char:SetAttribute("SurvivalFoodEaten", (char:GetAttribute("SurvivalFoodEaten") or 0) + amount)
			char:SetAttribute("LastAteAt", now)
			if c.food <= 1e-6 then removeCarcass(carcass, "eaten") end
			if hunger >= hMax then stopAction(char, s, "full") end
		end
	elseif s.action == "drink" then
		if source ~= "lake" then
			stopAction(char, s, "notInLake")
		elseif thirst >= tMax then
			stopAction(char, s, "full")
		elseif s.phase ~= "active" then -- v1.1: still lowering, no refill yet
		else
			local amount = math.min(get(char, "DrinkRate") * dt, tMax - thirst)
			thirst += amount
			char:SetAttribute("SurvivalWaterDrunk", (char:GetAttribute("SurvivalWaterDrunk") or 0) + amount)
			char:SetAttribute("LastDrankAt", now)
			if thirst >= tMax then stopAction(char, s, "full") end
		end
	end
	char:SetAttribute("Hunger", hunger)
	char:SetAttribute("Thirst", thirst)
	-- 4. meter states (each change is traced)
	local warn = get(char, "SurvivalWarnFraction")
	local hs, ts = meterState(hunger, hMax, warn), meterState(thirst, tMax, warn)
	local oldH, oldT = char:GetAttribute("HungerState"), char:GetAttribute("ThirstState")
	if hs ~= oldH then
		char:SetAttribute("HungerState", hs)
		char:SetAttribute("SurvivalLastChange", ("HungerState %s -> %s (Hunger %.2f / %d, warn %.2f)"):format(tostring(oldH), hs, hunger, hMax, warn))
		char:SetAttribute("SurvivalLastChangeAt", now)
	end
	if ts ~= oldT then
		char:SetAttribute("ThirstState", ts)
		char:SetAttribute("SurvivalLastChange", ("ThirstState %s -> %s (Thirst %.2f / %d, warn %.2f)"):format(tostring(oldT), ts, thirst, tMax, warn))
		char:SetAttribute("SurvivalLastChangeAt", now)
	end
	local state
	if hs == "empty" and ts == "empty" then
		state = "starvingAndDehydrating"
	elseif hs == "empty" then
		state = "starving"
	elseif ts == "empty" then
		state = "dehydrating"
	elseif hs == "warning" or ts == "warning" then
		state = "warning"
	else
		state = "ok"
	end
	set(char, "SurvivalState", state)
	-- 5. health link: damage only while a meter is empty
	local starve = hs == "empty" and get(char, "StarveDamageRate") * hum.MaxHealth * dt or 0
	local dehyd = ts == "empty" and get(char, "DehydrateDamageRate") * hum.MaxHealth * dt or 0
	if starve > 0 or dehyd > 0 then
		char:SetAttribute("StarveDamageTaken", (char:GetAttribute("StarveDamageTaken") or 0) + starve)
		char:SetAttribute("DehydrateDamageTaken", (char:GetAttribute("DehydrateDamageTaken") or 0) + dehyd)
		char:SetAttribute("SurvivalDamageTaken", math.floor(char:GetAttribute("StarveDamageTaken") + char:GetAttribute("DehydrateDamageTaken") + 0.5))
		hum.Health = math.max(0, hum.Health - starve - dehyd)
		if hum.Health <= 0 then
			char:SetAttribute("SurvivalDiedOf", (starve > 0 and dehyd > 0) and "starvationAndDehydration"
				or (starve > 0 and "starvation" or "dehydration"))
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	local step = acc
	acc = 0
	for char, s in pairs(states) do update(char, s, step) end
	for _, w in pairs(downedBots) do
		if w.snap and w.hrp and w.hrp.Parent then w.lastCF = w.hrp.CFrame end
	end
	local t = os.clock()
	for model, c in pairs(carcasses) do
		if not model.Parent then
			carcasses[model] = nil
			bump("SurvivalCarcasses", -1)
		elseif t >= c.expires then
			removeCarcass(model, "expired")
		end
	end
end)
