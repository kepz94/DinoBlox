-- SurvivalBars v1.2 (Dino Arcade) — the player's own Hunger and Thirst bars + hold-E eat / drink (LocalScript).
-- Layout: one holder the same size as HealthBar 1.1 / StaminaBar 1.1 (42% wide, min 260 / max 560 px, 44 px tall),
--   50 px above the health bar (bottom -126; HealthBar -76, StaminaBar -26 unchanged). Inside: HUNGER on the left
--   half, THIRST on the right half (10 px gap), each "label + current / max" over a rounded 22 px bar in the HealthBar
--   style. Hunger fill orange, Thirst fill blue; below SurvivalWarnFraction (default 0.2) the fill turns red and the
--   outline pulses red (2 Hz); at 0 the value reads STARVING / DEHYDRATED in red. A hint line above the bars shows
--   "[E] Hold to eat" / "[E] Hold to drink" while food / fresh water is in reach, "Eating..." / "Drinking..." while
--   the server runs the action. The whole HUD is hidden while SurvivalEnabled = false.
-- Input: E is bound (ContextActionService, priority High + 1 = above RamTest's E) ONLY while SurvivalCanEat or
--   SurvivalCanDrink is true (server attributes, SurvivalServer 1.0) or the key is held; otherwise unbound, so E is
--   Ram everywhere else. Key down: "eat" if SurvivalCanEat, else "drink" -> DinoSurvivalAction; key up / cancel ->
--   "stop". Touch: the binding's on-screen button (Eat / Drink). Server validates everything.
-- Values read (character attributes, SurvivalServer 1.0): Hunger, Thirst, HungerMax, ThirstMax, SurvivalWarnFraction,
--   SurvivalEnabled, SurvivalCanEat, SurvivalCanDrink, SurvivalAction.
-- Diagnostics (character attributes, this client): SurvivalBarsVersion, SurvivalBarsState ("normal" / "warning" /
--   "empty" / "disabled"), SurvivalHint (hint text shown), SurvivalInputBound, SurvivalHolding ("eat" / "drink" / "").
-- v1.1 (SurvivalServer 1.1 phases; answers: move + turn locked, bite / roar / pounce cancel the meal):
--   * Lock: from the key press (predicted) and while the server's SurvivalLocked is true, the body is held: every
--     PreSimulation and at RenderStep Input + 5 (after TurnLimit at Input + 1 and RamTest at Input + 4)
--     Humanoid:Move(zero) and the HumanoidRootPart keeps the heading it had when the lock began (position kept).
--     The predicted lock ends if the server has not confirmed it within LOCK_CONFIRM s. The lock is let go at once on
--     this client when one of BitePredictedAt / PouncePredictedAt / JumpPredictedAt / RamPredictedAt (this client) or
--     BiteStartedAt / RoarStartedAt / PounceStartedAt / JumpStartedAt / RamStartedAt is newer than the lock start
--     (the server ends it with "interrupted" too). Diagnostic SurvivalLockState ("none" / "predicted" / "locked" /
--     "released").
--   * Hint line by phase: lowering "Lowering head..." (drink) / "Going in..." (eat), eating "Eating...", drinking
--     "Drinking...", rising "Getting up...".
--   * Eat prompt: a BillboardGui (PlayerGui.SurvivalEatPrompt) over the carcass named by SurvivalNearCarcass while
--     SurvivalCanEat: "[E] EAT" and the food left (CarcassFood / CarcassFoodMax); hidden otherwise.
--     Diagnostic SurvivalEatPrompt (carcass name or "").
-- v1.2 (bug: "the eating animation hasnt shown up once"): the eat / drink animation played, but the shoulder camera
--   (ShoulderCam 1.0) sits behind and above the dino, so the lowered head and the carcass were hidden behind its own
--   body. Answer: swing to a side view. While the lock is on (predicted or SurvivalLocked: lowering, eating /
--   drinking, rising) a weight eases to 1 at CAM_IN per second (back to 0 at CAM_OUT) and the camera, after
--   ShoulderCam has placed it (RenderStep Camera + 1, Scriptable camera only), is blended toward a 3/4 side view:
--   looking at the point CAM_FOCUS of the way from the HumanoidRootPart to the head, from the side the camera was on
--   when the swing began, CAM_DIST x the dino's longest side out (at least CAM_MIN_DIST), CAM_AHEAD of that forward,
--   CAM_UP x its height up; pulled in before world geometry (characters, bots, carcasses, tall grass ignored).
--   Mouse aim keeps working underneath, so the view returns to wherever the player aimed. Off with the character
--   attribute SurvivalSideCam = false. Diagnostic SurvivalCamBlend (0..1, 0.1 steps).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.0"
local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("DinoSurvivalAction", 10)

local ACTION = "DinoSurvivalEatDrink"
local KEYS = {Enum.KeyCode.E}
local PRIORITY = Enum.ContextActionPriority.High.Value + 1
local DEFAULTS = {HungerMax = 100, ThirstMax = 100, SurvivalWarnFraction = 0.2, SurvivalEnabled = true}
local PULSE_HZ = 2
local LOCK_CONFIRM = 0.6 -- v1.1: s a predicted lock waits for the server's SurvivalLocked
local LOCK_BIND = "DinoSurvivalLock" -- v1.1
local CAM_BIND = "DinoSurvivalCam" -- v1.2
local CAM_IN, CAM_OUT = 2.5, 3 -- v1.2: per second
local CAM_FOCUS, CAM_DIST, CAM_MIN_DIST, CAM_AHEAD, CAM_UP = 0.65, 0.9, 12, 0.3, 0.3 -- v1.2
local INTERRUPT_ATTRS = {"BitePredictedAt", "PouncePredictedAt", "JumpPredictedAt", "RamPredictedAt", -- v1.1
	"BiteStartedAt", "RoarStartedAt", "PounceStartedAt", "JumpStartedAt", "RamStartedAt"}

local COLORS = {
	back = Color3.fromRGB(20, 20, 26),
	hungerA = Color3.fromRGB(255, 176, 66), hungerB = Color3.fromRGB(222, 128, 38),
	thirstA = Color3.fromRGB(92, 190, 255), thirstB = Color3.fromRGB(46, 138, 222),
	low = Color3.fromRGB(235, 55, 45), lowB = Color3.fromRGB(190, 35, 30),
}

char:SetAttribute("SurvivalBarsVersion", VERSION)

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local old = player:WaitForChild("PlayerGui"):FindFirstChild("SurvivalHUD")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "SurvivalHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -126) -- 50 px above the health bar (HealthBar: -76)
holder.Size = UDim2.new(0.42, 0, 0, 44)
holder.BackgroundTransparency = 1
holder.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(260, 44)
limit.MaxSize = Vector2.new(560, 44)
limit.Parent = holder

local function label(parent, name, text, pos, size, align, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = 16
	l.TextXAlignment = align
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Parent = parent
	return l
end

local function makeBar(name, title, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Position = pos
	f.Size = UDim2.new(0.5, -5, 1, 0)
	f.Parent = holder
	label(f, "Title", title, UDim2.fromOffset(6, 0), UDim2.new(0.5, 0, 0, 18), Enum.TextXAlignment.Left)
	local value = label(f, "Value", "", UDim2.new(0.4, -6, 0, 0), UDim2.new(0.6, 0, 0, 18), Enum.TextXAlignment.Right)
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 22)
	back.BackgroundColor3 = COLORS.back
	back.BackgroundTransparency = 0.2
	back.ClipsDescendants = true
	back.Parent = f
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 11)
	backCorner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.55
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 11)
	fillCorner.Parent = fill
	local gradient = Instance.new("UIGradient")
	gradient.Parent = fill
	return {value = value, stroke = stroke, fill = fill, gradient = gradient}
