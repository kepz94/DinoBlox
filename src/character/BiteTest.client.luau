-- BiteTest v1.0 (Dino Arcade) — TEST input for the quick bite. Left click (mouse), R2 (gamepad) or the
-- on-screen Bite button (touch).
-- On press (when allowed): stamps BitePredictedAt = server time (this client only, so the attacker sees the
-- wind-up at once), sends DinoBiteRequest:FireServer(that time), and pushes the body forward
-- BiteLungeDist studs during the strike (BiteWindup .. BiteWindup + BiteStrike), stopping at walls.
-- Not allowed (no request, no prediction): while Roaring, while dead, BiteEnabled = false, or within
-- BiteCooldown of the last local bite (the server checks the same cooldown).
-- Diagnostics (character attributes, this client): BiteInputResult ("sent" / "cooldown" / "roaring" /
--   "disabled" / "dead"), BiteLungeMoved (studs actually moved by the last lunge, 0.01 steps).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local remote = ReplicatedStorage:WaitForChild("DinoBiteRequest")

local ACTION = "DinoBiteTest"
local DEFAULTS = {BiteEnabled = true, BiteCooldown = 0.8, BiteWindup = 0.15, BiteStrike = 0.10, BiteLungeDist = 3}

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local lastBite = -math.huge
local lungeConn

-- moves the body forward `dist` studs over `duration` seconds, starting after `delay` seconds
local function lunge(delay, duration, dist)
	if lungeConn then lungeConn:Disconnect(); lungeConn = nil end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local t0 = os.clock()
	local moved = 0
	lungeConn = RunService.PreSimulation:Connect(function()
		local t = os.clock() - t0 - delay
		if t < 0 then return end
		local target = dist * math.clamp(t / duration, 0, 1)
		local step = target - moved
		if step > 0 then
			local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			if fwd.Magnitude > 1e-3 then
				fwd = fwd.Unit
				-- stop at walls: probe from the body centre to just past the front of the hitbox
				local probe = hrp.Size.Z / 2 + step + 0.5
				if not workspace:Raycast(hrp.Position, fwd * probe, params) then
					hrp.CFrame = hrp.CFrame + fwd * step
					moved += step
				else
					t = duration -- blocked: end the lunge here
				end
			end
		end
		if t >= duration then
			char:SetAttribute("BiteLungeMoved", math.floor(moved * 100 + 0.5) / 100)
			lungeConn:Disconnect()
			lungeConn = nil
		end
	end)
end

local function tryBite()
	local result
	if hum.Health <= 0 then
		result = "dead"
	elseif get("BiteEnabled") == false then
		result = "disabled"
	elseif char:GetAttribute("Roaring") then
		result = "roaring"
	elseif os.clock() - lastBite < get("BiteCooldown") then
		result = "cooldown"
	else
		result = "sent"
		lastBite = os.clock()
		local stamp = workspace:GetServerTimeNow()
		char:SetAttribute("BitePredictedAt", stamp)
		remote:FireServer(stamp)
		lunge(get("BiteWindup"), get("BiteStrike"), get("BiteLungeDist"))
	end
	char:SetAttribute("BiteInputResult", result)
end

local function onBite(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		tryBite()
	end
	return Enum.ContextActionResult.Pass -- let clicks still reach the rest of the game (camera, UI)
end

ContextActionService:BindActionAtPriority(ACTION, onBite, true, Enum.ContextActionPriority.High.Value,
	Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle(ACTION, "Bite")

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
	if lungeConn then lungeConn:Disconnect(); lungeConn = nil end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
