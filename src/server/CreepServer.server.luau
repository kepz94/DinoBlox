-- CreepServer v1.0 (Dino Arcade) — TEST. Shares each player's creep state with everyone.
-- Client -> server: ReplicatedStorage.DinoCreepRequest:FireServer(wanted: boolean) (sent by CreepTest)
-- Server -> everyone: character attribute Creeping (true/false, replicates), read by every client's
--   IdleAnimation for the crouched pose / creep gait.
-- Checks: argument is a boolean, character alive, CreepEnabled ~= false (a false request is always accepted).
-- Diagnostics (character attributes): CreepLastResult ("on" / "off" / "disabled" / "dead" / "badArg").
-- Gameplay effects (stealth / detection radius) are NOT applied yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	char:SetAttribute("Creeping", wanted)
	char:SetAttribute("CreepLastResult", wanted and "on" or "off")
end)
