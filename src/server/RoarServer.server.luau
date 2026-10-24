-- RoarServer v1.0 (Dino Arcade) — TEST. Validates roar requests from players and stamps the start time.
-- Client -> server: ReplicatedStorage.DinoRoarRequest:FireServer()
-- Server -> everyone: character attribute RoarStartedAt = workspace:GetServerTimeNow() (replicates), which
--   every client's IdleAnimation (pose) and RoarFX (sound + rings) read, so all players see the same roar.
-- Checks: character alive, RoarEnabled ~= false, cooldown RoarCooldown (character attribute, default 3 s).
-- Diagnostics (character attributes): RoarCount (accepted roars), RoarLastResult ("ok" / "cooldown" / "disabled").
-- Gameplay effects (Roar of Terror debuff + slow on enemies, SRD §4) are NOT applied yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("DinoRoarRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoRoarRequest"
	remote.Parent = ReplicatedStorage
end

local DEFAULT_COOLDOWN = 3

remote.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if char:GetAttribute("RoarEnabled") == false then
		char:SetAttribute("RoarLastResult", "disabled")
		return
	end
	local now = workspace:GetServerTimeNow()
	local last = char:GetAttribute("RoarStartedAt")
	local cooldown = char:GetAttribute("RoarCooldown") or DEFAULT_COOLDOWN
	if last and now - last < cooldown then
		char:SetAttribute("RoarLastResult", "cooldown")
		return
	end
	char:SetAttribute("RoarStartedAt", now)
	char:SetAttribute("RoarCount", (char:GetAttribute("RoarCount") or 0) + 1)
	char:SetAttribute("RoarLastResult", "ok")
end)
