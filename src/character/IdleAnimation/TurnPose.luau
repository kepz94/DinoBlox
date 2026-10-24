-- TurnPose v1.0 (Dino Arcade) — head leans into turns while moving (walk / run / creep).
-- Pure function: smoothed turn rate (degrees per second, positive = turning left) -> neck + head offsets,
-- multiplied onto the current pose. The head yaws toward the side the dino is turning to and rolls
-- (tilts) into the turn. The animator scales the input by the walk blend, so standing turns are untouched.
-- Joint frames are world-aligned at build time: rotation about Y = yaw (positive = left),
-- about X = roll (positive tips the top toward +Z = the dino's right).

local TurnPose = {}

TurnPose.Version = "1.0"
TurnPose.Defaults = {
	TurnHeadEnabled = true,
	TurnHeadMax     = 20,   -- degrees of head yaw at most
	TurnHeadGain    = 0.06, -- degrees of head yaw per degree/second of turning
	TurnHeadRoll    = 0.4,  -- roll into the turn, as a share of the yaw
	TurnHeadSmooth  = 8,    -- how fast the turn rate is followed (per second)
}

local rad = math.rad

-- turn amount in degrees (already clamped and scaled by the walk blend) for a turn rate
function TurnPose.amount(turnRate, s, weight)
	return math.clamp(turnRate * s.TurnHeadGain, -s.TurnHeadMax, s.TurnHeadMax) * (weight or 1)
end

-- a: turn amount in degrees (positive = left)
function TurnPose.get(a, s)
	local roll = -a * s.TurnHeadRoll -- left turn tips the head to the left (-Z)
	return {
		Neck = CFrame.Angles(rad(roll * 0.5), rad(a * 0.45), 0),
		Head = CFrame.Angles(rad(roll * 0.5), rad(a * 0.55), 0),
	}
end

function TurnPose.settings(model)
	local s = {}
	for k, v in pairs(TurnPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return TurnPose