end

local hungerBar = makeBar("Hunger", "HUNGER", UDim2.fromScale(0, 0))
local thirstBar = makeBar("Thirst", "THIRST", UDim2.new(0.5, 5, 0, 0))
local hint = label(holder, "Hint", "", UDim2.new(0, 0, 0, -22), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center)

gui.Parent = player.PlayerGui

local shown = {}
local function show(attr, v)
	if shown[attr] ~= v then
		shown[attr] = v
		char:SetAttribute(attr, v)
	end
end

-- returns "normal" / "warning" / "empty"
local function drawBar(bar, v, max, warn, colA, colB, emptyText, pulse)
	max = math.max(1, max)
	v = math.clamp(v, 0, max)
	local frac = v / max
	bar.fill.Size = UDim2.fromScale(frac, 1)
	local state = v <= 0 and "empty" or (frac < warn and "warning" or "normal")
	if state == "empty" then
		bar.value.Text = emptyText
		bar.value.TextColor3 = COLORS.low
	else
		bar.value.Text = ("%d / %d"):format(math.ceil(v), math.floor(max + 0.5))
		bar.value.TextColor3 = Color3.new(1, 1, 1)
	end
	if state == "normal" then
		bar.gradient.Color = ColorSequence.new(colA, colB)
		bar.stroke.Color = Color3.new(1, 1, 1)
		bar.stroke.Transparency = 0.55
	else
		bar.gradient.Color = ColorSequence.new(COLORS.low, COLORS.lowB)
		bar.stroke.Color = COLORS.low
		bar.stroke.Transparency = pulse
	end
	return state
