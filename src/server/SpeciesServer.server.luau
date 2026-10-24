-- SpeciesServer v1.0 (Dino Arcade) — TEST species switch: respawns a player as the dino they pick.
-- Client -> server: ReplicatedStorage.DinoSpeciesRequest:FireServer(species) (sent by SpeciesPicker 1.0),
--   species = "TRex" or "Raptor".
-- TRex   -> player:LoadCharacter() (StarterPlayer.StarterCharacter, the T-Rex).
-- Raptor -> a copy of the raptor template: built once at start from ServerStorage.DinoArcade.Models.RaptorModelData
--   with DinoModelBuilder 1.0 (Rojo: src/shared -> ServerStorage.DinoArcade). The copy gets clones of every
--   StarterCharacterScripts child (so IdleAnimation, SprintTest, TurnLimit, StaminaBar ... run on it), is
--   placed standing at the SpawnLocation (or where the old character stood), then set as player.Character, so
--   every CharacterAdded hook (DinoHitboxes, StaminaServer, CreepServer ...) treats it like any character.
-- The choice is kept in the player attribute DinoSpecies: when Roblox respawns the player after a death
--   (always as the StarterCharacter T-Rex), a player who picked Raptor is switched back to a raptor.
-- Checks: species is a known name; at most one switch per SWITCH_COOLDOWN seconds; template built.
-- Diagnostics: player attributes DinoSpecies, SpeciesLastResult ("ok" / "same" / "badArg" / "cooldown" /
--   "noTemplate"); SpeciesTemplate (server attribute on this script: "ready" / "missing <reason>").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SWITCH_COOLDOWN = 2
local SPECIES = {TRex = true, Raptor = true}

local remote = ReplicatedStorage:FindFirstChild("DinoSpeciesRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoSpeciesRequest"
	remote.Parent = ReplicatedStorage
end

-- raptor template, built once from the model data
local raptorTemplate
do
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("RaptorModelData"))
		raptorTemplate = Builder.build(data, {name = "Raptor"})
	end)
	script:SetAttribute("SpeciesTemplate", ok and raptorTemplate and "ready" or ("missing " .. tostring(err)))
end

local lastSwitch = {}

local function speciesOf(char)
	return char and char:GetAttribute("Species") or nil
end

-- where the new body stands: the old character's spot, else the SpawnLocation
local function spawnCFrame(player, hipHeight)
	local old = player.Character
	local hrp = old and old:FindFirstChild("HumanoidRootPart")
	local hum = old and old:FindFirstChildOfClass("Humanoid")
	local base
	if hrp and hum and hum.Health > 0 then
		local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		local ground = hrp.Position.Y - (hrp.Size.Y / 2 + hum.HipHeight)
		local pos = Vector3.new(hrp.Position.X, ground, hrp.Position.Z)
		base = CFrame.lookAt(pos, pos + (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)))
	else
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local pos = spawn and (spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)) or Vector3.zero
		base = CFrame.new(pos)
	end
	return base + Vector3.new(0, hipHeight, 0)
end

local function spawnRaptor(player)
	local char = raptorTemplate:Clone()
	char.Name = player.Name
	for _, s in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
		s:Clone().Parent = char
	end
	local hrp = char.HumanoidRootPart
	local hum = char:FindFirstChildOfClass("Humanoid")
	char:PivotTo(spawnCFrame(player, hrp.Size.Y / 2 + hum.HipHeight))
	local old = player.Character
	char.Parent = workspace
	player.Character = char
	if old and old ~= char then old:Destroy() end
end

local function switch(player, species)
	player:SetAttribute("DinoSpecies", species)
	if species == "Raptor" then
		spawnRaptor(player)
	else
		player:LoadCharacter()
	end
end

remote.OnServerEvent:Connect(function(player, species)
	if typeof(species) ~= "string" or not SPECIES[species] then
		player:SetAttribute("SpeciesLastResult", "badArg")
		return
	end
	if species == "Raptor" and not raptorTemplate then
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	local now = os.clock()
	if lastSwitch[player] and now - lastSwitch[player] < SWITCH_COOLDOWN then
		player:SetAttribute("SpeciesLastResult", "cooldown")
		return
	end
	if speciesOf(player.Character) == species then
		player:SetAttribute("DinoSpecies", species)
		player:SetAttribute("SpeciesLastResult", "same")
		return
	end
	lastSwitch[player] = now
	switch(player, species)
	player:SetAttribute("SpeciesLastResult", "ok")
end)

-- keep the chosen species after a death (Roblox respawns as the StarterCharacter T-Rex)
local function onPlayer(player)
	player.CharacterAdded:Connect(function(char)
		local want = player:GetAttribute("DinoSpecies")
		if want == "Raptor" and raptorTemplate and speciesOf(char) ~= "Raptor" then
			task.defer(function()
				if player.Character == char then spawnRaptor(player) end
			end)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player) lastSwitch[player] = nil end)
