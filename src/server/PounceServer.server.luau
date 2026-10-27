-- PounceServer v1.0 (Dino Arcade) — TEST. Validates raptor pounces, latches the raptor onto a larger dino and
-- deals the latch damage.
-- Client -> server (sent by PounceTest 1.0):
--   DinoPounceRequest:FireServer(clientServerTime)              at the key press
--   DinoPounceClaim:FireServer(stamp, hitboxPart, offset)       when the lunge touches a target hitbox;
--                                                               offset = latch CFrame relative to hitboxPart
--   DinoPounceRelease:FireServer()                              jump key while latched (leap off)
-- Request checks, in order: "badArg", "dead", "disabled" (PounceEnabled ~= true), "latched" (already on),
--   "exhausted", "stamina" (stamina < PounceStaminaCost, StaminaEnabled ~= false), "cooldown"
--   (PounceCooldown since the last accepted pounce) -> "ok": PounceStartedAt = stamp clamped to
--   [now - MAX_LAG, now] (replicates; StaminaServer 1.2 charges PounceStaminaCost for each new value).
--   Denied: PounceDeniedAt = the client stamp, PounceDenyReason.
-- Claim checks: "badArg", "noPounce" (stamp is not the pending pounce), "late" (more than PounceClaimWindow s after
--   the start), "badTarget" (part is not in the "Hitboxes" folder of a Workspace model with Bitable = true and a
--   Species attribute, or that model is knocked out, or it is the raptor itself), "small" (target extents not at
--   least PounceSizeRatio x the raptor's), "far" (part more than CLAIM_TOLERANCE studs from the raptor's body as
--   the server sees it), "badOffset" (offset farther than OFFSET_MAX studs from the part) -> "ok".
-- Latched (replicated, read by PounceTest and IdleAnimation 1.16 on every client):
--   ObjectValue "PounceLatchPart" (child of the character) = the hitbox part, attribute PounceLatchOffset (CFrame
--   relative to that part), PounceLatched = true, PounceLatchedAt (server time), PounceLatchTarget (model name),
--   PounceLatchSegment (HitboxSegment of the part).
-- Damage (target DummyHealth, BiteTargetHealth): PounceLandDamage (8) at the latch, then PounceTickDamage (4) every
--   PounceTickInterval (0.5 s) while latched; each x the target's DebuffDamageTakenMul while DebuffUntil is in the
--   future (roar debuff), rounded. No hit-zone multiplier. Each hit sets PounceBiteAt (server time; chomp pose)
--   and PounceHitDamage.
-- Release (PounceLatched = false, PounceReleasedAt, PounceReleaseReason): "jump" (release request), "stamina"
--   (stamina reached 0; StaminaServer 1.2 drains PounceLatchDrain per second while latched), "ko" (target knocked
--   out), "gone" (target or part removed), "dead", "disabled", "timeout" (MAX_LATCH s safety).
-- Settings (raptor attributes): PounceEnabled (default false), PounceStaminaCost 15, PounceCooldown 3,
--   PounceClaimWindow 0.9, PounceSizeRatio 1.5, PounceLandDamage 8, PounceTickDamage 4, PounceTickInterval 0.5.
-- Diagnostics (raptor attributes): PounceServerResult, PounceClaimResult, PounceCount, PounceLatchCount,
--   PounceDamageTotal (this latch), PounceClaimDist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULTS = {PounceEnabled = false, PounceStaminaCost = 15, PounceCooldown = 3, PounceClaimWindow = 0.9,
	PounceSizeRatio = 1.5, PounceLandDamage = 8, PounceTickDamage = 4, PounceTickInterval = 0.5,
	StaminaEnabled = true, StaminaMax = 100}
local MAX_LAG = 0.3         -- seconds a client stamp may lag behind the server clock
local CLAIM_TOLERANCE = 24  -- studs between the claimed part and the raptor body (the server sees a 70 studs/s lunge
                            -- late and targets in rest pose; 14 rejected a latch on a walking T-Rex at 15.1)
