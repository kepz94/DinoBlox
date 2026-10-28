-- GrassCover v1.0 (Dino Arcade) — is a dino hidden by grass? Head height against grass height, plus a creeping edge.
-- DINO-24, plan docs/plans/AMBUSH_v1.0.md (deterministic map), ADR-004. Pure (no services, no instances): BotServer 1.7
--   builds the patch list and calls check() for every player character.
-- User: "This is the reason for grass and creep walk. Allow a way for that mechanic to be used for ambushing"; answers:
--   creeping near grass counts as hidden; some grass tall enough that a T-Rex is hidden only while creeping; option A
--   of docs/mockups/ambush_options.html (height rule, tall grass 17 + short grass 10).
-- top(species, scale, creeping) = TOP[species][creeping and 2 or 1] x scale (unknown species: TRex; scale nil: 1).
--   TOP measured in Play 2026-10-27 (top of the head above the ground): T-Rex 20.0 standing / 14.0 creeping, raptor 5.5 / 3.3.
-- patch(cf, size, height) = {cf, half = size / 2 + MARGIN, height (nil: DEFAULT_HEIGHT 17)}.
-- check(patches, pos, species, scale, creeping) -> hidden, reason, height, hint:
--   a patch holds pos when pos is inside its box (in the box frame); it is near when pos is vertically inside the box and
--   the flat distance to the box is at most EDGE (inside counts as near). insideH / nearH = the highest such height.
--   * inside a patch and top <= insideH                        -> true,  "inside",  insideH, false
--   * creeping, near a patch and top <= nearH                  -> true,  "edge",    nearH,   false
--   * inside a patch (too tall)                                -> false, "tooTall", insideH, not creeping and creeping top <= nearH
--   * near only, creeping (too tall)                           -> false, "tooTall", nearH,   false
--   * near only, not creeping                                  -> false, "open",    nearH,   creeping top <= nearH
--   * nothing near                                             -> false, "open",    0,       false
local GrassCover = {}
GrassCover.Version = "1.0"
GrassCover.TOP = {TRex = {20.0, 14.0}, Raptor = {5.5, 3.3}}
GrassCover.DEFAULT_HEIGHT = 17
GrassCover.EDGE = 4
GrassCover.MARGIN = 0.5

function GrassCover.patch(cf, size, height)
	local m = GrassCover.MARGIN
	return {cf = cf, half = size / 2 + Vector3.new(m, m, m), height = height or GrassCover.DEFAULT_HEIGHT}
end

function GrassCover.top(species, scale, creeping)
	local t = GrassCover.TOP[species] or GrassCover.TOP.TRex
	return t[creeping and 2 or 1] * (scale or 1)
end

function GrassCover.check(patches, pos, species, scale, creeping)
	local insideH, nearH = nil, nil
	for _, p in ipairs(patches) do
		local lp = p.cf:PointToObjectSpace(pos)
		if math.abs(lp.Y) <= p.half.Y then
			local dx = math.max(math.abs(lp.X) - p.half.X, 0)
			local dz = math.max(math.abs(lp.Z) - p.half.Z, 0)
			local d = math.sqrt(dx * dx + dz * dz)
			if d == 0 then
				if not insideH or p.height > insideH then insideH = p.height end
			end
			if d <= GrassCover.EDGE then
				if not nearH or p.height > nearH then nearH = p.height end
			end
		end
	end
	local topNow = GrassCover.top(species, scale, creeping)
	local topCreep = GrassCover.top(species, scale, true)
	if insideH and topNow <= insideH then return true, "inside", insideH, false end
	if creeping and nearH and topNow <= nearH then return true, "edge", nearH, false end
	if insideH then return false, "tooTall", insideH, (not creeping) and topCreep <= nearH end
	if nearH then
		if creeping then return false, "tooTall", nearH, false end
		return false, "open", nearH, topCreep <= nearH
	end
	return false, "open", 0, false
end

return GrassCover
