-- BiteServer v1.0 (Dino Arcade) — TEST. Validates bite requests, stamps the start time, and checks for a
-- hit at the moment the jaws shut.
-- Client -> server: ReplicatedStorage.DinoBiteRequest:FireServer(clientServerTime) (sent by BiteTest)
-- Start time = the client's stamp clamped to [now - MAX_LAG, now] (so every client's pose lines up with
--   the attacker's click), written to the character attribute BiteStartedAt (replicates).
-- Checks, in order (first failing one is the result): character alive ("dead"), BiteEnabled ~= false
--   ("disabled"), not inside a roar (RoarStartedAt + RoarDuration, "roaring"), BiteCooldown since the
--   last accepted bite ("cooldown"). Accepted = "ok".
-- Hit check at start + BiteWindup + BiteStrike (contact): a sphere of radius BiteRange centred
--   BiteRange / 2 studs in front of the mouth (Head_mouth front face, rest pose, where the body is now).
--   Targets: models with attribute BiteDummy = true only (players are not damaged yet). Closest target
--   part wins. On a hit: target DummyHealth -= BiteDamage; attacker attributes BiteHitAt (server time),
--   BiteHitPos (Vector3), BiteHitDamage, BiteHitTarget (model name), BiteHitCount.
-- Diagnostics (character attributes): BiteCount (accepted), BiteLastResult ("ok" / "cooldown" /
--   "roaring" / "disabled" / "dead" / "badArg"), BiteLastContact ("hit" / "miss"), BiteStartLag (s).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("DinoBiteRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoBiteRequest"
	remote.Parent = ReplicatedStorage
end

local DEFAULTS = {BiteEnabled = true, BiteCooldown = 0.8, BiteWindup = 0.15, BiteStrike = 0.10,
	BiteDamage = 25, BiteRange = 5, RoarDuration = 1.4}
local MAX_LAG = 0.3 -- seconds a client stamp may lag behind the server clock

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- mouth front + forward direction from the rest-pose head (the server does not animate joints)
local function mouthFrame(char)
	local head = char:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (mouth and hrp) then return nil end
	local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	return mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0), fwd
end

-- closest point of a part's box to p
local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

local function checkHit(char, startedAt)
	if char:GetAttribute("BiteStartedAt") ~= startedAt then return end -- a newer bite replaced this one
	local origin, fwd = mouthFrame(char)
	if not origin then return end
	local range = get(char, "BiteRange")
	local centre = origin + fwd * (range / 2)
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best, bestModel, bestPoint = math.huge, nil, nil
	for _, part in ipairs(workspace:GetPartBoundsInRadius(centre, range, params)) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		while model and model:GetAttribute("BiteDummy") ~= true do
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		if model then
			local cp = closestPoint(part, centre)
			local d = (cp - centre).Magnitude
			if d <= range and d < best then best, bestModel, bestPoint = d, model, cp end
		end
	end
	if not bestModel then
		char:SetAttribute("BiteLastContact", "miss")
		return
	end
	local dmg = get(char, "BiteDamage")
	local hp = bestModel:GetAttribute("DummyHealth")
	if hp then bestModel:SetAttribute("DummyHealth", math.max(0, hp - dmg)) end
	char:SetAttribute("BiteHitPos", bestPoint)
	char:SetAttribute("BiteHitDamage", dmg)
	char:SetAttribute("BiteHitTarget", bestModel.Name)
	char:SetAttribute("BiteHitCount", (char:GetAttribute("BiteHitCount") or 0) + 1)
	char:SetAttribute("BiteLastContact", "hit")
	char:SetAttribute("BiteHitAt", workspace:GetServerTimeNow()) -- last: clients react to this one
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		char:SetAttribute("BiteLastResult", "badArg")
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local result
	if not hum or hum.Health <= 0 then
		result = "dead"
	elseif char:GetAttribute("BiteEnabled") == false then
		result = "disabled"
	else
		local roarAt = char:GetAttribute("RoarStartedAt")
		local start = math.clamp(stamp, now - MAX_LAG, now)
		local last = char:GetAttribute("BiteStartedAt")
		if roarAt and start >= roarAt and start <= roarAt + get(char, "RoarDuration") then
			result = "roaring"
		elseif last and start - last < get(char, "BiteCooldown") then
			result = "cooldown"
		else
			result = "ok"
			char:SetAttribute("BiteStartedAt", start)
			char:SetAttribute("BiteStartLag", math.floor((now - start) * 1000 + 0.5) / 1000)
			char:SetAttribute("BiteCount", (char:GetAttribute("BiteCount") or 0) + 1)
			local contact = start + get(char, "BiteWindup") + get(char, "BiteStrike")
			task.delay(math.max(0, contact - workspace:GetServerTimeNow()), checkHit, char, start)
		end
	end
	char:SetAttribute("BiteLastResult", result)
end)
