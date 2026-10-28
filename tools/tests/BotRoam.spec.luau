-- BotRoam.spec v1.0 (Dino Arcade) — tests for ServerStorage.DinoArcade.BotRoam (DINO-28, plan docs/plans/ROAMING_v1.0.md).
-- Run in Studio Edit through execute_luau: paste this file's source; it requires the installed module and returns
-- "PASS n" or "FAIL ..." lines (no test runner in the repo; same pattern as the other specs). Uses fake height maps only.
local ok, BR = pcall(function() return require(game.ServerStorage.DinoArcade.BotRoam) end)
if not ok then return "FAIL require: " .. tostring(BR) end

local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function truthy(name, v) eq(name, v and true or false, true) end
local function flatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end

-- fake island: flat top 2 inside +/-1000 (wider than LIMIT 920, so the limit check is reached); a lake (nil) for 100 <= x <= 200; a cliff (top 30) for z >= 500;
-- west of x = -300 the ground is 2.5 higher (a step StepAssist can lift)
local function sample(x, z)
	if math.abs(x) > 1000 or math.abs(z) > 1000 then return nil end
	if x >= 100 and x <= 200 then return nil end
	if z >= 500 then return 30 end
	if x < -300 then return 4.5 end
	return 2
end
-- a 3.5-stud step at x = -300 instead
local function sampleHigh(x, z)
	if x < -300 then return 5.5 end
	return 2
end
-- water everywhere except a 60 x 60 islet
local function islet(x, z)
	if math.abs(x) <= 30 and math.abs(z) <= 30 then return 2 end
	return nil
end

eq("Version", BR.Version, "1.0")
eq("STEP", BR.STEP, 4)
eq("MAX_RISE", BR.MAX_RISE, 3)
-- pathOk
local okP, why = BR.pathOk(Vector3.new(0, 0, 0), Vector3.new(300, 0, 0), sample)
eq("across lake ok", okP, false) eq("across lake why", why, "water")
okP, why = BR.pathOk(Vector3.new(0, 0, 300), Vector3.new(0, 0, 600), sample)
eq("into cliff ok", okP, false) eq("into cliff why", why, "high")
okP, why = BR.pathOk(Vector3.new(-200, 0, 0), Vector3.new(-500, 0, 0), sample)
eq("2.5 step ok", okP, true) eq("2.5 step why", why, "ok")
okP, why = BR.pathOk(Vector3.new(-200, 0, 0), Vector3.new(-500, 0, 0), sampleHigh)
eq("3.5 step ok", okP, false) eq("3.5 step why", why, "rise")
okP = BR.pathOk(Vector3.new(-500, 0, 0), Vector3.new(-200, 0, 0), sampleHigh)
eq("3.5 step down ok", okP, true)
okP, why = BR.pathOk(Vector3.new(800, 0, -800), Vector3.new(950, 0, -800), sample)
eq("limit ok", okP, false) eq("limit why", why, "limit")
okP, why = BR.pathOk(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), sample)
eq("zero length", okP, true)
-- pickSpot
local from = Vector3.new(-500, 0, 0)
local p, tries = BR.pickSpot(Random.new(1), from, sample)
truthy("pick found", p)
if p then
	local d = flatDist(p, from)
	eq("pick dist >= 250", d >= 250, true)
	eq("pick dist <= 650", d <= 650, true)
	eq("pick not past lake", p.X < 100, true)
	eq("pick z < 500", p.Z < 500, true)
	eq("pick y = ground", p.Y, sample(p.X, p.Z))
	eq("pick path ok", (BR.pathOk(from, p, sample)), true)
end
local p2 = BR.pickSpot(Random.new(1), from, sample)
eq("same seed same spot", p2 and p and (p2 - p).Magnitude < 1e-6, true)
local none, t = BR.pickSpot(Random.new(5), Vector3.new(0, 0, 0), islet)
eq("boxed in nil", none, nil) eq("boxed in tries", t, 40)
local avoid = {{pos = Vector3.new(-500, 0, 300), dist = 250}}
local allFar = true
for seed = 1, 10 do
	local q = BR.pickSpot(Random.new(seed), from, sample, {avoid = avoid})
	if q and flatDist(q, avoid[1].pos) < 250 then allFar = false end
end
eq("avoid respected (10 seeds)", allFar, true)
-- respawnSpot
local players = {Vector3.new(0, 0, 0)}
local farOk = true
for seed = 1, 10 do
	local r = BR.respawnSpot(Random.new(seed), sample, players, {avoid = {{pos = Vector3.new(400, 0, 0), dist = 250}}})
	if not r or flatDist(r, players[1]) < 150 or flatDist(r, Vector3.new(400, 0, 0)) < 250 or not BR.groundOk(sample(r.X, r.Z)) then farOk = false end
end
eq("respawn >= 150 from players, >= 250 from avoid, dry (10 seeds)", farOk, true)
eq("respawn on islet with player on it", BR.respawnSpot(Random.new(3), islet, {Vector3.new(0, 0, 0)}), nil)
eq("groundOk nil", BR.groundOk(nil), false)
eq("groundOk 20", BR.groundOk(20), true)
eq("groundOk 21", BR.groundOk(21), false)
eq("groundOk -1", BR.groundOk(-1), false)

if #fails > 0 then return "FAIL " .. #fails .. " (pass " .. passes .. ")\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