end

-- input ---------------------------------------------------------------
local holding = ""
local bound = false

-- v1.1: movement / turn lock ---------------------------------------------
local hrp = char:WaitForChild("HumanoidRootPart")
local lock = {state = "none", at = 0, predictedClock = 0, rot = nil}
local function lockPredict()
	if lock.state == "none" or lock.state == "released" then
		lock.state, lock.at, lock.predictedClock = "predicted", workspace:GetServerTimeNow(), os.clock()
		lock.rot = hrp.CFrame.Rotation
	end
end
local function interruptedSince(t)
	for _, k in ipairs(INTERRUPT_ATTRS) do
		local v = char:GetAttribute(k)
		if typeof(v) == "number" and v > t + 1e-3 then return true end
	end
	return false
end
local function updateLock()
	local serverLocked = char:GetAttribute("SurvivalLocked") == true
	if lock.state == "predicted" then
		if serverLocked then
			lock.state = "locked"
		elseif os.clock() - lock.predictedClock > LOCK_CONFIRM then
			lock.state = "none"
		end
	elseif lock.state == "none" and serverLocked then
		lock.state, lock.at, lock.rot = "locked", char:GetAttribute("SurvivalLockAt") or workspace:GetServerTimeNow(), hrp.CFrame.Rotation
	elseif lock.state == "locked" and not serverLocked then
		lock.state = "none"
	elseif lock.state == "released" and not serverLocked then
		lock.state = "none"
	end
	if (lock.state == "predicted" or lock.state == "locked") and (hum.Health <= 0 or interruptedSince(lock.at)) then
		lock.state = "released"
	end
	char:SetAttribute("SurvivalLockState", lock.state)
end
local function holdStill()
	if lock.state ~= "predicted" and lock.state ~= "locked" then return end
	hum:Move(Vector3.zero, false)
	if lock.rot then hrp.CFrame = CFrame.new(hrp.Position) * lock.rot end
end
local lockStep = RunService.PreSimulation:Connect(function()
	updateLock()
	holdStill()
end)
pcall(function() RunService:UnbindFromRenderStep(LOCK_BIND) end)
RunService:BindToRenderStep(LOCK_BIND, Enum.RenderPriority.Input.Value + 5, holdStill)

