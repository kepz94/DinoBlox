-- StunClient v1.2 (Dino Arcade) — the player's own dino while stunned (LocalScript).
-- Stunned = the character attribute StunnedUntil (server time, set by ShakeOffServer 1.0 when a T-Rex rams a tree with
-- this raptor latched on) is in the future. While stunned: Humanoid.PlatformStand = true and the HumanoidRootPart is
-- anchored lying on its side on the ground below (ground ray, dinos and grass ignored; rolled 90 degrees about its
-- forward axis over ROLL_TIME s), set every frame after TurnLimit / PounceTest (RenderStep Input + 3) and before
-- physics, so the dino cannot move, turn or leap. PounceTest 1.3 / PounceServer 1.2 refuse pounces meanwhile. When the
-- stun ends it rolls back up over GETUP_TIME s, is un-anchored and stands (PlatformStand off).
-- v1.1: toss (user: "they shouldnt just fall straight to the floor make them get tossed off a reasonable distance with
--   the stun animation"). When the stun comes with a toss (ShakeOffServer 1.1 sets StunTossAt = the ram time,
--   StunTossFrom = the tree's point, StunTossDistance = studs; taken when StunTossAt is within TOSS_FRESH s of the
--   stun's start), the body is flung instead of rolling where it is: TOSS_TIME s along an arc (TOSS_HEIGHT studs high
--   at the middle) from where it was to StunTossDistance studs farther from StunTossFrom (flat; away from the tree; the
--   point is kept inside ISLAND_LIMIT), facing back toward the tree, turning one full backward flip and rolling onto its
--   side as it lands on the ground found there (same ground ray). Then it lies there as in v1.0 (IdleAnimation 1.19
--   kicks the legs, StunFX 1.0 shows the stars) and gets up when the stun ends. Without a toss, v1.0 behaviour.
--   Diagnostics: StunState adds "tossed" (in the air); StunTossDist (studs flown, 0.1 steps).
-- v1.2 (user: "when i ram into a tree when latched the raptors fly so far. lets keep it nearby relevant to the
--   player"): the landing point was clamped to |X|, |Z| <= ISLAND_LIMIT (230, the v1.0 island); on the current island
--   (IslandHalfSize 940) a raptor tossed farther out was dragged up to hundreds of studs toward the middle. The clamp
--   now uses Workspace.DinoIsland's IslandWanderLimit (ISLAND_LIMIT only when it is missing), so it lands
--   StunTossDistance (15) studs from where it was, away from the tree. Diagnostics: StunClientVersion,
--   StunTossLimit (the limit used).
-- Diagnostics (character attributes, this client): StunState ("none" / "stunned" / "getup"), StunLeft (seconds, 0.1
-- steps).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local BIND = "DinoStun"
local ROLL_TIME = 0.35
local GETUP_TIME = 0.4
local TOSS_TIME = 0.6      -- v1.1
local TOSS_HEIGHT = 6      -- v1.1: studs above the straight line at the middle of the flight
local TOSS_FRESH = 1       -- v1.1: s between the stun start and StunTossAt for the stun to be a toss
local ISLAND_LIMIT = 230   -- v1.1: |X| / |Z| the landing point is kept within (edge walls at 237)
local VERSION = "1.2"      -- v1.2
char:SetAttribute("StunClientVersion", VERSION)

pcall(function() RunService:UnbindFromRenderStep(BIND) end) -- a binding left by a previous character

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local shown = {}
local function show(k, v)
	if shown[k] ~= v then
		shown[k] = v
		char:SetAttribute(k, v)
	end
end

local state = "none"
local t0, standCF, lyingCF
local toss -- v1.1: {fromCF, rot, startPos, endPos}

local function frames()
	local ignore = {char}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	local island = workspace:FindFirstChild("DinoIsland")
	if island then
		for _, n in ipairs({"Bots", "TallGrass", "Bushes"}) do
			local f = island:FindFirstChild(n)
			if f then table.insert(ignore, f) end
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
	local ground = hit and hit.Position.Y or (hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight)
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local pos = Vector3.new(hrp.Position.X, ground, hrp.Position.Z)
	local rot = CFrame.lookAt(Vector3.zero, look.Unit)
	local halfWidth = char:GetExtentsSize().X / 2
	standCF = CFrame.new(pos + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0)) * rot
	lyingCF = CFrame.new(pos + Vector3.new(0, math.min(halfWidth, 1.2), 0)) * rot * CFrame.Angles(0, 0, math.pi / 2)
