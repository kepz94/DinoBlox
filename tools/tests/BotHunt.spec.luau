-- BotHunt.spec v1.0 (Dino Arcade) — tests for ServerStorage.DinoArcade.BotHunt (DINO-30, plan docs/plans/BOTHUNT_v1.0.md).
-- Run in Studio Edit through execute_luau (copy in ServerStorage.DinoArcadeTools.BotHunt_spec); returns "PASS n" or "FAIL ...".
local ok, BH = pcall(function() return require(game.ServerStorage.DinoArcade.BotHunt) end)
if not ok then return "FAIL require: " .. tostring(BH) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function bot(id, species, pack, hp, grudge) return {kind = "bot", id = id, species = species, pack = pack, hpFrac = hp or 1, grudge = grudge} end
local prey = {kind = "prey", id = "Chicken_1", species = "Chicken"}
local rA1, rA2 = bot("R1", "Raptor", "Pack1"), bot("R2", "Raptor", "Pack1")
local rB = bot("R3", "Raptor", "Roam1")
local rLone = bot("R4", "Raptor", nil)
local t1, t2 = bot("T1", "TRex", nil), bot("T2", "TRex", nil)

eq("Version", BH.Version, "1.0")
-- rule table
eq("raptor -> prey", BH.hostile(rA1, prey), true)
eq("trex -> prey", BH.hostile(t1, prey), true)
eq("raptor -> same pack", BH.hostile(rA1, rA2), false)
eq("raptor -> other pack", BH.hostile(rA1, rB), true)
eq("raptor -> no-pack raptor", BH.hostile(rA1, rLone), true)
eq("raptor -> trex (no grudge)", BH.hostile(rA1, t1), false)
eq("raptor -> trex (grudge on it)", BH.hostile(bot("R1", "Raptor", "Pack1", 1, "T1"), t1), true)
eq("raptor -> other trex (grudge on T1)", BH.hostile(bot("R1", "Raptor", "Pack1", 1, "T1"), t2), false)
eq("trex -> raptor", BH.hostile(t1, rA1), true)
eq("trex -> trex", BH.hostile(t1, t2), true)
eq("self", BH.hostile(t1, t1), false)
eq("player not judged", BH.hostile(t1, {kind = "player", id = "P"}), false)
-- low health
eq("low raptor -> other pack", BH.hostile(bot("R1", "Raptor", "Pack1", 0.2), rB), false)
eq("low raptor -> prey", BH.hostile(bot("R1", "Raptor", "Pack1", 0.2), prey), true)
eq("low trex -> raptor", BH.hostile(bot("T1", "TRex", nil, 0.29), rA1), false)
eq("at 0.3 still fights", BH.hostile(bot("T1", "TRex", nil, 0.3), rA1), true)
eq("shouldFlee 0.29", BH.shouldFlee(0.29), true)
eq("shouldFlee 0.3", BH.shouldFlee(0.3), false)
-- nearest
local cands = {
	{desc = {kind = "player", id = "P"}, dist = 40, allowed = true},
	{desc = prey, dist = 30},
	{desc = rA2, dist = 10}, -- same pack: not hostile
}
eq("nearest = prey (player farther, packmate skipped)", BH.nearest(rA1, cands, 60), 2)
cands[1].dist = 20
eq("nearest = player when closer", BH.nearest(rA1, cands, 60), 1)
cands[1].allowed = false
eq("disallowed player skipped", BH.nearest(rA1, cands, 60), 2)
eq("out of sight", BH.nearest(rA1, {{desc = prey, dist = 61}}, 60), nil)
eq("tie keeps first", BH.nearest(t1, {{desc = rA1, dist = 20}, {desc = rB, dist = 20}}, 60), 1)
eq("none", BH.nearest(t1, {}, 60), nil)
-- regen
eq("regen before wait", BH.regen(10, 60, 9.9, 1), 10)
eq("regen after wait", BH.regen(10, 60, 10, 1), 10.6, 1e-9)
eq("regen capped", BH.regen(59.9, 60, 30, 1), 60)
eq("regen full", BH.regen(60, 60, 30, 1), 60)
if #fails > 0 then return "FAIL " .. #fails .. " (pass " .. passes .. ")\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