local OFFSET_MAX = 8        -- studs the latch spot may sit from the part's centre beyond its half size
local MAX_LATCH = 30        -- safety: seconds a latch may last

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local requestRemote = remote("DinoPounceRequest")
local claimRemote = remote("DinoPounceClaim")
local releaseRemote = remote("DinoPounceRelease")

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local function stamina(char, now)
	local max = get(char, "StaminaMax")
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local function alive(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- the latchable model a hitbox part belongs to (nil if none)
local function targetOf(part)
	local folder = part.Parent
	if not (folder and folder.Name == "Hitboxes") then return nil end
	local model = folder.Parent
	if not (model and model:IsA("Model") and model:IsDescendantOf(workspace)) then return nil end
	if model:GetAttribute("Bitable") ~= true or model:GetAttribute("Species") == nil then return nil end
	return model
end

local function sizeOf(model)
	return model:GetExtentsSize().Magnitude
end

local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

local pending = {}   -- [char] = {stamp, start}
local latches = {}   -- [char] = {model, part, nextTick, at}
local lastAccepted = setmetatable({}, {__mode = "k"})

local function latchValue(char)
	local v = char:FindFirstChild("PounceLatchPart")
	if not v then
		v = Instance.new("ObjectValue")
		v.Name = "PounceLatchPart"
		v.Parent = char
	end
	return v
end

local function hit(char, model, dmg, now)
	local mul = 1
	local untilT, dmul = model:GetAttribute("DebuffUntil"), model:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and now < untilT then mul = dmul end
	local d = math.floor(dmg * mul + 0.5)
	local hp = model:GetAttribute("DummyHealth")
	if typeof(hp) == "number" then model:SetAttribute("DummyHealth", math.max(0, hp - d)) end
	char:SetAttribute("PounceHitDamage", d)
	char:SetAttribute("PounceDamageTotal", (char:GetAttribute("PounceDamageTotal") or 0) + d)
	char:SetAttribute("PounceBiteAt", now)
end

local function release(char, reason)
	if not latches[char] then return end
	latches[char] = nil
	local v = char:FindFirstChild("PounceLatchPart")
	if v then v.Value = nil end
	char:SetAttribute("PounceLatched", false)
	char:SetAttribute("PounceReleasedAt", workspace:GetServerTimeNow())
	char:SetAttribute("PounceReleaseReason", reason)
end

requestRemote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not alive(char) then
		result = "dead"
	elseif get(char, "PounceEnabled") ~= true then
		result = "disabled"
	elseif latches[char] then
		result = "latched"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) < get(char, "PounceStaminaCost") then
		result = "stamina"
	elseif lastAccepted[char] and now - lastAccepted[char] < get(char, "PounceCooldown") then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("PounceServerResult", result)
	if result == "ok" then
		lastAccepted[char] = now
		local start = math.clamp(stamp, now - MAX_LAG, now)
		pending[char] = {stamp = stamp, start = start}
		char:SetAttribute("PounceCount", (char:GetAttribute("PounceCount") or 0) + 1)
		char:SetAttribute("PounceStartedAt", start)
	elseif result ~= "badArg" then
		char:SetAttribute("PounceDenyReason", result)
		char:SetAttribute("PounceDeniedAt", stamp)
	end
end)

claimRemote.OnServerEvent:Connect(function(player, stamp, part, offset)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local p = pending[char]
	local result, model
	if typeof(stamp) ~= "number" or typeof(part) ~= "Instance" or not part:IsA("BasePart") or typeof(offset) ~= "CFrame" then
		result = "badArg"
	elseif not p or p.stamp ~= stamp then
		result = "noPounce"
	elseif now - p.start > get(char, "PounceClaimWindow") then
		result = "late"
	else
		model = targetOf(part)
		if not model or model == char or model:GetAttribute("DummyState") == "ko" then
			result = "badTarget"
		elseif sizeOf(model) < sizeOf(char) * get(char, "PounceSizeRatio") then
			result = "small"
		else
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local dist = hrp and (closestPoint(part, hrp.Position) - hrp.Position).Magnitude or math.huge
			char:SetAttribute("PounceClaimDist", math.floor(dist * 10 + 0.5) / 10)
			if dist > CLAIM_TOLERANCE then
				result = "far"
			elseif offset.Position.Magnitude > part.Size.Magnitude / 2 + OFFSET_MAX then
				result = "badOffset"
			elseif not alive(char) then
				result = "dead"
			else
				result = "ok"
			end
		end
	end
	char:SetAttribute("PounceClaimResult", result)
	if result ~= "ok" then return end
	pending[char] = nil
	latches[char] = {model = model, part = part, at = now, nextTick = now + get(char, "PounceTickInterval")}
	latchValue(char).Value = part
	char:SetAttribute("PounceLatchOffset", offset)
	char:SetAttribute("PounceLatchTarget", model.Name)
	char:SetAttribute("PounceLatchSegment", part:GetAttribute("HitboxSegment"))
	char:SetAttribute("PounceDamageTotal", 0)
	char:SetAttribute("PounceLatchedAt", now)
	char:SetAttribute("PounceLatchCount", (char:GetAttribute("PounceLatchCount") or 0) + 1)
	char:SetAttribute("PounceLatched", true) -- last: clients read the rest from here
	hit(char, model, get(char, "PounceLandDamage"), now)
end)

releaseRemote.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char then release(char, "jump") end
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for char, l in pairs(latches) do
		if not char.Parent or not alive(char) then
			release(char, "dead")
		elseif get(char, "PounceEnabled") ~= true then
			release(char, "disabled")
		elseif not l.part.Parent or not l.model:IsDescendantOf(workspace) then
			release(char, "gone")
		elseif l.model:GetAttribute("DummyState") == "ko" or (l.model:GetAttribute("DummyHealth") or 1) <= 0 then
			release(char, "ko")
		elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) <= 0 then
			release(char, "stamina")
		elseif now - l.at > MAX_LATCH then
			release(char, "timeout")
		elseif now >= l.nextTick then
			l.nextTick += get(char, "PounceTickInterval")
			hit(char, l.model, get(char, "PounceTickDamage"), now)
		end
	end
	for char, p in pairs(pending) do
		if not char.Parent or now - p.start > get(char, "PounceClaimWindow") + 0.5 then pending[char] = nil end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		latches[player.Character] = nil
		pending[player.Character] = nil
	end
end)
