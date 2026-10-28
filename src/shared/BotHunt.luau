-- BotHunt v1.0 (Dino Arcade) — who a bot may attack, which target is nearest, when it flees, how it heals.
-- DINO-30, plan docs/plans/BOTHUNT_v1.0.md, ADR-006. Pure: works on plain descriptors; BotServer 1.9 applies it.
-- User: "the bots need to hunt too tho when theyre in range of prey or fight if they get in range of other bot animals";
--   answers: predator rules, the loser flees at low health, the killer eats after a kill, the nearest target wins.
-- Descriptor: {kind = "bot" / "prey" / "player", species, pack (pack name or nil), id (unique name), hpFrac (0..1),
--   grudge (raptor packs: id of the bot the pack has a grudge on, or nil)}.
-- hostile(self, other): never itself; prey -> true; a bot target needs self.hpFrac >= FLEE_FRAC (0.3), then:
--   self T-Rex -> any bot; self raptor -> a raptor bot of another pack (or with no pack), or a T-Rex bot only when it is
--   self.grudge. Players are not judged here (the caller keeps its own player rules and passes `allowed`).
-- nearest(self, candidates, sight): candidates = {{desc, dist, allowed?}}; players use `allowed`, animals hostile();
--   returns the index of the closest within sight (ties: the first), or nil.
-- shouldFlee(hpFrac): hpFrac < FLEE_FRAC.
-- regen(hp, max, sinceHit, dt): sinceHit >= REGEN_WAIT (10 s) -> hp + REGEN_RATE (0.01) x max x dt, capped at max.
local BotHunt = {}
BotHunt.Version = "1.0"
BotHunt.FLEE_FRAC = 0.3
BotHunt.REGEN_WAIT = 10
BotHunt.REGEN_RATE = 0.01

function BotHunt.hostile(self, other)
	if not self or not other or (self.id ~= nil and self.id == other.id) then return false end
	if other.kind == "prey" then return true end
	if other.kind ~= "bot" then return false end
	if (self.hpFrac or 1) < BotHunt.FLEE_FRAC then return false end
	if self.species == "TRex" then return true end
	if other.species == "TRex" then return self.grudge ~= nil and self.grudge == other.id end
	return other.pack == nil or other.pack ~= self.pack
end

function BotHunt.nearest(self, candidates, sight)
	local best, bestD = nil, sight
	for i, c in ipairs(candidates) do
		local ok
		if c.desc.kind == "player" then ok = c.allowed == true else ok = BotHunt.hostile(self, c.desc) end
		if ok and c.dist <= bestD and (best == nil or c.dist < bestD) then best, bestD = i, c.dist end
	end
	return best
end

function BotHunt.shouldFlee(hpFrac)
	return (hpFrac or 1) < BotHunt.FLEE_FRAC
end

function BotHunt.regen(hp, max, sinceHit, dt)
	if hp >= max or sinceHit < BotHunt.REGEN_WAIT then return math.min(hp, max) end
	return math.min(max, hp + BotHunt.REGEN_RATE * max * dt)
end

return BotHunt
