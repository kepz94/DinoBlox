-- GoalServer v1.0 (Dino Arcade) — goals: 3 goals per player per species (session only), counted from attributes the game
--   already publishes, paid as XP through GrowthServer 1.2 (character GoalXpEarned), replaced when done.
-- DINO-20, plan docs/plans/GOALS_v1.0.md (deterministic map), ADR-003. Pool / rewards / pick / carry: ServerStorage.DinoArcade.GoalDefs 1.0.
-- User: "makes the game boring off the bat ... freely running around unless i walk into range of a bot dinosaur"; answers:
--   option A (3 goals listed, any order), pool as shown, on death keep the goals that still fit.
-- Records: records[player][species] = {species, stage, slots = {{id, have, doneAt}}, used}. Session only (saving = DINO-10).
-- Every TICK s, per player character:
--   * GoalsEnabled false -> GoalState "disabled", slot attributes removed, baselines follow (nothing done while off counts).
--   * GrowthState not "ready" -> GoalState "waiting" ("paused" when GrowthState is "disabled"); baselines follow.
--   * ready -> GoalState "running". First time for the species: GoalDefs.nextGoal fills 3 slots. GrowthStage differs from the
--     record's stage (stage-up, or the death drop on the next character) -> GoalDefs.carry keeps the slots still in the new
--     pool (progress kept), the rest are refilled; GoalLastEvent "stage a->b kept n". Same stage on respawn: unchanged.
--   * Progress (open slots only, have = min(need, have + amount)):
--       eat   - SurvivalFoodEaten increase;  drink - SurvivalWaterDrunk increase;  roar - RoarCount increase;
--       bites - each new BiteHitAt;  damage - BiteHitDamage of each new BiteHitAt + PounceHitDamage of each new PounceBiteAt;
--       hide  - whole seconds of Hidden = true in a row (0 again when Hidden goes false);
--       kill  - a new KilledAt on a model in DinoIsland.Bots / DinoIsland.Prey whose KilledBy is this player's name and that
--               GoalDefs.matchKill accepts (IsPrey, PreyKind, BotSpecies, KilledWith); a KilledAt already older than
--               KILL_LATE s when first seen is ignored (as GrowthServer). A counter that went down (reset at spawn) only
--               moves the baseline.
--   * Done (have >= need): Goal<i>Done true, Goal<i>DoneAt = server time; the character's GoalXpEarned += GoalDefs.reward(
--     size, GrowthLevel); GoalsCompleted + 1, GoalLastDone "<text> +n", GoalLastDoneAt. GoalReplaceDelay s later the slot gets
--     GoalDefs.nextGoal with the finished goal still counted as on screen (so another goal comes first); when nothing else
--     is left the same goal comes back. The replace runs on the record, also when the character died meanwhile.
--   * Goal<i>Xp = GoalDefs.reward(size, current GrowthLevel), rewritten when the level changes.
-- Player attributes: GoalState ("waiting" / "running" / "paused" / "disabled"), GoalStageName, Goal<i>Id / Text / Have / Need /
--   Xp / Size / Done / DoneAt (i = 1..3), GoalsCompleted, GoalLastDone, GoalLastDoneAt, GoalLastEvent.
-- Character attribute: GoalXpEarned (cumulative, read by GrowthServer 1.2).
-- Script attributes: GoalServerVersion, GoalsEnabled (default true), GoalReplaceDelay (default 2.5), GoalCompletedTotal.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local TICK = 0.2
local KILL_LATE = 2
local SCRIPT_DEFAULTS = {GoalsEnabled = true, GoalReplaceDelay = 2.5}
local SLOT_KEYS = {"Id", "Text", "Have", "Need", "Xp", "Size", "Done", "DoneAt"}

local GD = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("GoalDefs"))

