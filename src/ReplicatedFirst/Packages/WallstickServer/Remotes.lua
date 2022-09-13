--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local wallstickClientPath = game:GetService("ReplicatedFirst")
:FindFirstChild("Packages")
:FindFirstChild("WallstickClient")

local WallstickConfig = require(wallstickClientPath:FindFirstChild("WallstickConfig"))

--local Wallstick = script.Parent.Parent.Parent:WaitForChild("WallstickClient")
--local RemotesFolder = Wallstick:WaitForChild("Remotes")
local RemotesFolder = Instance.new("Folder")
RemotesFolder.Name = "WallstickRemotes"
RemotesFolder.Parent = WallstickConfig.Get.RemoteParent()
--RemotesFolder.Parent = workspace

local CONSTANTS = require(wallstickClientPath:WaitForChild("Constants"))

local setCollidable = Instance.new("RemoteEvent")
setCollidable.Name = "SetCollidable"
setCollidable.Parent = RemotesFolder

setCollidable.OnServerEvent:Connect(function(player, bool)
	if not player.Character then
		return
	end

	for _, part in pairs((player.Character :: any):GetChildren()) do
		if part:IsA("BasePart") then
			part.CollisionGroupId = not bool and CONSTANTS.PHYSICS_ID or 0
		end
	end
end)

local replicationStorage = {}

local replicatePhysics = Instance.new("RemoteEvent")
replicatePhysics.Name = "ReplicatePhysics"
replicatePhysics.Parent = RemotesFolder

replicatePhysics.OnServerEvent:Connect(function(player, part, cf, instant, shouldRemove)
	if not shouldRemove then
		local storage = replicationStorage[player]

		if not storage then
			storage = {
				Part = part,
				CFrame = cf,
				PrevPart = part,
				PrevCFrame = cf,
				Instant = instant,
			}

			replicationStorage[player] = storage
		end

		storage.Part = part
		storage.CFrame = cf
		storage.Instant = instant
	else
		replicationStorage[player] = nil
	end

	replicatePhysics:FireAllClients(player, part, cf, instant, shouldRemove)
end)

Players.PlayerRemoving:Connect(function(player)
	replicationStorage[player] = nil
end)

local function onStep(dt)
	for player, storage in pairs(replicationStorage) do
		local cf = storage.CFrame

		if not storage.Instant then
			if storage.Part == storage.PrevPart then
				cf = storage.PrevCFrame:Lerp(cf, 0.1*dt*60)
			else
				local prevCFrame = storage.Part.CFrame:ToObjectSpace(storage.PrevPart.CFrame * storage.PrevCFrame)
				cf = prevCFrame:Lerp(cf, 0.1*dt*60)
			end
		end

		storage.PrevPart = storage.Part
		storage.PrevCFrame = cf
		
		local character = player.Character
		local HRP:BasePart = (character and character:FindFirstChild("HumanoidRootPart") or nil) :: any
		if HRP then
			HRP.CFrame = storage.Part.CFrame * cf
		end 
	end
end

local Remotes = {}
local heartbeat:RBXScriptConnection
function Remotes.StartCharacterCFrameReplication()
	if heartbeat==nil then
		-- This only need to run if you need an accurate character cframe on the server
		heartbeat = RunService.Heartbeat:Connect(onStep) 
	end
end

function Remotes.StopCharacterCFrameReplication()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil :: any
	end
end

return Remotes