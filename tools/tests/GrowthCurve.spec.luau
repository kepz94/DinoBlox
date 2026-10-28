-- GrowthCurve.spec v1.1 (Dino Arcade) — tests for ServerStorage.DinoArcade.GrowthCurve (DINO-5).
-- Run in Studio Edit through execute_luau: paste this file's source; it requires the installed module and returns
-- "PASS n" or "FAIL ..." lines. No test runner exists in the repo, so this is the Logic-mode check.
local ok, GC = pcall(function() return require(game.ServerStorage.DinoArcade.GrowthCurve) end)
if not ok then return "FAIL require: " .. tostring(GC) end

local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then
		good = math.abs(got - want) <= (tol or 1e-9)
	else
		good = got == want
	end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function tuple(name, want, ...)
	local got = {...}
	for i, w in ipairs(want) do eq(name .. "[" .. i .. "]", got[i], w) end
end

eq("Version", GC.Version, "1.1")
eq("MAX_LEVEL", GC.MAX_LEVEL, 20)
eq("xpToNext(1)", GC.xpToNext(1), 15)
eq("xpToNext(5)", GC.xpToNext(5), 35)
eq("xpToNext(6)", GC.xpToNext(6), 115)
eq("xpToNext(19)", GC.xpToNext(19), 310)
eq("xpToNext(20)", GC.xpToNext(20), 0)
local sum, sum5 = 0, 0
for l = 1, 19 do sum += GC.xpToNext(l) end
for l = 1, 5 do sum5 += GC.xpToNext(l) end
eq("sum 1..19", sum, 3100)
eq("sum 1..5", sum5, 125)
eq("stageOf(5)", GC.stageOf(5), 1)
eq("stageOf(6)", GC.stageOf(6), 2)
eq("stageOf(20)", GC.stageOf(20), 4)
eq("sizeOf(1)", GC.sizeOf(1), 0.4)
eq("sizeOf(16)", GC.sizeOf(16), 1)
eq("strengthOf(1)", GC.strengthOf(1), 0.4)
eq("strengthOf(20)", GC.strengthOf(20), 1)
eq("speedOf(6)", GC.speedOf(6), 0.87)
tuple("addXp(1,0,40)", {3, 5, 2}, GC.addXp(1, 0, 40))
tuple("addXp(1,30,500)", {9, 15, 8}, GC.addXp(1, 30, 500))
tuple("addXp(20,0,999)", {20, 0, 0}, GC.addXp(20, 0, 999))
tuple("deathDrop(13,50)", {8, 50}, GC.deathDrop(13, 50))
tuple("deathDrop(3,10)", {1, 10}, GC.deathDrop(3, 10))
tuple("deathDrop(8,200)", {3, 24}, GC.deathDrop(8, 200))
eq("sizeRatioMul(40.1,12.85)", GC.sizeRatioMul(40.1, 12.85), 3.12, 0.01)
eq("sizeRatioMul(12.85,40.1)", GC.sizeRatioMul(12.85, 40.1), 1)
eq("sizeRatioMul(500,1)", GC.sizeRatioMul(500, 1), 10)
eq("sizeRatioMul(0,5)", GC.sizeRatioMul(0, 5), 1)
eq("maxHealthOf(200,1)", GC.maxHealthOf(200, 1), 80)
eq("maxHealthOf(200,20)", GC.maxHealthOf(200, 20), 200)
local sa = GC.scaledAttributes({BiteDamage = 25, BiteRange = 5, MoveRunSpeed = 52, Unrelated = 7}, 1)
eq("scaled BiteDamage", sa.BiteDamage, 10)
eq("scaled BiteRange (v1.1: not scaled)", sa.BiteRange, nil)
eq("scaled MoveRunSpeed", sa.MoveRunSpeed, 41.6, 1e-6)
eq("scaled skips unknown", sa.Unrelated, nil)
eq("scaled skips missing", sa.PounceDistance, nil)

if #fails > 0 then return "FAIL " .. #fails .. " / " .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