-- v1.2: side camera while locked ------------------------------------------
local camW, camSide, modelSize = 0, nil, nil
local headParts
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Exclude
local function headCenter()
	if not headParts then
		local seg = char:FindFirstChild("Head")
		if not seg then return nil end
		headParts = {}
		for _, p in ipairs(seg:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then table.insert(headParts, p) end
		end
	end
	if #headParts == 0 then return nil end
	local sum = Vector3.zero
	for _, p in ipairs(headParts) do sum += p.Position end
	return sum / #headParts
end
local function camStep(dt)
	local want = (lock.state == "predicted" or lock.state == "locked") and char:GetAttribute("SurvivalSideCam") ~= false
	camW = want and math.min(1, camW + dt * CAM_IN) or math.max(0, camW - dt * CAM_OUT)
	show("SurvivalCamBlend", math.floor(camW * 10 + 0.5) / 10)
	if camW <= 0 then
		camSide = nil
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then return end
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then return end
	local fwd = look.Unit
	local right = fwd:Cross(Vector3.yAxis)
	if not camSide then camSide = (cam.CFrame.Position - hrp.Position):Dot(right) >= 0 and 1 or -1 end
	modelSize = modelSize or char:GetExtentsSize()
	local long = math.max(modelSize.X, modelSize.Z)
	local head = headCenter() or (hrp.Position + fwd * long * 0.3)
	local focus = hrp.Position:Lerp(head, CAM_FOCUS)
	local dist = math.max(CAM_MIN_DIST, long * CAM_DIST)
	local desired = focus + right * camSide * dist + fwd * dist * CAM_AHEAD + Vector3.new(0, modelSize.Y * CAM_UP, 0)
	local ignore = {char}
	for _, n in ipairs({"DinoCarcasses", "CarcassFliesLocal"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ignore, f) end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = island and island:FindFirstChild(n)
		if f then table.insert(ignore, f) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	camParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(focus, desired - focus, camParams)
	if hit then desired = hit.Position + (focus - hit.Position).Unit * 1 end
	local e = camW * camW * (3 - 2 * camW)
	cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(desired, focus), e)
end
pcall(function() RunService:UnbindFromRenderStep(CAM_BIND) end)
RunService:BindToRenderStep(CAM_BIND, Enum.RenderPriority.Camera.Value + 1, camStep)

-- v1.1: eat prompt over the carcass ------------------------------------------
local prompt = Instance.new("BillboardGui")
prompt.Name = "SurvivalEatPrompt"
prompt.AlwaysOnTop = true
prompt.Size = UDim2.fromOffset(150, 46)
prompt.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
prompt.LightInfluence = 0
prompt.Enabled = false
local promptKey = Instance.new("TextLabel")
promptKey.Name = "Key"
promptKey.BackgroundColor3 = COLORS.back
promptKey.BackgroundTransparency = 0.15
promptKey.Size = UDim2.new(1, 0, 0, 26)
promptKey.Font = Enum.Font.FredokaOne
promptKey.TextSize = 18
promptKey.TextColor3 = Color3.new(1, 1, 1)
promptKey.Text = "[E] EAT"
promptKey.Parent = prompt
local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 10)
promptCorner.Parent = promptKey
local promptStroke = Instance.new("UIStroke")
promptStroke.Color = COLORS.hungerA
promptStroke.Thickness = 2
promptStroke.Parent = promptKey
local promptFood = Instance.new("TextLabel")
promptFood.Name = "Food"
promptFood.BackgroundTransparency = 1
promptFood.Position = UDim2.fromOffset(0, 26)
promptFood.Size = UDim2.new(1, 0, 0, 20)
promptFood.Font = Enum.Font.FredokaOne
promptFood.TextSize = 14
promptFood.TextColor3 = COLORS.hungerA
promptFood.TextStrokeTransparency = 0.4
promptFood.Parent = prompt
prompt.Parent = player.PlayerGui
local function updatePrompt(alive)
	local name = char:GetAttribute("SurvivalNearCarcass")
	local folder = workspace:FindFirstChild("DinoCarcasses")
	local c = alive and char:GetAttribute("SurvivalCanEat") == true and folder and type(name) == "string" and name ~= ""
		and folder:FindFirstChild(name)
	local part = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChildWhichIsA("BasePart", true))
	if part then
		prompt.Adornee = part
		prompt.Enabled = true
		local food, max = c:GetAttribute("CarcassFood") or 0, c:GetAttribute("CarcassFoodMax") or 0
		promptFood.Text = ("food %d / %d"):format(math.ceil(food), math.floor(max + 0.5))
		promptKey.Text = char:GetAttribute("SurvivalAction") == "eating" and "EATING" or "[E] EAT"
		show("SurvivalEatPrompt", c.Name)
	else
		prompt.Enabled = false
		prompt.Adornee = nil
		show("SurvivalEatPrompt", "")
	end