end

-- v1.1: toss setup; returns true when this stun is a toss
local function tossFrames(now)
	local at, from, dist = char:GetAttribute("StunTossAt"), char:GetAttribute("StunTossFrom"), char:GetAttribute("StunTossDistance")
	if typeof(at) ~= "number" or typeof(from) ~= "Vector3" or typeof(dist) ~= "number" or math.abs(now - at) > TOSS_FRESH then
		return false
	end
	local start = hrp.Position
	local away = Vector3.new(start.X - from.X, 0, start.Z - from.Z)
	if away.Magnitude < 0.5 then
		away = -Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if away.Magnitude < 1e-3 then away = Vector3.new(0, 0, 1) end
	end
	away = away.Unit
	local land = Vector3.new(start.X, 0, start.Z) + away * dist
	local isl = workspace:FindFirstChild("DinoIsland") -- v1.2: the current island's limit, not 230
	local limit = (isl and isl:GetAttribute("IslandWanderLimit")) or ISLAND_LIMIT
	show("StunTossLimit", limit)
	land = Vector3.new(math.clamp(land.X, -limit, limit), 0, math.clamp(land.Z, -limit, limit))
	local hit = workspace:Raycast(Vector3.new(land.X, start.Y + 40, land.Z), Vector3.new(0, -140, 0), params)
	local ground = hit and hit.Position.Y or (start.Y - hrp.Size.Y / 2 - hum.HipHeight)
	local rot = CFrame.lookAt(Vector3.zero, -away) -- faces back toward the tree, flies backward
	local halfWidth = char:GetExtentsSize().X / 2
	local lyingPos = Vector3.new(land.X, ground + math.min(halfWidth, 1.2), land.Z)
	toss = {rot = rot, startPos = start, endPos = lyingPos}
	standCF = CFrame.new(Vector3.new(land.X, ground + hrp.Size.Y / 2 + hum.HipHeight, land.Z)) * rot
	lyingCF = CFrame.new(lyingPos) * rot * CFrame.Angles(0, 0, math.pi / 2)
	show("StunTossDist", math.floor((Vector3.new(lyingPos.X, 0, lyingPos.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude * 10 + 0.5) / 10)
	return true
end

local function step()
	if hum.Health <= 0 then return end
	local now = workspace:GetServerTimeNow()
	local untilT = char:GetAttribute("StunnedUntil")
	local stunned = typeof(untilT) == "number" and untilT > now
	if stunned then
		if state ~= "stunned" and state ~= "tossed" then
			t0 = os.clock()
			frames()
			toss = nil -- v1.1
			state = tossFrames(now) and "tossed" or "stunned"
			hum.PlatformStand = true
			hrp.Anchored = true
		end
		hum.PlatformStand = true -- every frame: a latch release in the same moment may switch it off
		hrp.Anchored = true
		if state == "tossed" then -- v1.1: flying backward, one flip, rolling onto its side to land
			local u = math.min(1, (os.clock() - t0) / TOSS_TIME)
			local pos = toss.startPos:Lerp(toss.endPos, u) + Vector3.new(0, 4 * TOSS_HEIGHT * u * (1 - u), 0)
			local e = u * u * (3 - 2 * u)
			hrp.CFrame = CFrame.new(pos) * toss.rot * CFrame.Angles(0, 0, math.pi / 2 * e) * CFrame.Angles(2 * math.pi * e, 0, 0)
			if u >= 1 then
				state = "stunned"
				t0 = os.clock() - ROLL_TIME -- already lying
			end
		else
			local u = math.min(1, (os.clock() - t0) / ROLL_TIME)
			hrp.CFrame = standCF:Lerp(lyingCF, u * u * (3 - 2 * u))
		end
		show("StunLeft", math.floor((untilT - now) * 10 + 0.5) / 10)
	elseif state == "stunned" or state == "tossed" then -- v1.1: + tossed
		state = "getup"
		t0 = os.clock()
	elseif state == "getup" then
		local u = math.min(1, (os.clock() - t0) / GETUP_TIME)
		hrp.CFrame = lyingCF:Lerp(standCF, u * u * (3 - 2 * u))
		if u >= 1 then
			state = "none"
			hrp.Anchored = false
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			show("StunLeft", 0)
		end
	end
	show("StunState", state)
end

RunService:BindToRenderStep(BIND, Enum.RenderPriority.Input.Value + 3, step)
local conn = RunService.PreSimulation:Connect(step)

local function cleanup()
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	conn:Disconnect()
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
