-- KillRegenServer v1.0 (Dino Arcade) — TEST. Health back after a kill.
-- User: "add health regen after a kill". Answers: a kill = the killing blow on a bot (player-vs-player kills later, once
--   PvP damage exists); the killer gets 25% of their max health back over 5 s.
-- Kill: BiteServer 1.6 / PounceServer 1.3 stamp the killing blow on the bot: KilledBy (player name), KilledByUserId,
--   KilledWith ("bite" / "pounce") and, last, KilledAt (server time). This script watches every model with IsBot = true
--   (DinoIsland.Bots, BotServer) for a new KilledAt and credits that player.
-- Regen: the killer's living character gets a regen stream of KillRegenFraction x Humanoid.MaxHealth spread evenly over
--   KillRegenTime seconds (Heartbeat), never above MaxHealth. Each kill adds its own stream (two kills close together
--   heal both amounts). Streams stop when the character dies or is removed. No regen otherwise (DinoHealthServer 1.0
--   still removes Roblox's default "Health" script).
-- Not credited (bot attribute KillRegenCredited): "noPlayer" (killer left / unknown), "dead" (killer dead or no
--   character), "disabled" (killer's KillRegenEnabled = false); otherwise the killer's name.
-- Settings (character attributes): KillRegenEnabled (default true), KillRegenFraction (default 0.25),
--   KillRegenTime (default 5).
-- Diagnostics: character KillRegenActive (true while any stream runs), KillRegenRemaining (HP still to come, whole),
--   KillRegenLastAmount, KillRegenLastAt (server time), KillRegenHealed (HP actually added, total, whole;
--   KillRegenHealedExact = the same unrounded),
--   KillCount, LastKillTarget, LastKillWith; player DinoKills; bot KillRegenCredited; script KillRegenServerVersion,
--   KillRegenKills (total credited).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local DEFAULTS = {KillRegenEnabled = true, KillRegenFraction = 0.25, KillRegenTime = 5}

script:SetAttribute("KillRegenServerVersion", VERSION)
script:SetAttribute("KillRegenKills", 0)

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local streams = {} -- [char] = {{left = HP still to give, rate = HP per second}, ...}

local function remaining(list)
	local r = 0
	for _, s in ipairs(list) do r += s.left end
	return r
end

local function credit(bot)
	local at = bot:GetAttribute("KilledAt")
	if typeof(at) ~= "number" then return end
	local player = Players:GetPlayerByUserId(bot:GetAttribute("KilledByUserId") or 0)
		or Players:FindFirstChild(tostring(bot:GetAttribute("KilledBy")))
	if not player then
		bot:SetAttribute("KillRegenCredited", "noPlayer")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		bot:SetAttribute("KillRegenCredited", "dead")
		return
	end
	player:SetAttribute("DinoKills", (player:GetAttribute("DinoKills") or 0) + 1)
	char:SetAttribute("KillCount", (char:GetAttribute("KillCount") or 0) + 1)
	char:SetAttribute("LastKillTarget", bot.Name)
	char:SetAttribute("LastKillWith", tostring(bot:GetAttribute("KilledWith")))
	script:SetAttribute("KillRegenKills", (script:GetAttribute("KillRegenKills") or 0) + 1)
	if get(char, "KillRegenEnabled") == false then
		bot:SetAttribute("KillRegenCredited", "disabled")
		return
	end
	local amount = hum.MaxHealth * get(char, "KillRegenFraction")
	local duration = math.max(0.05, get(char, "KillRegenTime"))
	local list = streams[char]
	if not list then
		list = {}
		streams[char] = list
	end
	table.insert(list, {left = amount, rate = amount / duration})
	char:SetAttribute("KillRegenLastAmount", math.floor(amount + 0.5))
	char:SetAttribute("KillRegenLastAt", workspace:GetServerTimeNow())
	char:SetAttribute("KillRegenActive", true)
	char:SetAttribute("KillRegenRemaining", math.floor(remaining(list) + 0.5))
	bot:SetAttribute("KillRegenCredited", player.Name)
end

-- watch bots
local watched = setmetatable({}, {__mode = "k"})
local function watch(m)
	if watched[m] or not m:IsA("Model") or m:GetAttribute("IsBot") ~= true then return end
	watched[m] = true
	m:GetAttributeChangedSignal("KilledAt"):Connect(function() credit(m) end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		if d:GetAttribute("IsBot") == true then
			watch(d)
		else
			-- BotServer sets IsBot right after cloning; catch it when it arrives
			local conn
			conn = d:GetAttributeChangedSignal("IsBot"):Connect(function()
				conn:Disconnect()
				watch(d)
			end)
			task.delay(2, function() if conn.Connected then conn:Disconnect() end end)
		end
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end

-- heal
RunService.Heartbeat:Connect(function(dt)
	for char, list in pairs(streams) do
		local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			streams[char] = nil
			if char.Parent then
				char:SetAttribute("KillRegenActive", false)
				char:SetAttribute("KillRegenRemaining", 0)
			end
			continue
		end
		local give = 0
		for i = #list, 1, -1 do
			local s = list[i]
			local step = math.min(s.left, s.rate * dt)
			s.left -= step
			give += step
			if s.left <= 1e-6 then table.remove(list, i) end
		end
		local before = hum.Health
		hum.Health = math.min(hum.MaxHealth, before + give)
		local added = hum.Health - before
		if added > 0 then
			char:SetAttribute("KillRegenHealed", math.floor((char:GetAttribute("KillRegenHealedExact") or 0) + added + 0.5))
			char:SetAttribute("KillRegenHealedExact", (char:GetAttribute("KillRegenHealedExact") or 0) + added)
		end
		local rem = math.floor(remaining(list) + 0.5)
		if char:GetAttribute("KillRegenRemaining") ~= rem then char:SetAttribute("KillRegenRemaining", rem) end
		if #list == 0 then
			streams[char] = nil
			char:SetAttribute("KillRegenActive", false)
		end
	end
end)
