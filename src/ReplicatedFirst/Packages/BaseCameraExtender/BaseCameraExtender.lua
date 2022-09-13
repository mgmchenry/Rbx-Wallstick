--!strict
local BaseCameraExtender = {}
local types = require(script.Parent:FindFirstChild("TypeHelper"))
type PlayerModuleScript = types.PlayerModuleScript
type BaseCamera = types.BaseCamera

--[[
	We expect the following modules may extend BaseCamera when they call BaseCamera.new:
	CameraModule.VehicleCamera
	CameraModule.OrbitalCamera
	CameraModule.ClassicCamera
	CameraModule.LegacyCamera
	CameraModule.VRBaseCamera
	
	VRCamera extends VRBaseCamera
	VRVehicleCamera extends VRBaseCamera, but also pulls from VehicleCamera
	
	CameraModule.VehicleCamera
		VehicleCameraCore
		VehicleCameraConfig
		

]]

export type CameraControllerInfo = {
	Name: string,
	Script: ModuleScript,
	ControllerSelf:BaseCamera,
	ExtendedFunctions: {}
}
local cameraControllers:{[string]:CameraControllerInfo} = {}
local cameraExtensions:BaseCamera = {}
local lastActiveController:CameraControllerInfo = nil

function BaseCameraExtender:GetExtensionFunctions()
	return cameraExtensions
end

function BaseCameraExtender:PrepareToExtendCamera(controller:CameraControllerInfo)
	local cameraSelf = controller.ControllerSelf
	local savedFunctions = controller.ExtendedFunctions
	for fName, fBody in pairs(cameraExtensions) do
		if savedFunctions[fName]==nil then
			local fSave = rawget(cameraSelf, fName) or true
			savedFunctions[fName] = fSave
			print("Overriding camera controller function:", controller.Name, fName)
			rawset(cameraSelf, fName, fBody)
		end
		if savedFunctions[fName]~=fBody then
			print("Previous overide function must be updated")
			print("Overriding camera controller function:", controller.Name, fName)
			rawset(cameraSelf, fName, fBody)
		end
	end
	self:ExtendCamera(controller)
end
function BaseCameraExtender:ExtendCamera(controller:CameraControllerInfo)

end

local function init()
	local PlayerModuleScript:PlayerModuleScript = game:GetService("Players").LocalPlayer.PlayerScripts
		:WaitForChild("PlayerModule")
	local CameraModuleScript = PlayerModuleScript:WaitForChild("CameraModule")
	
	local BaseCamera:BaseCamera = require(CameraModuleScript:WaitForChild("BaseCamera"))
	local BaseCamera_new = BaseCamera.new
	function BaseCamera.new()
		local env = getfenv(2)
		local camScript:ModuleScript = env.script

		local newSelfTable:BaseCamera = BaseCamera_new()
		-- camera controller implementation (such as ClassicCamera) has called BaseCamera.new
		-- newSelfTable will be returned to actual camera controller implementation to be initialized
		-- actual controller module table will be set as the metatable of newSelfTable
		-- we can wrap any calls to the actual controller methods before we return newSelfTable:
		if typeof(camScript)=="Instance" and camScript:IsA("ModuleScript") then -- sanity check
			print("BaseCamera.new called for camera controller: ", camScript:GetFullName())
			local controllerInfo:CameraControllerInfo = {
				Name = camScript.Name,
				Script = camScript,
				ControllerSelf = newSelfTable,
				ExtendedFunctions = {},
			}
			cameraControllers[controllerInfo.Name] = controllerInfo
			
			function newSelfTable:Enable(enable: boolean)
				if self~=newSelfTable then
					print("Something is wrong. expected self==baseTable. There will be problems")
				end
				local cameraControllerMeta:BaseCamera = getmetatable(self)
				print("Enabling camera controller:", controllerInfo.Name)
				BaseCameraExtender:PrepareToExtendCamera(controllerInfo)
				lastActiveController = controllerInfo
				cameraControllerMeta.Enable(self, enable)
			end
		else
			print("Can't find script calling BaseCamera.new", env)
		end
		return newSelfTable
	end

	local Camera = require(CameraModuleScript)
	print(cameraControllers)
end

--[[
function BaseCamera:UpdateWithUpVector(dt,newCameraCFrame, newCameraFocus)
	return newCameraCFrame, newCameraFocus
end
function cameraExtensions:Update(dt)
	local cameraControllerMeta:BaseCamera = getmetatable(self) -- this is the underlying camera controller __index and metatable
	local newCameraCFrame, newCameraFocus 
		=  cameraControllerMeta.Update(self, dt) -- get cframe and focus from underlying camera controller update
	return self:UpdateWithUpVector(dt, newCameraCFrame, newCameraFocus)
end
]]

init()


return BaseCameraExtender
