-- BiteServer v1.4 (Dino Arcade) — TEST. Validates bite requests, stamps the start time, and checks for a
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
-- v1.1: client hit claims (BiteTest 1.1). Each accepted bite is resolved exactly once, by whichever comes
--   first: (a) a valid claim DinoBiteClaim(stamp, targetModel, point) -> hit, BiteHitSource = "client";
--   (b) the server's own check at contact finds a target -> hit, BiteHitSource = "server";
--   (c) CLAIM_WAIT seconds after contact with neither -> miss.
--   A claim is valid when: it matches the pending bite's client stamp, arrives before the bite is resolved
--   and before contact + CLAIM_WAIT, the target is a workspace Model with BiteDummy = true, the point lies on
--   the target (within POINT_TOLERANCE of one of its parts), and the point is within BiteRange + CLAIM_SLACK
--   of the server's own hit volume (the server sees the body slightly late while it moves or turns).
--   Rejected claims are recorded in BiteClaimResult ("noBite" / "stale" / "resolved" / "late" / "badTarget" /
--   "offTarget" / "far" / "badArg"); "ok" when accepted.
--   Hit volume (server check and claim validation): a capsule of radius BiteRange around the line from
--   BiteReachBack studs behind the mouth front (back along the snout) to BiteRange / 2 studs ahead of it,
--   so a target the head has pushed into still counts (the head reaches ~15 studs past the body hitbox).
--   Claims must lie within BiteRange + CLAIM_SLACK of the server's capsule line.
-- v1.2: targets are BiteDummy models (any part) and Bitable models such as other dinos (only the parts in
--   their "Hitboxes" folder, built by DinoHitboxes). A claim on a Bitable model may sit up to
--   POINT_TOLERANCE_DINO studs off its hitboxes (the server sees dinos in their rest pose, clients see
--   them animated). Damage goes to the target's DummyHealth attribute (BiteDummy / BiteTargetHealth).
-- v1.3: hit zones + roar debuff. Damage = round(BiteDamage x zone multiplier x debuff multiplier).
--   Zone = the bitten hitbox's HitboxSegment (server check: of the target's hitboxes inside the capsule, the
--   one nearest the capsule's front tip, where the teeth close; client claim: the hitbox part nearest the
--   claimed point). The target choice itself is unchanged. Head / Jaw / Neck -> "head" (HitZoneHeadMul, default 1.5);
--   Tail1-5 -> "tail" (HitZoneTailMul, default 0.5); Torso, legs, shins, feet, arms -> "torso"
--   (HitZoneTorsoMul, default 1). Multipliers are read from the TARGET model's attributes (defaults here).
--   BiteDummy targets have no zones: zone "dummy", multiplier 1, and no debuff.
--   Debuff: while the target's DebuffUntil (server time, set by RoarServer 1.1) is in the future, damage
--   is multiplied by the target's DebuffDamageTakenMul (default 1).
--   Diagnostics (attacker attributes): BiteHitZone ("head" / "torso" / "tail" / "dummy"), BiteHitSegment,
--   BiteHitZoneMul, BiteHitDebuffMul, BiteHitBaseDamage. BiteHitDamage is the final damage dealt.
-- v1.4: tired bites. A bite accepted while the attacker is Exhausted (StaminaServer 1.0; read when the bite is
--   accepted, before its own stamina cost) does x StaminaTiredBiteMul (attacker attribute, default 0.6), on every
--   target including the dummy: damage = round(BiteDamage x zone x debuff x tired). Diagnostic: BiteHitTiredMul.
-- Diagnostics (character attributes): BiteHitSource ("client" / "server"), BiteClaimDist (studs from the
--   server capsule line to the claimed point), BiteCount (accepted), BiteLastResult ("ok" / "cooldown" /
--   "roaring" / "disabled" / "dead" / "badArg"), BiteLastContact ("hit" / "miss"), BiteStartLag (s).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("DinoBiteRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoBiteRequest"
	remote.Parent = ReplicatedStorage
end
local claimRemote = ReplicatedStorage:FindFirstChild("DinoBiteClaim")
if not claimRemote then
	claimRemote = Instance.new("RemoteEvent")
	claimRemote.Name = "DinoBiteClaim"
	claimRemote.Parent = ReplicatedStorage
end

local DEFAULTS = {BiteEnabled = true, BiteCooldown = 0.8, BiteWindup = 0.15, BiteStrike = 0.10,
	BiteDamage = 25, BiteRange = 5, BiteReachBack = 8, RoarDuration = 1.4,
	StaminaTiredBiteMul = 0.6} -- v1.4
local MAX_LAG = 0.3 -- seconds a client stamp may lag behind the server clock
local CLAIM_WAIT = 0.35     -- seconds after contact a claim is still taken
local CLAIM_SLACK = 10      -- extra studs allowed between the server capsule line and a claimed point
local POINT_TOLERANCE = 1.5 -- studs a claimed point may sit off the target's parts
local POINT_TOLERANCE_DINO = 4 -- same, for Bitable dinos (animated on clients, rest pose on the server)

local pending = {} -- [char] = {stamp, start, contact, resolved}

-- v1.3 hit zones: hitbox segment -> zone, zone -> multiplier attribute on the target (+ default)
local ZONE_OF = {Head = "head", Jaw = "head", Neck = "head",
	Tail1 = "tail", Tail2 = "tail", Tail3 = "tail", Tail4 = "tail", Tail5 = "tail"}
local ZONE_ATTR = {head = "HitZoneHeadMul", torso = "HitZoneTorsoMul", tail = "HitZoneTailMul"}
local ZONE_DEFAULT = {head = 1.5, torso = 1, tail = 0.5}

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

-- the bite target a part belongs to: a BiteDummy model (any of its parts) or a Bitable model (only the
-- parts in its "Hitboxes" folder, built by DinoHitboxes); nil otherwise
local function targetOf(part)
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:GetAttribute("BiteDummy") == true then return model end
		if model:GetAttribute("Bitable") == true then
			local folder = part.Parent
			if folder and folder.Name == "Hitboxes" and folder.Parent == model then return model end
			return nil
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- the server's own hit capsule line for this character, right now (a = behind the mouth, b = ahead)
local function serverSegment(char)
	local origin, fwd = mouthFrame(char)
	if not origin then return nil end
	return origin - fwd * get(char, "BiteReachBack"), origin + fwd * (get(char, "BiteRange") / 2)
end

-- closest point on the segment a..b to p
local function segmentPoint(a, b, p)
	local ab = b - a
	local t = ab:Dot(ab) > 0 and math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
	return a + ab * t
end

-- closest distance (and point on the part) between a part's box and the segment a..b, sampled every 0.5 studs
local function segmentHit(part, a, b)
	local best, bestPt = math.huge, nil
	local n = math.max(1, math.ceil((b - a).Magnitude / 0.5))
	for i = 0, n do
		local q = a:Lerp(b, i / n)
		local cp = closestPoint(part, q)
		local d = (cp - q).Magnitude
		if d < best then best, bestPt = d, cp end
	end
	return best, bestPt
end

-- v1.3: zone of the bitten part -> zone name, segment name, multiplier
local function zoneOf(model, part)
	if model:GetAttribute("BiteDummy") == true then return "dummy", nil, 1 end
	local seg = part and part:GetAttribute("HitboxSegment")
	local zone = (seg and ZONE_OF[seg]) or "torso"
	local mul = model:GetAttribute(ZONE_ATTR[zone])
	if typeof(mul) ~= "number" then mul = ZONE_DEFAULT[zone] end
	return zone, seg, mul
end

-- v1.3: roar debuff on the target -> damage taken multiplier (1 when none / expired / dummy)
local function debuffOf(model)
	if model:GetAttribute("BiteDummy") == true then return 1 end
	local untilT = model:GetAttribute("DebuffUntil")
	local mul = model:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(mul) == "number" and workspace:GetServerTimeNow() < untilT then
		return mul
	end
	return 1
end

local function applyHit(char, model, point, source, part)
	local base = get(char, "BiteDamage")
	local zone, seg, zoneMul = zoneOf(model, part)
	local debuffMul = debuffOf(model)
	local pb = pending[char] -- v1.4: was the attacker exhausted when this bite was accepted?
	local tiredMul = (pb and pb.exhausted) and get(char, "StaminaTiredBiteMul") or 1
	local dmg = math.floor(base * zoneMul * debuffMul * tiredMul + 0.5)
	char:SetAttribute("BiteHitBaseDamage", base)
	char:SetAttribute("BiteHitZone", zone)
	char:SetAttribute("BiteHitSegment", seg)
	char:SetAttribute("BiteHitZoneMul", zoneMul)
	char:SetAttribute("BiteHitDebuffMul", debuffMul)
	char:SetAttribute("BiteHitTiredMul", tiredMul) -- v1.4
	local hp = model:GetAttribute("DummyHealth")
	if hp then model:SetAttribute("DummyHealth", math.max(0, hp - dmg)) end
	char:SetAttribute("BiteHitPos", point)
	char:SetAttribute("BiteHitDamage", dmg)
	char:SetAttribute("BiteHitTarget", model.Name)
	char:SetAttribute("BiteHitSource", source)
	char:SetAttribute("BiteHitCount", (char:GetAttribute("BiteHitCount") or 0) + 1)
	char:SetAttribute("BiteLastContact", "hit")
	char:SetAttribute("BiteHitAt", workspace:GetServerTimeNow()) -- last: clients react to this one
end

local function checkHit(char, startedAt)
	if char:GetAttribute("BiteStartedAt") ~= startedAt then return end -- a newer bite replaced this one
	local p = pending[char]
	if not p or p.start ~= startedAt or p.resolved then return end
	local a, b = serverSegment(char)
	if not a then return end
	local range = get(char, "BiteRange")
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best, bestModel, bestPoint, bestPart = math.huge, nil, nil, nil
	local inRange = {} -- v1.3: every target part inside the capsule, for the zone pick
	for _, part in ipairs(workspace:GetPartBoundsInRadius((a + b) / 2, (b - a).Magnitude / 2 + range, params)) do
		local model = targetOf(part)
		if model then
			local d, cp = segmentHit(part, a, b)
			if d <= range then table.insert(inRange, {model = model, part = part}) end
			if d <= range and d < best then best, bestModel, bestPoint, bestPart = d, model, cp, part end
		end
	end
	if bestModel then
		-- v1.3: zone = the chosen target's part nearest the capsule's front tip (b)
		local zonePart, zoneD = bestPart, math.huge
		for _, c in ipairs(inRange) do
			if c.model == bestModel then
				local d = (closestPoint(c.part, b) - b).Magnitude
				if d < zoneD then zonePart, zoneD = c.part, d end
			end
		end
		p.resolved = true
		applyHit(char, bestModel, bestPoint, "server", zonePart)
		return
	end
	-- no server hit: wait for a client claim, then call it a miss
	task.delay(CLAIM_WAIT, function()
		if pending[char] == p and not p.resolved then
			p.resolved = true
			char:SetAttribute("BiteLastContact", "miss")
		end
	end)
end

claimRemote.OnServerEvent:Connect(function(player, stamp, model, point)
	local char = player.Character
	if not char then return end
	local function reject(why) char:SetAttribute("BiteClaimResult", why) end
	if typeof(stamp) ~= "number" or typeof(model) ~= "Instance" or typeof(point) ~= "Vector3" then return reject("badArg") end
	local p = pending[char]
	if not p then return reject("noBite") end
	if math.abs(p.stamp - stamp) > 0.001 then return reject("stale") end
	if p.resolved then return reject("resolved") end
	if workspace:GetServerTimeNow() > p.contact + CLAIM_WAIT then return reject("late") end
	local isDummy = model:IsA("Model") and model:GetAttribute("BiteDummy") == true
	local isDino = model:IsA("Model") and model:GetAttribute("Bitable") == true and model:FindFirstChild("Hitboxes") ~= nil
	if not (model:IsDescendantOf(workspace) and (isDummy or isDino)) or model == char then
		return reject("badTarget")
	end
	local onTarget = math.huge
	local nearestPart -- v1.3: the hitbox nearest the claimed point decides the zone
	for _, part in ipairs((isDummy and model or model.Hitboxes):GetDescendants()) do
		if part:IsA("BasePart") then
			local d = (closestPoint(part, point) - point).Magnitude
			if d < onTarget then onTarget, nearestPart = d, part end
		end
	end
	if onTarget > (isDummy and POINT_TOLERANCE or POINT_TOLERANCE_DINO) then return reject("offTarget") end
	local a, b = serverSegment(char)
	local dist = a and (point - segmentPoint(a, b, point)).Magnitude or math.huge
	char:SetAttribute("BiteClaimDist", math.floor(dist * 100 + 0.5) / 100)
	if dist > get(char, "BiteRange") + CLAIM_SLACK then return reject("far") end
	p.resolved = true
	char:SetAttribute("BiteClaimResult", "ok")
	applyHit(char, model, point, "client", nearestPart)
end)

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
			local exhausted = char:GetAttribute("Exhausted") == true -- v1.4: before this bite's stamina cost
			char:SetAttribute("BiteStartedAt", start)
			pending[char] = {stamp = stamp, start = start, contact = start + get(char, "BiteWindup") + get(char, "BiteStrike"), resolved = false, exhausted = exhausted}
			char:SetAttribute("BiteStartLag", math.floor((now - start) * 1000 + 0.5) / 1000)
			char:SetAttribute("BiteCount", (char:GetAttribute("BiteCount") or 0) + 1)
			task.delay(math.max(0, pending[char].contact - workspace:GetServerTimeNow()), checkHit, char, start)
		end
	end
	char:SetAttribute("BiteLastResult", result)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	if player.Character then pending[player.Character] = nil end
end)
