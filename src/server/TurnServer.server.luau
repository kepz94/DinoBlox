-- TurnServer v1.0 (Dino Arcade) — shares each player's "turn still to go" so every client can show the
-- head leading the body into a turn (HeadLeadPose 1.0 in IdleAnimation).
-- Client -> server: ReplicatedStorage.DinoTurnError:FireServer(errorDeg: number) (sent by TurnLimit 1.0,
--   whole degrees, positive = left, at most 20 per second).
-- Server -> everyone: character attribute TurnError (whole degrees, -180..180, replicates).
-- Checks: argument is a finite number; character exists; at most MAX_PER_SECOND events per player per
--   second; a dead character is set to 0.
-- Diagnostics (character attributes): TurnErrorLastResult = "ok" / "badArg" / "rateLimited" / "dead"
--   (written only when it changes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MAX_PER_SECOND = 30

local remote = ReplicatedStorage:FindFirstChild("DinoTurnError")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTurnError"
	remote.Parent = ReplicatedStorage
end

local windows = {} -- player -> {start = os.clock(), count = n}

local function result(char, r)
	if char:GetAttribute("TurnErrorLastResult") ~= r then char:SetAttribute("TurnErrorLastResult", r) end
end

remote.OnServerEvent:Connect(function(player, e)
	local char = player.Character
	if not char then return end
	if typeof(e) ~= "number" or e ~= e or math.abs(e) == math.huge then
		return result(char, "badArg")
	end
	local now = os.clock()
	local w = windows[player]
	if not w or now - w.start >= 1 then
		w = {start = now, count = 0}
		windows[player] = w
	end
	w.count += 1
	if w.count > MAX_PER_SECOND then return result(char, "rateLimited") end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		char:SetAttribute("TurnError", 0)
		return result(char, "dead")
	end
	local v = math.clamp(math.floor(e + 0.5), -180, 180)
	if char:GetAttribute("TurnError") ~= v then char:SetAttribute("TurnError", v) end
	result(char, "ok")
end)

Players.PlayerRemoving:Connect(function(player)
	windows[player] = nil
end)
