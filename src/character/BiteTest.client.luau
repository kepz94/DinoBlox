-- BiteTest v1.1 (Dino Arcade) — TEST input for the quick bite. Left click (mouse), R2 (gamepad) or the
-- on-screen Bite button (touch).
-- On press (when allowed): stamps BitePredictedAt = server time (this client only, so the attacker sees the
-- wind-up at once), sends DinoBiteRequest:FireServer(that time), and pushes the body forward
-- BiteLungeDist studs during the strike (BiteWindup .. BiteWindup + BiteStrike), stopping at walls.
-- Not allowed (no request, no prediction): while Roaring, while dead, BiteEnabled = false, or within
-- BiteCooldown of the last local bite (the server checks the same cooldown).
-- v1.1: hit claim. At the contact moment (BiteWindup + BiteStrike after the press) this client checks the
--   bite against what it actually shows: a capsule of radius BiteRange around the line from BiteReachBack
--   studs behind the animated mouth (Head_mouth front face, back along the snout) to BiteRange / 2 studs
--   ahead of it, so a target the head has pushed into still counts. The closest BiteDummy part found is
--   sent as DinoBiteClaim:FireServer(stamp, targetModel, point); BiteServer validates it. No target = no claim.
-- Diagnostics (character attributes, this client): BiteClaim ("sent" / "none"), BiteInputResult ("sent" / "cooldown" / "roaring" /
--   "disabled" / "dead"), BiteLungeMoved (studs actually moved by the last lunge, 0.01 steps).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local remote = ReplicatedStorage:WaitForChild("DinoBiteRequest")
local claimRemote = ReplicatedStorage:WaitForChild("DinoBiteClaim")

local ACTION = "DinoBiteTest"
local DEFAULTS = {BiteEnabled = true, BiteCooldown = 0.8, BiteWindup = 0.15, BiteStrike = 0.10, BiteLungeDist = 3,
	BiteRange = 5, BiteReachBack = 8}

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

-- closest point of a part's box to p
local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

-- closest distance (and point on the part) between a part's box and the segment a..b, sampled every 0.5 studs
local function segmentHit(part, a, b)
	local best, bestPt = math.huge, nil
	local n = math.max(1, math.ceil((b - a).Magnitude / 0.5))
	for i = 0, n do
		local q = a:Lerp(b, i / n)
		local cp = closestPoint(part, q)
		local d = (cp - q).Magnitude
		if d < best then best, bestPt = d, cp end
	end
	return best, bestPt
end

-- at the contact moment: find the closest dummy part around the animated snout and claim it
local function claimHit(stamp)
	local head = char:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	if not mouth then return end
	local origin = mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0)
	local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if fwd.Magnitude < 1e-3 then return end
	local range = get("BiteRange")
	fwd = fwd.Unit
	local a, b = origin - fwd * get("BiteReachBack"), origin + fwd * (range / 2)
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best, bestModel, bestPoint = math.huge, nil, nil
	for _, part in ipairs(workspace:GetPartBoundsInRadius((a + b) / 2, (b - a).Magnitude / 2 + range, params)) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		while model and model:GetAttribute("BiteDummy") ~= true do
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		if model then
			local d, cp = segmentHit(part, a, b)
			if d <= range and d < best then best, bestModel, bestPoint = d, model, cp end
		end
	end
	if bestModel then
		claimRemote:FireServer(stamp, bestModel, bestPoint)
		char:SetAttribute("BiteClaim", "sent")
	else
		char:SetAttribute("BiteClaim", "none")
	end
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
		task.delay(get("BiteWindup") + get("BiteStrike"), claimHit, stamp)
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
