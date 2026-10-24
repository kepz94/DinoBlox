-- CreepServer v1.1 (Dino Arcade) — TEST. Shares each player's creep state with everyone.
-- Client -> server: ReplicatedStorage.DinoCreepRequest:FireServer(wanted: boolean) (sent by CreepTest)
-- Server -> everyone: character attribute Creeping (true/false, replicates), read by every client's
--   IdleAnimation for the crouched pose / creep gait.
-- Checks: argument is a boolean, character alive, CreepEnabled ~= false (a false request is always accepted).
-- Diagnostics (character attributes): CreepLastResult ("on" / "off" / "disabled" / "dead" / "badArg").
-- Gameplay effects (stealth / detection radius) are NOT applied yet.
-- v1.1: exhaustion crouch. Creeping = the player's request (CreepWanted) OR Exhausted (StaminaServer 1.0), so an
--   exhausted dino crouch-walks until it recovers, then returns to whatever the player is holding.
--   Re-evaluated on every request and whenever Exhausted changes. Diagnostic: CreepWanted (last accepted request).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:FindFirstChild("DinoCreepRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoCreepRequest"
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player, wanted)
	local char = player.Character
	if not char then return end
	if typeof(wanted) ~= "boolean" then
		char:SetAttribute("CreepLastResult", "badArg")
		return
	end
	if wanted then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			char:SetAttribute("CreepLastResult", "dead")
			return
		end
		if char:GetAttribute("CreepEnabled") == false then
			char:SetAttribute("CreepLastResult", "disabled")
			return
		end
	end
	char:SetAttribute("CreepWanted", wanted) -- v1.1
	char:SetAttribute("Creeping", wanted or char:GetAttribute("Exhausted") == true) -- v1.1: exhausted holds the crouch
	char:SetAttribute("CreepLastResult", wanted and "on" or "off")
end)

-- v1.1: follow exhaustion (StaminaServer 1.0)
local function onCharacter(char)
	char:GetAttributeChangedSignal("Exhausted"):Connect(function()
		local creeping = char:GetAttribute("CreepWanted") == true or char:GetAttribute("Exhausted") == true
		if char:GetAttribute("Creeping") ~= creeping then char:SetAttribute("Creeping", creeping) end
	end)
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
