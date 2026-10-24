-- HeadLeadPose v1.0 (Dino Arcade) — the head turns toward where the dino is going before the body does.
-- Input: the turn still to go (degrees, positive = left), from TurnLimit 1.0 (TurnErrorLocal on the owner's
-- client, TurnError replicated by TurnServer 1.0 for everyone else). The animator clamps it to HeadLeadMax,
-- smooths it (HeadLeadSmooth) and multiplies the result onto the neck + head. Applies moving and standing.
-- The animator fades it out during the roar and the bite (those layers aim the head forward).
-- Joint frames are world-aligned at build time: rotation about Y = yaw (positive = left).

local HeadLeadPose = {}

HeadLeadPose.Version = "1.0"
HeadLeadPose.Defaults = {
	HeadLeadEnabled   = true,
	HeadLeadMax       = 45,   -- degrees of neck + head yaw at most
	HeadLeadSmooth    = 10,   -- how fast the head follows the turn still to go (per second)
	HeadLeadNeckShare = 0.45, -- share of the yaw on the neck (the rest on the head)
}

local rad = math.rad

-- target lead (degrees) for a turn still to go
function HeadLeadPose.target(errDeg, s)
	return math.clamp(errDeg, -s.HeadLeadMax, s.HeadLeadMax)
end

-- a: lead in degrees (positive = left)
function HeadLeadPose.get(a, s)
	return {
		Neck = CFrame.Angles(0, rad(a * s.HeadLeadNeckShare), 0),
		Head = CFrame.Angles(0, rad(a * (1 - s.HeadLeadNeckShare)), 0),
	}
end

function HeadLeadPose.settings(model)
	local s = {}
	for k, v in pairs(HeadLeadPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return HeadLeadPose
