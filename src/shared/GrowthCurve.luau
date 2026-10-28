-- GrowthCurve v1.1 (Dino Arcade) — growth maths: levels, stages, XP, size, strength, speed, death drop, size-ratio XP.
-- Pure functions, no Instance access. Used by GrowthServer 1.0 (DINO-7). Tests: tools/tests/GrowthCurve.spec.luau.
-- Plan: docs/plans/GROWTH_v1.0.md, ADR-001 (user's answers: option C, levels + growth stages).
--   * 20 levels in 4 stages of 5: Hatchling 1-5, Juvenile 6-10, Sub-adult 11-15, Adult 16-20.
--   * Size (body scale) changes only at stage-ups: STAGE_SIZE 0.4 / 0.6 / 0.8 / 1.0.
--   * Strength (max health, bite / pounce damage) every level: 0.4 + 0.6 x (level - 1) / 19 (level 20 = adult).
--   * Speed per stage: SPEED_MUL 0.80 / 0.87 / 0.93 / 1.00 (red-team answer: small legs would step too fast).
--   * XP from level L to L + 1: HATCHLING_COST 15 / 20 / 25 / 30 / 35 for levels 1-5 (user: "the hatchling levels
--     should be very quick to level up from"), else 40 + 15 x (L - 1); 0 at level 20. 3100 XP from 1 to 20.
--   * Death: one stage down = 5 levels (minimum 1); XP into the level kept, below that level's requirement.
--   * Bigger-target bonus: damage / kill XP x clamp(target length / attacker length, 1, 10).
--   * scaledAttributes: the character attributes the existing scripts read, scaled from the adult (base) values.
-- v1.1: BiteRange (the bite's hit radius around the snout line = its forgiveness) is no longer scaled with the body.
--   Measured in Play (DINO-7): a Hatchling raptor's radius became 1.2 studs; auto-aim picked the lying T-Rex bot but the
--   server found its Torso 3.6 studs from the mouth (beyond 1.2 + BiteAimSlack 2) and both bites missed, against the
--   user's "it needs to be consistent". Reach-back, lunge, pounce and eating distances still scale.
local GrowthCurve = {}

GrowthCurve.Version = "1.1"
GrowthCurve.MAX_LEVEL = 20
GrowthCurve.STAGE_LEVELS = 5
GrowthCurve.STAGES = {"Hatchling", "Juvenile", "Sub-adult", "Adult"}
GrowthCurve.STAGE_SIZE = {0.4, 0.6, 0.8, 1.0}
GrowthCurve.SPEED_MUL = {0.80, 0.87, 0.93, 1.00}
GrowthCurve.HATCHLING_COST = {15, 20, 25, 30, 35}
GrowthCurve.DEATH_DROP = 5
GrowthCurve.SIZE_RATIO_MAX = 10

GrowthCurve.SPEED_KEYS = {"MoveWalkSpeed", "MoveRunSpeed", "MoveCreepSpeed"}
GrowthCurve.STRENGTH_KEYS = {"BiteDamage", "PounceLandDamage", "PounceTickDamage"}
GrowthCurve.DISTANCE_KEYS = {"BiteReachBack", "BiteLungeDist", "PounceDistance", "PounceReach",
	"PounceLatchStandoff", "EatRange", "EatHeight", "CameraStartZoom", "ShoulderCamDistance"}

local function clampLevel(level)
	return math.clamp(math.floor(level), 1, GrowthCurve.MAX_LEVEL)
end

function GrowthCurve.xpToNext(level)
	level = clampLevel(level)
	if level >= GrowthCurve.MAX_LEVEL then return 0 end
	local h = GrowthCurve.HATCHLING_COST[level]
	if h then return h end
	return 40 + 15 * (level - 1)
end

function GrowthCurve.stageOf(level)
	return math.floor((clampLevel(level) - 1) / GrowthCurve.STAGE_LEVELS) + 1
end

function GrowthCurve.stageName(level)
	return GrowthCurve.STAGES[GrowthCurve.stageOf(level)]
end

function GrowthCurve.sizeOf(level)
	return GrowthCurve.STAGE_SIZE[GrowthCurve.stageOf(level)]
end

function GrowthCurve.speedOf(level)
	return GrowthCurve.SPEED_MUL[GrowthCurve.stageOf(level)]
end

function GrowthCurve.strengthOf(level)
	return 0.4 + 0.6 * (clampLevel(level) - 1) / (GrowthCurve.MAX_LEVEL - 1)
end

-- returns level, xp, levelsGained
function GrowthCurve.addXp(level, xp, gain)
	level = clampLevel(level)
	xp = math.max(0, xp + math.max(0, gain))
	local gained = 0
	while level < GrowthCurve.MAX_LEVEL and xp >= GrowthCurve.xpToNext(level) do
		xp -= GrowthCurve.xpToNext(level)
		level += 1
		gained += 1
	end
	if level >= GrowthCurve.MAX_LEVEL then xp = 0 end
	return level, xp, gained
end

-- returns level, xp after a death
function GrowthCurve.deathDrop(level, xp)
	local new = math.max(1, clampLevel(level) - GrowthCurve.DEATH_DROP)
	local need = GrowthCurve.xpToNext(new)
	if need <= 0 then return new, 0 end
	return new, math.clamp(xp, 0, need - 1)
end

function GrowthCurve.sizeRatioMul(targetLen, myLen)
	if type(targetLen) ~= "number" or type(myLen) ~= "number" or targetLen <= 0 or myLen <= 0 then return 1 end
	return math.clamp(targetLen / myLen, 1, GrowthCurve.SIZE_RATIO_MAX)
end

function GrowthCurve.maxHealthOf(baseMax, level)
	return math.floor(baseMax * GrowthCurve.strengthOf(level) + 0.5)
end

local function roundTo(x, step)
	return math.floor(x / step + 0.5) * step
end

-- base: {[attribute] = adult value}; returns {[attribute] = value at this level} for the keys present in base
function GrowthCurve.scaledAttributes(base, level)
	local out = {}
	local speed, strength, size = GrowthCurve.speedOf(level), GrowthCurve.strengthOf(level), GrowthCurve.sizeOf(level)
	for _, k in ipairs(GrowthCurve.SPEED_KEYS) do
		if type(base[k]) == "number" then out[k] = roundTo(base[k] * speed, 0.1) end
	end
	for _, k in ipairs(GrowthCurve.STRENGTH_KEYS) do
		if type(base[k]) == "number" then out[k] = math.floor(base[k] * strength + 0.5) end
	end
	for _, k in ipairs(GrowthCurve.DISTANCE_KEYS) do
		if type(base[k]) == "number" then out[k] = roundTo(base[k] * size, 0.01) end
	end
	return out
end

return GrowthCurve
