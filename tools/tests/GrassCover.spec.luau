-- GrassCover.spec v1.0 (Dino Arcade) — tests for ServerStorage.DinoArcade.GrassCover (DINO-24, plan docs/plans/AMBUSH_v1.0.md).
-- Run in Studio Edit through execute_luau: paste this file's source; it requires the installed module and returns
-- "PASS n" or "FAIL ..." lines (no test runner in the repo; same pattern as GrowthCurve.spec / GoalDefs.spec).
local ok, GC = pcall(function() return require(game.ServerStorage.DinoArcade.GrassCover) end)
if not ok then return "FAIL require: " .. tostring(GC) end

local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function chk(name, patches, pos, species, scale, creeping, wHidden, wReason, wHeight, wHint)
	local h, r, height, hint = GC.check(patches, pos, species, scale, creeping)
	eq(name .. " hidden", h, wHidden)
	eq(name .. " reason", r, wReason)
	if wHeight ~= nil then eq(name .. " height", height, wHeight) end
	if wHint ~= nil then eq(name .. " hint", hint, wHint) end
end

eq("Version", GC.Version, "1.0")
eq("DEFAULT_HEIGHT", GC.DEFAULT_HEIGHT, 17)
eq("EDGE", GC.EDGE, 4)
eq("MARGIN", GC.MARGIN, 0.5)
-- top
eq("top TRex 1 stand", GC.top("TRex", 1, false), 20)
eq("top TRex 1 creep", GC.top("TRex", 1, true), 14)
eq("top TRex 0.6 stand", GC.top("TRex", 0.6, false), 12)
eq("top TRex 0.6 creep", GC.top("TRex", 0.6, true), 8.4)
eq("top Raptor 1 stand", GC.top("Raptor", 1, false), 5.5)
eq("top Raptor 1 creep", GC.top("Raptor", 1, true), 3.3)
eq("top unknown", GC.top("Compy", 1, false), 20)
eq("top nil scale", GC.top("TRex", nil, false), 20)
-- patches
local A = GC.patch(CFrame.new(0, 0, 0), Vector3.new(30, 25, 30), 17)
local B = GC.patch(CFrame.new(100, 0, 0), Vector3.new(20, 12, 20), 10)
eq("patch half X", A.half.X, 15.5)
eq("patch default height", GC.patch(CFrame.new(), Vector3.new(2, 2, 2)).height, 17)
local P = {A, B}
chk("adult stand origin", P, Vector3.new(0, 0, 0), "TRex", 1, false, false, "tooTall", 17, true)
chk("adult creep origin", P, Vector3.new(0, 0, 0), "TRex", 1, true, true, "inside", 17)
chk("adult creep edge 18", P, Vector3.new(18, 0, 0), "TRex", 1, true, true, "edge", 17)
chk("adult stand edge 18", P, Vector3.new(18, 0, 0), "TRex", 1, false, false, "open", nil, true)
chk("adult creep 22", P, Vector3.new(22, 0, 0), "TRex", 1, true, false, "open", nil, false)
chk("adult stand 22", P, Vector3.new(22, 0, 0), "TRex", 1, false, false, "open", nil, false)
chk("juvenile stand short", P, Vector3.new(100, 0, 0), "TRex", 0.6, false, false, "tooTall", 10, true)
chk("juvenile creep short", P, Vector3.new(100, 0, 0), "TRex", 0.6, true, true, "inside", 10)
chk("subadult creep short", P, Vector3.new(100, 0, 0), "TRex", 0.8, true, false, "tooTall", 10, false)
chk("raptor stand short", P, Vector3.new(100, 0, 0), "Raptor", 1, false, true, "inside", 10)
chk("hatchling stand tall", P, Vector3.new(0, 0, 0), "TRex", 0.4, false, true, "inside", 17)
chk("above the box", P, Vector3.new(0, 20, 0), "Raptor", 1, false, false, "open", 0, false)
chk("no patches", {}, Vector3.new(0, 0, 0), "Raptor", 1, true, false, "open", 0, false)
-- overlap: a short patch on top of the tall one -> the higher height counts
local C = GC.patch(CFrame.new(0, 0, 0), Vector3.new(30, 25, 30), 10)
chk("overlap", {C, A}, Vector3.new(0, 0, 0), "TRex", 1, true, true, "inside", 17)
-- rotated patch: box turned 45 degrees, point 20 studs out along X is within its corner? (corner reaches 15.5 * sqrt 2 = 21.9)
local R = GC.patch(CFrame.Angles(0, math.rad(45), 0), Vector3.new(30, 25, 30), 17)
chk("rotated corner inside", {R}, Vector3.new(20, 0, 0), "Raptor", 1, false, true, "inside", 17)

if #fails > 0 then return "FAIL " .. #fails .. " (pass " .. passes .. ")\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