script:SetAttribute("GoalServerVersion", VERSION)
for k, v in pairs(SCRIPT_DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("GoalCompletedTotal", script:GetAttribute("GoalCompletedTotal") or 0)
local function sget(k)
	local v = script:GetAttribute(k)
	if v == nil then v = SCRIPT_DEFAULTS[k] end
	return v
end
local function enabled() return sget("GoalsEnabled") ~= false end

local records = {} -- [player] = {[species] = rec}
local chars = {} -- [char] = {player, base = {...}, hideSince, kills = {}}
local current = {} -- [player] = {char, rec} the record shown on the player's attributes

local function setP(inst, k, v)
	if inst:GetAttribute(k) ~= v then inst:SetAttribute(k, v) end
end

local function recordOf(player, species)
	records[player] = records[player] or {}
	local r = records[player][species]
	if not r then
		r = {species = species, stage = nil, slots = {}, used = {}}
		records[player][species] = r
	end
	return r
end

local function onScreen(rec, extraId)
	local t = {}
	for _, s in ipairs(rec.slots) do t[s.id] = true end
	if extraId then t[extraId] = true end
	return t
end

local function fill(rec)
	while #rec.slots < GD.SLOTS do
		local def
		def, rec.used = GD.nextGoal(rec.stage, rec.species, onScreen(rec), rec.used)
		if not def then break end
		table.insert(rec.slots, {id = def.id, have = 0})
	end
end

local function clearSlots(player)
	for i = 1, GD.SLOTS do
		for _, k in ipairs(SLOT_KEYS) do
			if player:GetAttribute("Goal" .. i .. k) ~= nil then player:SetAttribute("Goal" .. i .. k, nil) end
		end
	end
	if player:GetAttribute("GoalStageName") ~= nil then player:SetAttribute("GoalStageName", nil) end
end

local function writeSlots(player, rec, char)
	local level = char and char:GetAttribute("GrowthLevel") or 1
	for i = 1, GD.SLOTS do
		local s = rec.slots[i]
		local def = s and GD.byId(s.id)
		local p = "Goal" .. i
		if def then
			setP(player, p .. "Id", def.id)
			setP(player, p .. "Text", def.text)
			setP(player, p .. "Have", s.have)
			setP(player, p .. "Need", def.need)
			setP(player, p .. "Xp", GD.reward(def.size, level))
			setP(player, p .. "Size", def.size)
			setP(player, p .. "Done", s.doneAt ~= nil)
			setP(player, p .. "DoneAt", s.doneAt)
		else
			for _, k in ipairs(SLOT_KEYS) do
				if player:GetAttribute(p .. k) ~= nil then player:SetAttribute(p .. k, nil) end
			end
		end
	end
	if char then setP(player, "GoalStageName", char:GetAttribute("GrowthStageName")) end
end

local function isShown(player, rec)
	local c = current[player]
	return c and c.rec == rec and enabled() and player:GetAttribute("GoalState") == "running"
end

local function replace(player, rec, slot)
	local i = table.find(rec.slots, slot)
	if not i then return end -- carried away by a stage change meanwhile
	local others = {}
	for k, s in ipairs(rec.slots) do
		if k ~= i then others[s.id] = true end
	end
	local withDone = table.clone(others)
	withDone[slot.id] = true -- the finished goal counts as on screen: another goal comes first
	local def, used = GD.nextGoal(rec.stage, rec.species, withDone, rec.used)
	if not def then def, used = GD.nextGoal(rec.stage, rec.species, others, rec.used) end -- nothing else left: it comes back
	rec.used = used
	if def then
		rec.slots[i] = {id = def.id, have = 0}
	else
		table.remove(rec.slots, i)
	end
	setP(player, "GoalLastEvent", ("replace %s -> %s"):format(slot.id, def and def.id or "none"))
	if isShown(player, rec) then writeSlots(player, rec, current[player].char) end
end

local function complete(player, rec, slot, char)
	local def = GD.byId(slot.id)
	local now = workspace:GetServerTimeNow()
	slot.doneAt = now
	local xp = GD.reward(def.size, char:GetAttribute("GrowthLevel") or 1)
	char:SetAttribute("GoalXpEarned", (char:GetAttribute("GoalXpEarned") or 0) + xp)
	player:SetAttribute("GoalsCompleted", (player:GetAttribute("GoalsCompleted") or 0) + 1)
	player:SetAttribute("GoalLastDone", ("%s +%d"):format(def.text, xp))
	player:SetAttribute("GoalLastDoneAt", now)
	player:SetAttribute("GoalLastEvent", ("done %s +%d"):format(def.id, xp))
	script:SetAttribute("GoalCompletedTotal", (script:GetAttribute("GoalCompletedTotal") or 0) + 1)
	task.delay(sget("GoalReplaceDelay"), replace, player, rec, slot)
end

local function readBase(char)
	return {
		food = char:GetAttribute("SurvivalFoodEaten") or 0,
		water = char:GetAttribute("SurvivalWaterDrunk") or 0,
		roar = char:GetAttribute("RoarCount") or 0,
		biteAt = char:GetAttribute("BiteHitAt"),
		pounceAt = char:GetAttribute("PounceBiteAt"),
	}
end

local function onCharacter(player, char)
	chars[char] = {player = player, base = readBase(char), hideSince = nil, kills = {}}
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function onPlayer(player)
	player:SetAttribute("GoalState", "waiting")
	player:SetAttribute("GoalsCompleted", player:GetAttribute("GoalsCompleted") or 0)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then onCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	records[p] = nil
	current[p] = nil
end)

script:GetAttributeChangedSignal("GoalsEnabled"):Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if not enabled() then
			clearSlots(player)
			setP(player, "GoalState", "disabled")
		end
	end
end)

