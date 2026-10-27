-- RamServer v1.1 (Dino Arcade) — TEST. Validates the T-Rex tree charge ("a dedicated button that makes a dino run into
-- the nearest tree") and stamps it so every client shows it (IdleAnimation 1.19 / RamPose 1.0) and ShakeOffServer 1.1
-- can knock latched raptors off on the impact.
-- Client -> server (sent by RamTest 1.0):
--   DinoRamRequest:FireServer(stamp, trunkPart)     at the key press (stamp = the client's server time)
--   DinoRamImpact:FireServer(stamp, hit)            hit = true: the body reached the trunk; false: the charge ended
--                                                   without reaching it (RamMaxCharge s, blocked, cancelled)
-- Request checks, in order: "badArg", "dead", "disabled" (RamEnabled ~= true), "stunned" (StunnedUntil in the future),
--   "latched" (PounceLatched: a raptor riding something), "busy" (a ram is already running), "exhausted",
--   "stamina" (stamina < RamStaminaCost, StaminaEnabled ~= false), "cooldown" (RamCooldown s since the last accepted
--   ram), "badTree" (the part is not a trunk / root of a DinoIsland.Trees model), "far" (trunk more than RamRange +
--   RANGE_TOLERANCE studs flat from the HumanoidRootPart) -> "ok": RamStartedAt = stamp clamped to [now - MAX_LAG, now]
--   (replicates; StaminaServer 1.3 charges RamStaminaCost for each new value), RamTargetTree (tree model name),
--   RamCount + 1. Denied: RamDeniedAt = the client stamp, RamDenyReason.
-- Impact checks: "badArg", "noRam" (stamp is not the running ram), "late" (more than RamWindup + RamMaxCharge +
--   IMPACT_GRACE s after the start), then for hit = true "farImpact" (the trunk's nearest point more than
--   IMPACT_TOLERANCE studs from the body: HumanoidRootPart and Hitboxes as the server sees them; the server sees a
--   44 studs/s charge ~5-10 studs behind, so a far body is re-checked every Heartbeat for IMPACT_WAIT s, result
--   "waiting", before it counts as "farImpact") -> "hit":
--   RamImpactPoint (Vector3, the trunk's flat centre at body height; the raptors are tossed away from it),
--   RamImpactAt = now (ShakeOffServer 1.1 reacts to this one), RamImpactCount + 1. Every accepted end (hit, "miss",
--   or a "farImpact" counted as a miss) sets RamEndedAt = now and RamResult.
-- Safety: a running ram with no impact message RamWindup + RamMaxCharge + IMPACT_GRACE s after its start ends with
--   RamResult "timeout" (RamEndedAt set).
-- Settings (character attributes, defaults = RamPose 1.0): RamEnabled (false), RamWindup 0.4, RamRange 60,
--   RamStaminaCost 20, RamCooldown 6, RamMaxCharge 3.5.
-- Diagnostics (character attributes): RamServerResult (request result), RamImpactResult, RamResult ("hit" / "miss" /
--   "timeout"), RamImpactDist (studs, 0.1 steps), RamCount, RamImpactCount; script attribute RamServerVersion.
-- v1.1: ram only while latched on (user: "ram should only be able to happen when latched by a dino").
--   LatchedOnCount (character attribute, every player character, refreshed every LATCH_TICK s) = raptors (player
--   characters and DinoIsland.Bots) with PounceLatched = true, PounceMode ~= "pin" and a PounceLatchPart inside this
--   character (the same rule ShakeOffServer 1.1 uses to find who to shake off). New request check after "latched":
--   "notLatchedOn" when RamRequiresLatchOn (character attribute, default true) ~= false and the count, taken at the
--   request, is 0. A ram already accepted is not stopped when the raptors let go. Bots (BotServer 1.3) are unchanged:
--   they already ram only while a player raptor is latched on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local DEFAULTS = {RamEnabled = false, RamWindup = 0.4, RamRange = 60, RamStaminaCost = 20, RamCooldown = 6,
	RamMaxCharge = 3.5, StaminaEnabled = true, StaminaMax = 100}
DEFAULTS.RamRequiresLatchOn = true -- v1.1
local LATCH_TICK = 0.1 -- v1.1: s between LatchedOnCount refreshes
local MAX_LAG = 0.3          -- seconds a client stamp may lag behind the server clock
local RANGE_TOLERANCE = 8    -- studs beyond RamRange a request may be (the server sees the body a little late)
local IMPACT_TOLERANCE = 10  -- studs between the trunk and the body for a hit
local IMPACT_GRACE = 1       -- seconds past the longest charge an impact message is still taken
local IMPACT_WAIT = 0.6      -- seconds a far impact is re-checked while the server's copy of the body catches up

script:SetAttribute("RamServerVersion", VERSION)

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local requestRemote = remote("DinoRamRequest")
local impactRemote = remote("DinoRamImpact")

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

local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- the tree model (child of DinoIsland.Trees) a trunk / root part belongs to, or nil
local function treeOf(part)
	if not (part:IsA("BasePart") and (part.Name:find("^Trunk") or part.Name == "Root")) then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local trees = island and island:FindFirstChild("Trees")
	if not trees or not part:IsDescendantOf(trees) then return nil end
	local m = part
	while m and m.Parent ~= trees do m = m.Parent end
	return m
end

-- trunk / root parts of a tree
local function trunkParts(tree)
	local list = {}
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name:find("^Trunk") or d.Name == "Root") then table.insert(list, d) end
	end
	return list
end

-- smallest distance between the tree's trunk parts and the body (HumanoidRootPart + Hitboxes)
local function bodyGap(char, tree)
	local parts = {}
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then table.insert(parts, hrp) end
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do if p:IsA("BasePart") then table.insert(parts, p) end end
	end
	local best = math.huge
	for _, t in ipairs(trunkParts(tree)) do
		for _, p in ipairs(parts) do
			local a = closestPoint(t, p.Position)
			local b = closestPoint(p, a)
			best = math.min(best, (a - b).Magnitude)
		end
	end
	return best
end

local running = {} -- [char] = {stamp, start, tree, trunk}
local lastAccepted = setmetatable({}, {__mode = "k"})

local function finish(char, result, now)
	running[char] = nil
	char:SetAttribute("RamResult", result)
	char:SetAttribute("RamEndedAt", now)
end

local function hitTree(char, r, now)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local tp = r.trunk.Parent and r.trunk.Position or (hrp and hrp.Position) or Vector3.zero
	char:SetAttribute("RamImpactPoint", Vector3.new(tp.X, hrp and hrp.Position.Y or tp.Y, tp.Z))
	char:SetAttribute("RamImpactCount", (char:GetAttribute("RamImpactCount") or 0) + 1)
	char:SetAttribute("RamImpactAt", now)
	finish(char, "hit", now)
end

-- v1.1: raptors latched on a character (ShakeOffServer 1.1 rule: latched, not a pin, latch part inside the target)
local function latchedOnCounts()
	local counts = {}
	local function consider(m)
		if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return end
		local v = m:FindFirstChild("PounceLatchPart")
		local part = v and v.Value
		if not part or not part:IsDescendantOf(workspace) then return end
		local folder = part.Parent
		local target = folder and folder.Name == "Hitboxes" and folder.Parent or part:FindFirstAncestorWhichIsA("Model")
		if not target or target == m then return end
		counts[target] = (counts[target] or 0) + 1
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then consider(pl.Character) end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do consider(m) end
	end
	return counts
end
local function latchedOnCount(char)
	return latchedOnCounts()[char] or 0
end
local latchAcc = 0
RunService.Heartbeat:Connect(function(dt)
	latchAcc += dt
	if latchAcc < LATCH_TICK then return end
	latchAcc = 0
	local counts = latchedOnCounts()
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		if char then
			local n = counts[char] or 0
			if char:GetAttribute("LatchedOnCount") ~= n then char:SetAttribute("LatchedOnCount", n) end
		end
	end
end)

requestRemote.OnServerEvent:Connect(function(player, stamp, trunk)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local result, tree
	if typeof(stamp) ~= "number" or stamp ~= stamp or typeof(trunk) ~= "Instance" then
		result = "badArg"
	elseif not alive(char) then
		result = "dead"
	elseif get(char, "RamEnabled") ~= true then
		result = "disabled"
	elseif (char:GetAttribute("StunnedUntil") or 0) > now then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif get(char, "RamRequiresLatchOn") ~= false and latchedOnCount(char) == 0 then -- v1.1
		result = "notLatchedOn"
	elseif running[char] then
		result = "busy"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) < get(char, "RamStaminaCost") then
		result = "stamina"
	elseif lastAccepted[char] and now - lastAccepted[char] < get(char, "RamCooldown") then
		result = "cooldown"
	else
		tree = treeOf(trunk)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not tree then
			result = "badTree"
		elseif not hrp or flat(trunk.Position - hrp.Position).Magnitude > get(char, "RamRange") + RANGE_TOLERANCE then
			result = "far"
		else
			result = "ok"
		end
	end
	char:SetAttribute("RamServerResult", result)
	if result == "ok" then
		lastAccepted[char] = now
		local start = math.clamp(stamp, now - MAX_LAG, now)
		running[char] = {stamp = stamp, start = start, tree = tree, trunk = trunk}
		char:SetAttribute("RamTargetTree", tree.Name)
		char:SetAttribute("RamCount", (char:GetAttribute("RamCount") or 0) + 1)
		char:SetAttribute("RamStartedAt", start) -- last: clients and StaminaServer react to this one
	elseif result ~= "badArg" then
		char:SetAttribute("RamDenyReason", result)
		char:SetAttribute("RamDeniedAt", stamp)
	end
end)

impactRemote.OnServerEvent:Connect(function(player, stamp, hit)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local r = running[char]
	local result
	if typeof(stamp) ~= "number" or typeof(hit) ~= "boolean" then
		result = "badArg"
	elseif not r or r.stamp ~= stamp then
		result = "noRam"
	elseif now - r.start > get(char, "RamWindup") + get(char, "RamMaxCharge") + IMPACT_GRACE then
		result = "late"
	elseif not hit then
		result = "miss"
	elseif not r.tree.Parent then
		result = "farImpact"
	else
		local gap = bodyGap(char, r.tree)
		char:SetAttribute("RamImpactDist", math.floor(gap * 10 + 0.5) / 10)
		result = gap <= IMPACT_TOLERANCE and "hit" or "farImpact"
	end
	if result == "farImpact" and r.tree.Parent then -- the server's copy of the body may still be catching up
		r.waitUntil = now + IMPACT_WAIT
		result = "waiting"
	end
	char:SetAttribute("RamImpactResult", result)
	if result == "hit" then
		hitTree(char, r, now)
	elseif result == "miss" or result == "farImpact" then
		finish(char, "miss", now)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for char, r in pairs(running) do
		if not char.Parent or not alive(char) then
			running[char] = nil
		elseif r.waitUntil then -- far impact: re-check until the body is near enough or the wait is over
			local gap = r.tree.Parent and bodyGap(char, r.tree) or math.huge
			char:SetAttribute("RamImpactDist", math.floor(gap * 10 + 0.5) / 10)
			if gap <= IMPACT_TOLERANCE then
				char:SetAttribute("RamImpactResult", "hit")
				hitTree(char, r, now)
			elseif now > r.waitUntil then
				char:SetAttribute("RamImpactResult", "farImpact")
				finish(char, "miss", now)
			end
		elseif now - r.start > get(char, "RamWindup") + get(char, "RamMaxCharge") + IMPACT_GRACE then
			finish(char, "timeout", now)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then running[player.Character] = nil end
end)
