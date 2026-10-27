-- DinoHealthServer v1.0 (Dino Arcade) — TEST. Health, death and respawn for player dinos.
-- Every player character (also the raptor body SpeciesServer swaps in): Humanoid.MaxHealth = the character attribute
--   DinoMaxHealth, else by Species (TRex 200, Raptor 60), else 100; Health = MaxHealth; BreakJointsOnDeath = false
--   (the dino falls over in one piece). No health regeneration: Roblox's default "Health" regen script is removed
--   from the character, so the T-Rex (LoadCharacter) and the raptor (cloned body) behave the same.
-- Death: character attributes DiedAt (server time) and RespawnTime; player attribute DinoDeaths (+1). Roblox respawns
--   the player Players.RespawnTime = RESPAWN_TIME s later at the SpawnLocation as the StarterCharacter T-Rex, and
--   SpeciesServer 1.0 swaps a player who picked Raptor back to a raptor.
-- Damage comes from BotServer 1.0 (bot bites: Humanoid:TakeDamage).
-- Diagnostics: character attributes DinoHealthVersion, DinoMaxHealthSet; player attribute DinoDeaths.
local Players = game:GetService("Players")

local VERSION = "1.0"
local RESPAWN_TIME = 3
local MAX_BY_SPECIES = {TRex = 200, Raptor = 60}
local DEFAULT_MAX = 100

Players.RespawnTime = RESPAWN_TIME

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local species = char:GetAttribute("Species")
	local max = char:GetAttribute("DinoMaxHealth") or MAX_BY_SPECIES[species] or DEFAULT_MAX
	hum.MaxHealth = max
	hum.Health = max
	hum.BreakJointsOnDeath = false
	char:SetAttribute("DinoHealthVersion", VERSION)
	char:SetAttribute("DinoMaxHealthSet", max)
	-- no regen: remove Roblox's default Health script (it may be inserted just after spawning)
	local function dropRegen(c)
		if c.Name == "Health" and c:IsA("Script") then task.defer(function() c:Destroy() end) end
	end
	for _, c in ipairs(char:GetChildren()) do dropRegen(c) end
	char.ChildAdded:Connect(dropRegen)
	hum.Died:Connect(function()
		char:SetAttribute("DiedAt", workspace:GetServerTimeNow())
		char:SetAttribute("RespawnTime", Players.RespawnTime)
		player:SetAttribute("DinoDeaths", (player:GetAttribute("DinoDeaths") or 0) + 1)
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
