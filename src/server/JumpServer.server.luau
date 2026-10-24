-- JumpServer v1.0 (Dino Arcade) — TEST. Validates leap requests and stamps the start time for every client.
-- Client -> server: ReplicatedStorage.DinoJumpRequest:FireServer(clientServerTime) (sent by JumpTest 1.0 at the
--   key press, i.e. the start of the crouch).
-- Start time = the client's stamp clamped to [now - MAX_LAG, now], written to the character attribute
--   JumpStartedAt (replicates; IdleAnimation 1.15 / JumpPose 1.0 draw the crouch from it, StaminaServer 1.1
--   charges JumpStaminaCost for each new value).
-- Checks, in order (first failing one is the result):
--   "badArg"    stamp is not a number
--   "dead"      no character / Humanoid health <= 0
--   "disabled"  JumpEnabled ~= true (default false: only species that turn it on, e.g. Raptor, can leap)
--   "exhausted" Exhausted == true (StaminaServer)
--   "stamina"   current stamina < JumpStaminaCost (StaminaEnabled ~= false only)
--   "cooldown"  less than JumpCooldown seconds since the last accepted leap
--   accepted -> "ok"
-- Denied: JumpDeniedAt = the client stamp (unclamped, so JumpTest can match it) + JumpDenyReason; JumpTest
--   cancels the launch if this arrives during the crouch.
-- Physics (launch height, forward boost, air speed) is done by the owner's client (network owner); the server
--   only gates the request and its stamina cost.
-- Settings (character attributes): JumpEnabled (default false), JumpStaminaCost (15), JumpCooldown (0.5).
-- Diagnostics (character attributes): JumpServerResult (last result above), JumpCount (accepted leaps),
--   JumpDenyCount, JumpDeniedAt, JumpDenyReason.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULTS = {JumpEnabled = false, JumpStaminaCost = 15, JumpCooldown = 0.5, StaminaEnabled = true,
	StaminaMax = 100}
local MAX_LAG = 0.3 -- seconds a client stamp may lag behind the server clock (same as BiteServer)

local remote = ReplicatedStorage:FindFirstChild("DinoJumpRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoJumpRequest"
	remote.Parent = ReplicatedStorage
end

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- stamina now, from StaminaServer's replicated curve (same formula as StaminaServer 1.0)
local function stamina(char, now)
	local max = get(char, "StaminaMax")
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local lastAccepted = {} -- character -> server time of the last accepted leap (weak keys)
setmetatable(lastAccepted, {__mode = "k"})

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local result
	local hum = char:FindFirstChildOfClass("Humanoid")
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif get(char, "JumpEnabled") ~= true then
		result = "disabled"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) < get(char, "JumpStaminaCost") then
		result = "stamina"
	elseif lastAccepted[char] and now - lastAccepted[char] < get(char, "JumpCooldown") then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("JumpServerResult", result)
	if result == "ok" then
		lastAccepted[char] = now
		char:SetAttribute("JumpCount", (char:GetAttribute("JumpCount") or 0) + 1)
		char:SetAttribute("JumpStartedAt", math.clamp(stamp, now - MAX_LAG, now))
	elseif result ~= "badArg" then
		char:SetAttribute("JumpDenyCount", (char:GetAttribute("JumpDenyCount") or 0) + 1)
		char:SetAttribute("JumpDenyReason", result)
		char:SetAttribute("JumpDeniedAt", stamp)
	end
end)
