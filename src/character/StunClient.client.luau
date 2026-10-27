-- StunClient v1.0 (Dino Arcade) — the player's own dino while stunned (LocalScript).
-- Stunned = the character attribute StunnedUntil (server time, set by ShakeOffServer 1.0 when a T-Rex rams a tree with
-- this raptor latched on) is in the future. While stunned: Humanoid.PlatformStand = true and the HumanoidRootPart is
-- anchored lying on its side on the ground below (ground ray, dinos and grass ignored; rolled 90 degrees about its
-- forward axis over ROLL_TIME s), set every frame after TurnLimit / PounceTest (RenderStep Input + 3) and before
-- physics, so the dino cannot move, turn or leap. PounceTest 1.3 / PounceServer 1.2 refuse pounces meanwhile. When the
-- stun ends it rolls back up over GETUP_TIME s, is un-anchored and stands (PlatformStand off).
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

local function step()
	if hum.Health <= 0 then return end
	local now = workspace:GetServerTimeNow()
	local untilT = char:GetAttribute("StunnedUntil")
	local stunned = typeof(untilT) == "number" and untilT > now
	if stunned then
		if state ~= "stunned" then
			state = "stunned"
			t0 = os.clock()
			frames()
			hum.PlatformStand = true
			hrp.Anchored = true
		end
		hum.PlatformStand = true -- every frame: a latch release in the same moment may switch it off
		hrp.Anchored = true
		local u = math.min(1, (os.clock() - t0) / ROLL_TIME)
		hrp.CFrame = standCF:Lerp(lyingCF, u * u * (3 - 2 * u))
		show("StunLeft", math.floor((untilT - now) * 10 + 0.5) / 10)
	elseif state == "stunned" then
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
