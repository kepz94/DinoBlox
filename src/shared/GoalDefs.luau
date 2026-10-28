-- GoalDefs v1.0 (Dino Arcade) — goals: the pool per growth stage and species, the XP reward maths and the pick / carry rules.
-- DINO-18, plan docs/plans/GOALS_v1.0.md, ADR-003. Pure: no instances (requires GrowthCurve only). GoalServer 1.0 uses it.
-- User: "makes the game boring off the bat"; answers: goals first, option A (3 goals listed, any order), pool as shown in
--   docs/mockups/goals_options.html, on death keep the goals that still fit.
-- POOL[stage] (pick order) = {id, text, kind, need, size, who, filter}:
--   kind "kill" (filter: prey = list of PreyKind or "any"; bot = BotSpecies of a non-prey bot; with = KilledWith),
--   "eat" (food points), "drink" (water points), "bites" (hits), "damage" (bite + pounce damage), "roar" (roars),
--   "hide" (seconds hidden in a row). who = "both" / "TRex" / "Raptor".
-- reward(size, level) = floor(SHARES[size] x GrowthCurve.xpToNext(min(level, 19)) + 0.5): s 0.35, m 0.6, b 1 (a whole level).
-- nextGoal(stage, species, onScreen, used): the first goal in pool order that is neither on screen nor used; when every
--   one not on screen is used, used is cleared and the first not on screen is taken (so a finished goal comes back only
--   after the rest of the pool). Returns def (nil when every pool goal is on screen) and the updated used set.
-- carry(slots, stage, species): the slots whose id is in the new pool, progress kept (stage change / death drop).
local ServerStorage = game:GetService("ServerStorage")
local GC = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("GrowthCurve"))

local GoalDefs = {}
GoalDefs.Version = "1.0"
GoalDefs.SLOTS = 3
GoalDefs.SHARES = {s = 0.35, m = 0.6, b = 1}

local SNACKS = {"Chicken", "Crab"}
GoalDefs.POOL = {
	[1] = {
		{id = "h_snack", text = "Catch 2 chickens or crabs", kind = "kill", need = 2, size = "m", who = "both", filter = {prey = SNACKS}},
		{id = "h_eat", text = "Eat 25 food", kind = "eat", need = 25, size = "s", who = "both"},
		{id = "h_drink", text = "Drink 25 water", kind = "drink", need = 25, size = "s", who = "both"},
		{id = "h_hide", text = "Hide in a bush or tall grass for 10 s", kind = "hide", need = 10, size = "s", who = "both"},
		{id = "h_pounce", text = "Pounce-kill a chicken or crab", kind = "kill", need = 1, size = "m", who = "Raptor",
			filter = {prey = SNACKS, with = "pounce"}},
	},
	[2] = {
		{id = "j_compy", text = "Catch 3 compies", kind = "kill", need = 3, size = "m", who = "both", filter = {prey = {"Compy"}}},
		{id = "j_bites", text = "Land 5 bites", kind = "bites", need = 5, size = "s", who = "both"},
		{id = "j_eat", text = "Eat 50 food", kind = "eat", need = 50, size = "s", who = "both"},
		{id = "j_drink", text = "Drink 50 water", kind = "drink", need = 50, size = "s", who = "both"},
		{id = "j_roar", text = "Roar 3 times", kind = "roar", need = 3, size = "s", who = "TRex"},
	},
	[3] = {
		{id = "s_raptor", text = "Down a raptor", kind = "kill", need = 1, size = "b", who = "both", filter = {bot = "Raptor"}},
		{id = "s_damage", text = "Deal 150 bite damage", kind = "damage", need = 150, size = "m", who = "both"},
		{id = "s_prey", text = "Catch 5 prey", kind = "kill", need = 5, size = "m", who = "both", filter = {prey = "any"}},
	},
	[4] = {
		{id = "a_raptors", text = "Down 3 raptors", kind = "kill", need = 3, size = "b", who = "TRex", filter = {bot = "Raptor"}},
		{id = "a_trex", text = "Down the T-Rex", kind = "kill", need = 1, size = "b", who = "Raptor", filter = {bot = "TRex"}},
		{id = "a_damage", text = "Deal 300 bite damage", kind = "damage", need = 300, size = "m", who = "both"},
		{id = "a_eat", text = "Eat 100 food", kind = "eat", need = 100, size = "s", who = "both"},
	},
}

local BY_ID = {}
for _, list in pairs(GoalDefs.POOL) do
	for _, d in ipairs(list) do BY_ID[d.id] = d end
end

function GoalDefs.byId(id)
	return BY_ID[id]
end

function GoalDefs.poolFor(stage, species)
	local out = {}
	for _, d in ipairs(GoalDefs.POOL[stage] or {}) do
		if d.who == "both" or d.who == species then table.insert(out, d) end
	end
	return out
end

function GoalDefs.reward(size, level)
	local share = GoalDefs.SHARES[size] or 0
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, 19)
	return math.floor(share * GC.xpToNext(lv) + 0.5)
end

function GoalDefs.nextGoal(stage, species, onScreen, used)
	onScreen = onScreen or {}
	used = used or {}
	local pool = GoalDefs.poolFor(stage, species)
	for _, d in ipairs(pool) do
		if not onScreen[d.id] and not used[d.id] then
			used[d.id] = true
			return d, used
		end
	end
	for _, d in ipairs(pool) do
		if not onScreen[d.id] then
			used = {[d.id] = true}
			return d, used
		end
	end
	return nil, used
end

function GoalDefs.carry(slots, stage, species)
	local inPool = {}
	for _, d in ipairs(GoalDefs.poolFor(stage, species)) do inPool[d.id] = true end
	local kept = {}
	for _, s in ipairs(slots or {}) do
		if s and inPool[s.id] then table.insert(kept, s) end
	end
	return kept, #kept
end

function GoalDefs.matchKill(def, info)
	if not def or def.kind ~= "kill" or not info then return false end
	local f = def.filter or {}
	if f.with and info.with ~= f.with then return false end
	if f.prey then
		if info.isPrey ~= true then return false end
		if f.prey == "any" then return true end
		for _, k in ipairs(f.prey) do
			if info.preyKind == k then return true end
		end
		return false
	end
	if f.bot then
		return info.isPrey ~= true and info.botSpecies == f.bot
	end
	return false
end

return GoalDefs
