-- StaminaServer v1.0 (Dino Arcade) — TEST. Server-owned stamina for every player dino.
-- Stamina is stored as a straight-line curve so every client can draw it smoothly without updates:
--   stamina(now) = clamp(StaminaValue + StaminaRate * (now - StaminaAt), 0, StaminaMax)
--   (replicated character attributes; StaminaAt is server time, written last on every change).
-- The server checks every Heartbeat which rate applies and re-anchors the curve when it changes:
--   running   -> -StaminaMax / StaminaRunTime   (run wanted, not exhausted, moving faster than halfway
--                between MoveWalkSpeed and MoveRunSpeed — so Shift while standing, creeping or roaring
--                does not drain)
--   delay     -> 0 until StaminaRegenUntil (StaminaRegenDelay s after the last run or bite)
--   refilling -> +StaminaMax / StaminaRefillTime until full
--   full      -> 0
-- Bites: every accepted bite (BiteServer sets a new BiteStartedAt) costs StaminaBiteCost, clamped at 0. Bites
--   are never blocked by stamina.
-- Exhaustion: when stamina reaches 0 (running or biting), Exhausted = true (replicated): SprintTest 1.4 blocks
--   running and uses MoveCreepSpeed, CreepServer 1.1 holds Creeping = true (crouch walk). Refill works as
--   normal; at StaminaRecoverFraction x StaminaMax (default 25%) Exhausted = false.
-- Client -> server: ReplicatedStorage.DinoRunRequest:FireServer(wanted: boolean) (sent by SprintTest 1.4).
-- Settings (character attributes): StaminaEnabled (default true; false = always full, never exhausted),
--   StaminaMax 100, StaminaRunTime 15, StaminaRefillTime 5, StaminaBiteCost 10, StaminaRegenDelay 0.75,
--   StaminaRecoverFraction 0.25.
-- Diagnostics (character attributes): StaminaState ("full" / "running" / "delay" / "refilling" / "exhausted" /
--   "disabled"), StaminaLastEvent ("run" / "bite" / "exhausted" / "recovered" / "full"), StaminaRunWanted,
--   StaminaBiteCount, StaminaExhaustCount, Exhausted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULTS = {StaminaEnabled = true, StaminaMax = 100, StaminaRunTime = 15, StaminaRefillTime = 5,
	StaminaBiteCost = 10, StaminaRegenDelay = 0.75, StaminaRecoverFraction = 0.25,
	MoveWalkSpeed = 20, MoveRunSpeed = 44}

local remote = ReplicatedStorage:FindFirstChild("DinoRunRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoRunRequest"
	remote.Parent = ReplicatedStorage
end

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local states = {} -- char -> {runWanted, regenUntil, lastBite}

local function current(char, now)
	local value = char:GetAttribute("StaminaValue") or get(char, "StaminaMax")
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, get(char, "StaminaMax"))
end

local function anchor(char, value, rate, now)
	char:SetAttribute("StaminaValue", value)
	char:SetAttribute("StaminaRate", rate)
	char:SetAttribute("StaminaAt", now) -- last: clients recompute from this
end

local function setIf(char, k, v)
	if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end
end

local function step(char, st, now)
	local max = get(char, "StaminaMax")
	if get(char, "StaminaEnabled") == false then
		if current(char, now) < max or (char:GetAttribute("StaminaRate") or 0) ~= 0 then anchor(char, max, 0, now) end
		setIf(char, "Exhausted", false)
		setIf(char, "StaminaState", "disabled")
		return
	end
	local s = current(char, now)
	local exhausted = char:GetAttribute("Exhausted") == true
	-- exhaustion and recovery
	if not exhausted and s <= 0 then
		exhausted = true
		char:SetAttribute("Exhausted", true)
		char:SetAttribute("StaminaExhaustCount", (char:GetAttribute("StaminaExhaustCount") or 0) + 1)
		char:SetAttribute("StaminaLastEvent", "exhausted")
		st.regenUntil = now + get(char, "StaminaRegenDelay")
	elseif exhausted and s >= max * get(char, "StaminaRecoverFraction") then
		exhausted = false
		char:SetAttribute("Exhausted", false)
		char:SetAttribute("StaminaLastEvent", "recovered")
	end
	-- is the dino really running? (horizontal speed past halfway between walk and run speed)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local v = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local runLine = (get(char, "MoveWalkSpeed") + get(char, "MoveRunSpeed")) / 2
	local running = st.runWanted and not exhausted and speed > runLine
	local rate, state
	if running and s > 0 then
		rate, state = -max / get(char, "StaminaRunTime"), "running"
		st.regenUntil = now + get(char, "StaminaRegenDelay")
	elseif now < st.regenUntil then
		rate, state = 0, "delay"
	elseif s < max then
		rate, state = max / get(char, "StaminaRefillTime"), "refilling"
	else
		rate, state = 0, "full"
	end
	if exhausted then state = "exhausted" end
	if rate ~= (char:GetAttribute("StaminaRate") or 0) then
		anchor(char, s, rate, now)
		if state == "running" then char:SetAttribute("StaminaLastEvent", "run") end
		if state == "full" then char:SetAttribute("StaminaLastEvent", "full") end
	end
	setIf(char, "StaminaState", state)
end

local function onCharacter(char)
	local now = workspace:GetServerTimeNow()
	local st = {runWanted = false, regenUntil = 0, lastBite = char:GetAttribute("BiteStartedAt")}
	states[char] = st
	anchor(char, get(char, "StaminaMax"), 0, now)
	char:SetAttribute("Exhausted", false)
	char:SetAttribute("StaminaRunWanted", false)
	char:SetAttribute("StaminaBiteCount", 0)
	char:SetAttribute("StaminaExhaustCount", 0)
	char:SetAttribute("StaminaState", "full")
	-- each accepted bite (BiteServer writes a new BiteStartedAt) costs stamina
	char:GetAttributeChangedSignal("BiteStartedAt"):Connect(function()
		local at = char:GetAttribute("BiteStartedAt")
		if at == nil or at == st.lastBite then return end
		st.lastBite = at
		if get(char, "StaminaEnabled") == false then return end
		local t = workspace:GetServerTimeNow()
		local s = math.max(0, current(char, t) - get(char, "StaminaBiteCost"))
		st.regenUntil = t + get(char, "StaminaRegenDelay")
		anchor(char, s, 0, t)
		char:SetAttribute("StaminaBiteCount", (char:GetAttribute("StaminaBiteCount") or 0) + 1)
		char:SetAttribute("StaminaLastEvent", "bite")
		step(char, st, t) -- exhaustion check right away
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then states[char] = nil end
	end)
end

remote.OnServerEvent:Connect(function(player, wanted)
	local char = player.Character
	local st = char and states[char]
	if not st or typeof(wanted) ~= "boolean" then return end
	st.runWanted = wanted
	char:SetAttribute("StaminaRunWanted", wanted)
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for char, st in pairs(states) do
		if char.Parent then step(char, st, now) end
	end
end)