end

local function onAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		local what = char:GetAttribute("SurvivalCanEat") == true and "eat"
			or (char:GetAttribute("SurvivalCanDrink") == true and "drink" or nil)
		if not what then return Enum.ContextActionResult.Pass end
		holding = what
		if remote then remote:FireServer(what) end
		lockPredict() -- v1.1
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if holding == "" then return Enum.ContextActionResult.Pass end
		holding = ""
		if remote then remote:FireServer("stop") end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function applyBinding(want, title)
	if want and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, PRIORITY, table.unpack(KEYS))
		bound = true
	elseif not want and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	if bound and title then ContextActionService:SetTitle(ACTION, title) end
end

local conn
conn = RunService.RenderStepped:Connect(function()
	if not char.Parent then
		conn:Disconnect()
		applyBinding(false)
		gui:Destroy()
		lockStep:Disconnect() -- v1.1
		pcall(function() RunService:UnbindFromRenderStep(LOCK_BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(CAM_BIND) end) -- v1.2
		prompt:Destroy()
		return
	end
	local enabled = get("SurvivalEnabled") == true
	holder.Visible = enabled
	local canEat = char:GetAttribute("SurvivalCanEat") == true
	local canDrink = char:GetAttribute("SurvivalCanDrink") == true
	local alive = hum.Health > 0
	if holding ~= "" and (not alive or not enabled) then
		holding = ""
		if remote then remote:FireServer("stop") end
	end
	applyBinding(enabled and alive and (canEat or canDrink or holding ~= ""), canEat and "Eat" or "Drink")
	show("SurvivalInputBound", bound)
	show("SurvivalHolding", holding)
	if not enabled then
		show("SurvivalBarsState", "disabled")
		show("SurvivalHint", "")
		return
	end
	local warn = get("SurvivalWarnFraction")
	local pulse = 0.5 - 0.5 * math.cos(os.clock() * PULSE_HZ * 2 * math.pi)
	local hs = drawBar(hungerBar, char:GetAttribute("Hunger") or get("HungerMax"), get("HungerMax"), warn,
		COLORS.hungerA, COLORS.hungerB, "STARVING", pulse)
	local ts = drawBar(thirstBar, char:GetAttribute("Thirst") or get("ThirstMax"), get("ThirstMax"), warn,
		COLORS.thirstA, COLORS.thirstB, "DEHYDRATED", pulse)
	show("SurvivalBarsState", (hs == "empty" or ts == "empty") and "empty"
		or ((hs == "warning" or ts == "warning") and "warning" or "normal"))
	local action = char:GetAttribute("SurvivalAction")
	local phase = char:GetAttribute("SurvivalPhase") -- v1.1
	local kind = char:GetAttribute("SurvivalKind")
	updatePrompt(alive) -- v1.1
	local text = ""
	if alive and phase == "lowering" then -- v1.1: phase hints
		text = kind == "eat" and "Going in..." or "Lowering head..."
	elseif alive and phase == "rising" then
		text = "Getting up..."
	elseif alive then
		if action == "eating" then
			text = "Eating..."
		elseif action == "drinking" then
			text = "Drinking..."
		elseif canEat then
			text = "[E] Hold to eat"
		elseif canDrink then
			text = "[E] Hold to drink"
		end
	end
	hint.Text = text
	show("SurvivalHint", text)
end)
