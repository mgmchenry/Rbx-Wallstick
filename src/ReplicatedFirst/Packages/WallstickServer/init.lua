--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local WallstickServer = {}

local function replace(child, parent)
	local found = parent:FindFirstChild(child.Name)
	if found then found:Destroy() end
	child.Parent = parent
end

local isDeployed = false
function WallstickServer.Deploy()
	if isDeployed then return end
	
	local WallstickServerScript = script
	local ServerPackages = script.Parent
	local WallstickPlayerScripts = -- Client = --script:WaitForChild("Client")
		WallstickServerScript:WaitForChild("WallstickPlayerScripts")
	
	local UpVectorCameraLoader = ServerPackages:WaitForChild("BaseCameraExtender")
	:WaitForChild("PlayerScriptsLoader")
	UpVectorCameraLoader.Parent = WallstickPlayerScripts
	
	local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	local StarterCharacterScripts = game:GetService("StarterPlayer"):WaitForChild("StarterCharacterScripts")
	
	replace(WallstickPlayerScripts:WaitForChild("PlayerScriptsLoader"), StarterPlayerScripts)
	replace(WallstickPlayerScripts:WaitForChild("RbxCharacterSounds"), StarterPlayerScripts)
	replace(WallstickPlayerScripts:WaitForChild("WallstickLoader"), StarterPlayerScripts)
	replace(WallstickPlayerScripts:WaitForChild("Animate"), StarterCharacterScripts)

	--script:WaitForChild("Wallstick").Parent = ReplicatedStorage
	
	isDeployed = true
end

local Remotes
function WallstickServer.Start()
	require(script:WaitForChild("Collisions"))
	Remotes = require(script:WaitForChild("Remotes"))
	
	WallstickServer.Deploy()
end

function WallstickServer.StartCharacterCFrameReplication()
	if Remotes then
		Remotes.StartCharacterCFrameReplication()
	end
end

function WallstickServer.StopCharacterCFrameReplication()
	if Remotes then
		Remotes.StopCharacterCFrameReplication()
	end
end


return WallstickServer
