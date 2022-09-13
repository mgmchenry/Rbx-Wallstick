--!strict
-- CONSTANTS

local CONSTANTS = require(script.Parent.Parent:WaitForChild("Constants"))

local UNIT_Y = Vector3.new(0, 1, 0)
type UpVectorCamera = typeof(require(game:GetService("ReplicatedFirst").Packages.BaseCameraExtender.UpVectorCamera))

type WallstickState = typeof(require(script.Parent.Parent.WallstickState))
-- Class

local CameraClass = {
	UpVectorCamera = (nil :: any) :: UpVectorCamera,
	UpVector = (nil :: any) :: Vector3,
	Wallstick = (nil :: any) :: WallstickState
}
CameraClass.__index = CameraClass
CameraClass.ClassName = "Camera"

local function GetPackageBase() : typeof(game:GetService("ReplicatedFirst").Packages)
	return script.Parent.Parent.Parent --.Parent.Packages
end

-- Public Constructors
function CameraClass.new(wallstick: WallstickState)
	local self = setmetatable({}, CameraClass)

	local player = wallstick.Player
	--local playerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
	

	self.Wallstick = wallstick

	self.UpVector = Vector3.new(0, 1, 0)
	--self.CameraModule = playerModule:GetCameras()
	local UpVectorCamera:UpVectorCamera = --require(GetPackageBase()
		require(script.Parent.Parent.Parent
		:WaitForChild("BaseCameraExtender")
		:WaitForChild("UpVectorCamera") ) :: any 
	self.UpVectorCamera = UpVectorCamera

	init(self :: any)

	return self
end

-- Private methods

function init(self: CameraClass)
	self.UpVectorCamera:SetTransitionRate(0.15)
	self:SetSpinPart(workspace.Terrain)
	self.UpVectorCamera.GetUpVector = function(this, upVector:Vector3)
		return self.UpVector
	end
end

-- Public Methods

function CameraClass:SetMode(mode)
	local camera = workspace.CurrentCamera

	if mode == "Default" then
		camera.CameraSubject = self.Wallstick.Humanoid
	elseif mode == "Custom" then
		self.UpVector = UNIT_Y
		self.UpVectorCamera:SetSpinPart(workspace.Terrain)
		camera.CameraSubject = self.Wallstick.Humanoid
	elseif mode == "Debug" then
		camera.CameraSubject = self.Wallstick.Physics.Humanoid
	end
end

function CameraClass:SetSpinPart(part)
	if self.Wallstick.Mode == "Custom" and CONSTANTS.CUSTOM_CAMERA_SPIN then
		self.UpVectorCamera:SetSpinPart(part)
	end
end

function CameraClass:SetUpVector(normal)
	if self.Wallstick.Mode == "Custom" then
		self.UpVector = normal
	end
end

function CameraClass:Destroy()
	self.UpVectorCamera:SetTransitionRate(1)
	self:SetSpinPart(workspace.Terrain)
	self.UpVectorCamera.GetUpVector = function(this, upVector:Vector3)
		return Vector3.new(0, 1, 0)
	end
end

type CameraClass = typeof(CameraClass)
--

return CameraClass