-- GrowthServer v1.0 (Dino Arcade) — growth: XP, levels, stages, body scale, stats, death drop (session only).
-- DINO-7, plan docs/plans/GROWTH_v1.0.md, ADR-001. Maths: ServerStorage.DinoArcade.GrowthCurve 1.1.
-- User: "next is leveling up"; answers: option C (20 levels in 4 stages, size only at stage-ups), XP from eating,
--   drinking, damage dealt and kills, a raptor killing a T-Rex gets "wayyy more xp" (size-ratio bonus on damage / kill
--   XP, x1..x10, never reduced), saved per species but session-only first (DataStore = DINO-10), death drops one
--   stage (5 levels), cheap hatchling levels, speed per stage 0.80 / 0.87 / 0.93 / 1.00.
-- Records: records[player][species] = {level, xp} for this server session (player attribute GrowthSaveState =
--   "session"). A new species record starts at level 1, XP 0.
-- Each character (CharacterAdded, also SpeciesServer's raptor body), once DinoHealthServer has set its max health
--   (attribute DinoMaxHealthSet, BASE_WAIT s at most):
--   * Adult base, captured before anything is written: GrowthBase_<key> for every GrowthCurve speed / strength /
--     distance key (the character's own value, else FALLBACK below = the default the reading script uses);
--     GrowthBaseMaxHealth = Humanoid.MaxHealth; GrowthBaseLength = largest GetExtentsSize() component / GetScale().
--   * Apply (spawn, level-up, stage-up): Model:ScaleTo(GrowthCurve.sizeOf) when it differs by more than 0.001 (the
--     client animator re-fits, IdleAnimation 1.24); every scaled attribute written; Humanoid.MaxHealth =
--     maxHealthOf(base, level); Health = MaxHealth at spawn, else the health fraction is kept; GrowthBodyLength =
--     base length x size.
-- XP (every TICK s, from attributes the existing scripts already publish; tunables are script attributes):
--   * eating: SurvivalFoodEaten increase x XpPerFood (1)
--   * drinking: SurvivalWaterDrunk increase x XpPerWater (0.5)
--   * damage: a new BiteHitAt on the character -> BiteHitDamage x XpPerDamage (1) x sizeRatioMul(target named by
--     BiteHitTarget); a new PounceBiteAt -> PounceHitDamage x XpPerDamage x sizeRatioMul(target named by
--     PounceLatchTarget)
--   * kills: a new KilledAt on a model in DinoIsland.Bots / DinoIsland.Prey / Workspace (top level) whose KilledBy is
--     a player's name -> (DummyMaxHealth or Humanoid.MaxHealth) x KillXpFraction (0.5) x sizeRatioMul
--   Target length: its GrowthBodyLength attribute, else its largest GetExtentsSize() component.
-- Death (Humanoid.Died): GrowthCurve.deathDrop on that species' record; player attributes GrowthDeathDrop
--   ("Lv a -> Lv b") and GrowthDeathDropAt (server time); the next character gets the new stage.
-- Off: script attribute GrowthEnabled = false -> every character gets its adult base back (scale 1, attributes, max
--   health) and no XP is counted (GrowthState "disabled"); true again -> re-applied. While off, the eat / drink / bite /
--   pounce baselines keep advancing, so nothing done while off is credited after re-enabling (measured in Play: 10 food
--   eaten while off was credited +10 XP before this rule).
-- Character attributes: GrowthLevel, GrowthStage (1-4), GrowthStageName, GrowthXP (exact), GrowthXPNext, GrowthSkillPoints
--   (= level - 1, banked), GrowthScale, GrowthLevelUpAt, GrowthStageUpAt, GrowthBodyLength, GrowthState ("waiting" /
--   "ready" / "disabled"), GrowthLastXp ("<source> +n"), GrowthXpTotal, GrowthApplied (level last applied).
-- Player attributes: GrowthSaveState ("session"), GrowthDeathDrop, GrowthDeathDropAt.
-- Script attributes: GrowthServerVersion, GrowthEnabled, XpPerFood, XpPerWater, XpPerDamage, KillXpFraction,
--   GrowthKillsCounted.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local TICK = 0.2
local BASE_WAIT = 5
local SCRIPT_DEFAULTS = {GrowthEnabled = true, XpPerFood = 1, XpPerWater = 0.5, XpPerDamage = 1, KillXpFraction = 0.5}
-- the default each reading script uses when the character has no value (so hatchlings scale those too)
local FALLBACK = {MoveWalkSpeed = 16, MoveRunSpeed = 28, MoveCreepSpeed = 10, BiteDamage = 25, BiteRange = 5,
	BiteReachBack = 8, BiteLungeDist = 3, EatRange = 8, EatHeight = 20, CameraStartZoom = 35}

local GC = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("GrowthCurve"))
local ALL_KEYS = {}
for _, list in ipairs({GC.SPEED_KEYS, GC.STRENGTH_KEYS, GC.DISTANCE_KEYS}) do
	for _, k in ipairs(list) do table.insert(ALL_KEYS, k) end
end

script:SetAttribute("GrowthServerVersion", VERSION)
for k, v in pairs(SCRIPT_DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function sget(k)
	local v = script:GetAttribute(k)
	if v == nil then v = SCRIPT_DEFAULTS[k] end
	return v
end
local function enabled() return sget("GrowthEnabled") ~= false end

local records = {} -- [player] = {[species] = {level, xp}}
local chars = {} -- [char] = state {player, species, hum, base, ready, lastFood, lastWater, lastBiteAt, lastPounceAt}

local function recordOf(player, species)
	records[player] = records[player] or {}
	local r = records[player][species]
	if not r then
		r = {level = 1, xp = 0}
		records[player][species] = r
	end
	return r
end

local function set(inst, k, v)
	if inst:GetAttribute(k) ~= v then inst:SetAttribute(k, v) end
end

local function largestExtent(model)
	local s = model:GetExtentsSize()
	return math.max(s.X, s.Y, s.Z)
end

local function bodyLength(model)
	local l = model:GetAttribute("GrowthBodyLength")
	if type(l) == "number" and l > 0 then return l end
	return largestExtent(model)
end

local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	local p = Players:FindFirstChild(name)
	if p and p:IsA("Player") and p.Character then return p.Character end
	local island = workspace:FindFirstChild("DinoIsland")
	for _, folderName in ipairs({"Bots", "Prey"}) do
		local f = island and island:FindFirstChild(folderName)
		local m = f and f:FindFirstChild(name)
		if m then return m end
	end
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") then return m end
	return nil
end

-- write the record's stage onto the character
local function apply(char, st, atSpawn)
	local r = recordOf(st.player, st.species)
	local level = r.level
	local size = GC.sizeOf(level)
	if math.abs(char:GetScale() - size) > 0.001 then char:ScaleTo(size) end
	for k, v in pairs(GC.scaledAttributes(st.base, level)) do set(char, k, v) end
	local hum = st.hum
	local oldMax = hum.MaxHealth
	local frac = oldMax > 0 and hum.Health / oldMax or 1
	local newMax = GC.maxHealthOf(st.baseMax, level)
	hum.MaxHealth = newMax
	hum.Health = atSpawn and newMax or math.clamp(frac * newMax, 0, newMax)
	set(char, "GrowthLevel", level)
	set(char, "GrowthStage", GC.stageOf(level))
	set(char, "GrowthStageName", GC.stageName(level))
	set(char, "GrowthXP", r.xp)
	set(char, "GrowthXPNext", GC.xpToNext(level))
	set(char, "GrowthSkillPoints", level - 1)
	set(char, "GrowthScale", size)
	set(char, "GrowthBodyLength", math.floor(st.baseLength * size * 100 + 0.5) / 100)
	set(char, "GrowthApplied", level)
	set(char, "GrowthState", "ready")
end

-- adult values back (growth off)
local function restore(char, st)
	if math.abs(char:GetScale() - 1) > 0.001 then char:ScaleTo(1) end
	for k, v in pairs(st.base) do set(char, k, v) end
	local hum = st.hum
	local frac = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	hum.MaxHealth = st.baseMax
	hum.Health = math.clamp(frac * st.baseMax, 0, st.baseMax)
	set(char, "GrowthBodyLength", st.baseLength)
	set(char, "GrowthState", "disabled")
end

local function giveXp(char, st, amount, source)
	if amount <= 0 or not enabled() or not st.ready then return end
	local r = recordOf(st.player, st.species)
	local oldLevel, oldStage = r.level, GC.stageOf(r.level)
	local level, xp, gained = GC.addXp(r.level, r.xp, amount)
	r.level, r.xp = level, xp
	set(char, "GrowthLastXp", ("%s +%s"):format(source, tostring(math.floor(amount * 10 + 0.5) / 10)))
	set(char, "GrowthXpTotal", (char:GetAttribute("GrowthXpTotal") or 0) + amount)
	if gained > 0 then
		local now = workspace:GetServerTimeNow()
		char:SetAttribute("GrowthLevelUpAt", now)
		if GC.stageOf(level) > oldStage then char:SetAttribute("GrowthStageUpAt", now) end
		apply(char, st, false)
	else
		set(char, "GrowthXP", xp)
	end
	if level ~= oldLevel then set(char, "GrowthXP", xp) end
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	set(char, "GrowthState", "waiting")
	-- adult base first, before DinoHealthServer / anything else is overwritten by this script
	local base = {}
	for _, k in ipairs(ALL_KEYS) do
		local v = char:GetAttribute(k)
		if type(v) ~= "number" then v = FALLBACK[k] end
		if type(v) == "number" then
			base[k] = v
			char:SetAttribute("GrowthBase_" .. k, v)
		end
	end
	local t0 = os.clock()
	while char.Parent and char:GetAttribute("DinoMaxHealthSet") == nil and os.clock() - t0 < BASE_WAIT do task.wait(0.1) end
	if not char.Parent then return end
	local species = char:GetAttribute("Species") or "TRex"
	local st = {player = player, species = species, hum = hum, base = base, baseMax = hum.MaxHealth,
		baseLength = largestExtent(char) / char:GetScale(), ready = false,
		lastFood = char:GetAttribute("SurvivalFoodEaten") or 0, lastWater = char:GetAttribute("SurvivalWaterDrunk") or 0,
		lastBiteAt = char:GetAttribute("BiteHitAt"), lastPounceAt = char:GetAttribute("PounceBiteAt")}
	char:SetAttribute("GrowthBaseMaxHealth", st.baseMax)
	char:SetAttribute("GrowthBaseLength", math.floor(st.baseLength * 100 + 0.5) / 100)
	chars[char] = st
	if enabled() then apply(char, st, true) else set(char, "GrowthState", "disabled") end
	st.ready = true
	hum.Died:Connect(function()
		if not enabled() then return end
		local r = recordOf(player, species)
		local from = r.level
		r.level, r.xp = GC.deathDrop(r.level, r.xp)
		player:SetAttribute("GrowthDeathDrop", ("Lv %d -> Lv %d"):format(from, r.level))
		player:SetAttribute("GrowthDeathDropAt", workspace:GetServerTimeNow())
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function onPlayer(player)
	player:SetAttribute("GrowthSaveState", "session")
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p) records[p] = nil end)

script:GetAttributeChangedSignal("GrowthEnabled"):Connect(function()
	for char, st in pairs(chars) do
		if st.ready and char.Parent then
			if enabled() then apply(char, st, false) else restore(char, st) end
		end
	end
end)

-- kills: KilledAt seen per model
local killSeen = setmetatable({}, {__mode = "k"})
local function scanKills(models)
	for _, m in ipairs(models) do
		if m:IsA("Model") then
			local at = m:GetAttribute("KilledAt")
			if type(at) == "number" and killSeen[m] ~= at then
				local first = killSeen[m] == nil and at < workspace:GetServerTimeNow() - 2 -- already dead before we looked
				killSeen[m] = at
				if not first then
					local killer = Players:FindFirstChild(tostring(m:GetAttribute("KilledBy")))
					local kc = killer and killer:IsA("Player") and killer.Character
					local st = kc and chars[kc]
					if st then
						local hp = m:GetAttribute("DummyMaxHealth")
						if type(hp) ~= "number" then
							local h = m:FindFirstChildOfClass("Humanoid")
							hp = h and h.MaxHealth or 0
						end
						local mul = GC.sizeRatioMul(bodyLength(m), bodyLength(kc))
						giveXp(kc, st, hp * sget("KillXpFraction") * mul, "kill")
						script:SetAttribute("GrowthKillsCounted", (script:GetAttribute("GrowthKillsCounted") or 0) + 1)
					end
				end
			end
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	acc = 0
	for char, st in pairs(chars) do
		if st.ready and char.Parent and enabled() then
			local food = char:GetAttribute("SurvivalFoodEaten") or 0
			if food > st.lastFood then giveXp(char, st, (food - st.lastFood) * sget("XpPerFood"), "eat") end
			st.lastFood = food
			local water = char:GetAttribute("SurvivalWaterDrunk") or 0
			if water > st.lastWater then giveXp(char, st, (water - st.lastWater) * sget("XpPerWater"), "drink") end
			st.lastWater = water
			local biteAt = char:GetAttribute("BiteHitAt")
			if biteAt ~= nil and biteAt ~= st.lastBiteAt then
				st.lastBiteAt = biteAt
				local target = findModel(char:GetAttribute("BiteHitTarget"))
				local mul = target and GC.sizeRatioMul(bodyLength(target), bodyLength(char)) or 1
				giveXp(char, st, (char:GetAttribute("BiteHitDamage") or 0) * sget("XpPerDamage") * mul, "bite")
			end
			local pAt = char:GetAttribute("PounceBiteAt")
			if pAt ~= nil and pAt ~= st.lastPounceAt then
				st.lastPounceAt = pAt
				local target = findModel(char:GetAttribute("PounceLatchTarget"))
				local mul = target and GC.sizeRatioMul(bodyLength(target), bodyLength(char)) or 1
				giveXp(char, st, (char:GetAttribute("PounceHitDamage") or 0) * sget("XpPerDamage") * mul, "pounce")
			end
		elseif st.ready and char.Parent then
			-- growth off: advance the baselines only (no XP)
			st.lastFood = char:GetAttribute("SurvivalFoodEaten") or 0
			st.lastWater = char:GetAttribute("SurvivalWaterDrunk") or 0
			st.lastBiteAt = char:GetAttribute("BiteHitAt")
			st.lastPounceAt = char:GetAttribute("PounceBiteAt")
		end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	for _, folderName in ipairs({"Bots", "Prey"}) do
		local f = island and island:FindFirstChild(folderName)
		if f then scanKills(f:GetChildren()) end
	end
	scanKills(workspace:GetChildren())
end)