-- kills: KilledAt seen per model; credited to the killer's current character
local killSeen = setmetatable({}, {__mode = "k"})
local function scanKills(folder, now)
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") then
			local at = m:GetAttribute("KilledAt")
			if type(at) == "number" and killSeen[m] ~= at then
				local late = killSeen[m] == nil and at < now - KILL_LATE
				killSeen[m] = at
				if not late then
					local killer = Players:FindFirstChild(tostring(m:GetAttribute("KilledBy")))
					local kc = killer and killer:IsA("Player") and killer.Character
					local st = kc and chars[kc]
					if st then
						table.insert(st.kills, {isPrey = m:GetAttribute("IsPrey") == true, preyKind = m:GetAttribute("PreyKind"),
							botSpecies = m:GetAttribute("BotSpecies"), with = m:GetAttribute("KilledWith"), name = m.Name})
					end
				end
			end
		end
	end
end

local function delta(st, key, value)
	local d = value - st.base[key]
	st.base[key] = value
	return d > 0 and d or 0
end

local function stepChar(char, st, now)
	local player = st.player
	local base = st.base
	local food = delta(st, "food", char:GetAttribute("SurvivalFoodEaten") or 0)
	local water = delta(st, "water", char:GetAttribute("SurvivalWaterDrunk") or 0)
	local roar = delta(st, "roar", char:GetAttribute("RoarCount") or 0)
	local bites, damage = 0, 0
	local biteAt = char:GetAttribute("BiteHitAt")
	if biteAt ~= nil and biteAt ~= base.biteAt then
		base.biteAt = biteAt
		bites = 1
		damage += char:GetAttribute("BiteHitDamage") or 0
	end
	local pAt = char:GetAttribute("PounceBiteAt")
	if pAt ~= nil and pAt ~= base.pounceAt then
		base.pounceAt = pAt
		damage += char:GetAttribute("PounceHitDamage") or 0
	end
	local hidden = char:GetAttribute("Hidden") == true
	if hidden then st.hideSince = st.hideSince or now else st.hideSince = nil end
	local kills = st.kills
	st.kills = {}

	if not enabled() then
		setP(player, "GoalState", "disabled")
		return
	end
	local gState = char:GetAttribute("GrowthState")
	if gState ~= "ready" then
		setP(player, "GoalState", gState == "disabled" and "paused" or "waiting")
		return
	end
	local stage = char:GetAttribute("GrowthStage") or 1
	local rec = recordOf(player, char:GetAttribute("Species") or "TRex")
	if rec.stage == nil then
		rec.stage = stage
		fill(rec)
		setP(player, "GoalLastEvent", ("fill %s stage %d"):format(rec.species, stage))
	elseif rec.stage ~= stage then
		local from = rec.stage
		local kept, n = GD.carry(rec.slots, stage, rec.species)
		rec.slots = kept
		rec.stage = stage
		rec.used = {}
		for _, s in ipairs(kept) do rec.used[s.id] = true end
		fill(rec)
		setP(player, "GoalLastEvent", ("stage %d->%d kept %d"):format(from, stage, n))
	end
	local cur = current[player]
	if not cur or cur.char ~= char or cur.rec ~= rec then current[player] = {char = char, rec = rec} end
	setP(player, "GoalState", "running")

	local hideSecs = st.hideSince and math.floor(now - st.hideSince) or 0
	for _, slot in ipairs(rec.slots) do
		if slot.doneAt == nil then
			local def = GD.byId(slot.id)
			local add = 0
			if def.kind == "eat" then add = food
			elseif def.kind == "drink" then add = water
			elseif def.kind == "roar" then add = roar
			elseif def.kind == "bites" then add = bites
			elseif def.kind == "damage" then add = damage
			elseif def.kind == "kill" then
				for _, k in ipairs(kills) do
					if GD.matchKill(def, k) then add += 1 end
				end
			end
			if def.kind == "hide" then
				slot.have = math.min(def.need, hideSecs)
			elseif add > 0 then
				slot.have = math.min(def.need, slot.have + add)
				setP(player, "GoalLastEvent", ("%s +%s"):format(def.id, tostring(math.floor(add * 10 + 0.5) / 10)))
			end
			if slot.have >= def.need then complete(player, rec, slot, char) end
		end
	end
	writeSlots(player, rec, char)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	acc = 0
	local now = workspace:GetServerTimeNow()
	local island = workspace:FindFirstChild("DinoIsland")
	scanKills(island and island:FindFirstChild("Bots"), now)
	scanKills(island and island:FindFirstChild("Prey"), now)
	for char, st in pairs(chars) do
		if char.Parent and st.player.Parent then
			local ok, err = pcall(stepChar, char, st, os.clock())
			if not ok then warn("GoalServer: " .. tostring(err)) end
		end
	end
end)
