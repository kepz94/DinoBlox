-- CameraZoom v1.1 (Dino Arcade) — starts the camera zoomed out to a 3rd-person view of the dino on
-- every spawn. Distance = character attribute CameraStartZoom (default 35 studs). The scroll wheel /
-- pinch still zooms in and out afterwards: the minimum zoom is raised to CameraStartZoom only until the
-- camera has moved out to it, then put back to what it was.
-- Diagnostic: character attribute CameraZoomState ("zooming" / "set" / "timeout").
-- v1.1: re-fit on growth (DINO-6): when CameraStartZoom changes (GrowthServer 1.0 scales it with the body), the same
--   zoom-out runs again to the new distance. Diagnostics CameraZoomApplied (the distance last applied),
--   CameraZoomVersion.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local char = script.Parent
local player = Players.LocalPlayer

local DEFAULT_ZOOM = 35
local TIMEOUT = 2 -- seconds to wait for the camera to reach the distance

char:SetAttribute("CameraZoomVersion", "1.1")
local busy = false
local function applyZoom() -- v1.1: the v1.0 zoom-out, callable again
	if busy then return end
	busy = true
	local dist = char:GetAttribute("CameraStartZoom") or DEFAULT_ZOOM
	local prevMin = player.CameraMinZoomDistance
	char:SetAttribute("CameraZoomState", "zooming")
	player.CameraMinZoomDistance = math.min(dist, player.CameraMaxZoomDistance)

	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local reached = false
	while os.clock() - t0 < TIMEOUT do
		RunService.RenderStepped:Wait()
		if (cam.CFrame.Position - cam.Focus.Position).Magnitude >= dist - 0.5 then
			reached = true
			break
		end
	end
	player.CameraMinZoomDistance = prevMin
	char:SetAttribute("CameraZoomState", reached and "set" or "timeout")
	char:SetAttribute("CameraZoomApplied", dist)
	busy = false
end
char:GetAttributeChangedSignal("CameraStartZoom"):Connect(function() task.spawn(applyZoom) end)
applyZoom()
