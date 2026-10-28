-- GoalDefs.spec v1.0 (Dino Arcade) — tests for ServerStorage.DinoArcade.GoalDefs (DINO-18, plan docs/plans/GOALS_v1.0.md).
-- Run in Studio Edit through execute_luau: paste this file's source; it requires the installed module and returns
-- "PASS n" or "FAIL ..." lines. No test runner exists in the repo, so this is the Logic-mode check (as GrowthCurve.spec).
local ok, GD = pcall(function() return require(game.ServerStorage.DinoArcade.GoalDefs) end)
if not ok then return "FAIL require: " .. tostring(GD) end

local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function ids(list)
	local t = {}
	for _, d in ipairs(list) do table.insert(t, d.id) end
	return table.concat(t, ",")
end
local function set(list)
	local t = {}
	for _, k in ipairs(list) do t[k] = true end
	return t
end

eq("Version", GD.Version, "1.0")
eq("SLOTS", GD.SLOTS, 3)
-- pool sizes per stage / species
eq("pool 1 TRex", #GD.poolFor(1, "TRex"), 4)
eq("pool 1 Raptor", #GD.poolFor(1, "Raptor"), 5)
eq("pool 2 TRex", #GD.poolFor(2, "TRex"), 5)
eq("pool 2 Raptor", #GD.poolFor(2, "Raptor"), 4)
eq("pool 3 TRex", #GD.poolFor(3, "TRex"), 3)
eq("pool 3 Raptor", #GD.poolFor(3, "Raptor"), 3)
eq("pool 4 TRex", #GD.poolFor(4, "TRex"), 3)
eq("pool 4 Raptor", #GD.poolFor(4, "Raptor"), 3)
eq("pool 1 TRex order", ids(GD.poolFor(1, "TRex")), "h_snack,h_eat,h_drink,h_hide")
eq("pool 2 Raptor order", ids(GD.poolFor(2, "Raptor")), "j_compy,j_bites,j_eat,j_drink")
eq("pool 4 Raptor order", ids(GD.poolFor(4, "Raptor")), "a_trex,a_damage,a_eat")
eq("pool 5 empty", #GD.poolFor(5, "TRex"), 0)
-- rewards
eq("reward s 1", GD.reward("s", 1), 5)
eq("reward m 2", GD.reward("m", 2), 12)
eq("reward b 17", GD.reward("b", 17), 280)
eq("reward b 20", GD.reward("b", 20), 310)
eq("reward m 6", GD.reward("m", 6), 69)
-- byId
eq("byId h_hide need", GD.byId("h_hide") and GD.byId("h_hide").need, 10)
eq("byId missing", GD.byId("nope"), nil)
-- nextGoal
local d, used = GD.nextGoal(1, "TRex", {}, {})
eq("next empty", d and d.id, "h_snack")
eq("next empty marks used", used.h_snack, true)
d = GD.nextGoal(1, "TRex", set({"h_snack", "h_eat", "h_drink"}), set({"h_snack", "h_eat", "h_drink"}))
eq("next 4th", d and d.id, "h_hide")
d, used = GD.nextGoal(1, "TRex", set({"h_eat", "h_drink", "h_hide"}), set({"h_snack", "h_eat", "h_drink", "h_hide"}))
eq("next wrap", d and d.id, "h_snack")
eq("next wrap clears used (h_eat)", used.h_eat, nil)
eq("next wrap marks used", used.h_snack, true)
d = GD.nextGoal(3, "TRex", set({"s_raptor", "s_damage", "s_prey"}), {})
eq("next all on screen", d, nil)
-- carry
local kept, n = GD.carry({{id = "h_eat", have = 10}, {id = "h_snack", have = 1}, {id = "h_hide", have = 0}}, 2, "TRex")
eq("carry hatchling->juvenile n", n, 0)
eq("carry hatchling->juvenile list", #kept, 0)
kept, n = GD.carry({{id = "s_damage", have = 40}}, 4, "TRex")
eq("carry s_damage->adult", n, 0)
kept, n = GD.carry({{id = "a_damage", have = 40}}, 4, "Raptor")
eq("carry a_damage n", n, 1)
eq("carry a_damage have", kept[1] and kept[1].have, 40)
kept, n = GD.carry({{id = "j_roar", have = 2}}, 2, "Raptor")
eq("carry j_roar to Raptor", n, 0)
-- matchKill
local P = function(kind, with) return {isPrey = true, preyKind = kind, botSpecies = kind, with = with or "bite"} end
local B = function(sp) return {isPrey = false, botSpecies = sp, with = "bite"} end
eq("h_snack Crab", GD.matchKill(GD.byId("h_snack"), P("Crab")), true)
eq("h_snack Chicken", GD.matchKill(GD.byId("h_snack"), P("Chicken")), true)
eq("h_snack Compy", GD.matchKill(GD.byId("h_snack"), P("Compy")), false)
eq("h_pounce bite", GD.matchKill(GD.byId("h_pounce"), P("Chicken", "bite")), false)
eq("h_pounce pounce", GD.matchKill(GD.byId("h_pounce"), P("Chicken", "pounce")), true)
eq("s_raptor bot", GD.matchKill(GD.byId("s_raptor"), B("Raptor")), true)
eq("s_raptor prey", GD.matchKill(GD.byId("s_raptor"), P("Compy")), false)
eq("s_prey any", GD.matchKill(GD.byId("s_prey"), P("Crab")), true)
eq("s_prey bot", GD.matchKill(GD.byId("s_prey"), B("Raptor")), false)
eq("a_trex", GD.matchKill(GD.byId("a_trex"), B("TRex")), true)
eq("a_trex raptor", GD.matchKill(GD.byId("a_trex"), B("Raptor")), false)
eq("eat goal not a kill", GD.matchKill(GD.byId("h_eat"), P("Crab")), false)

if #fails > 0 then return "FAIL " .. #fails .. " (pass " .. passes .. ")\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
