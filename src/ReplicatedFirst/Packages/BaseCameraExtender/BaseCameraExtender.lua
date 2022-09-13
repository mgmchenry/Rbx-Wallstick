local cameraControllers = {}
local BaseCamera:BaseCamera = require(CameraModule:WaitForChild("BaseCamera"))
local BaseCamera_new = BaseCamera.new
function BaseCamera:UpdateWithUpVector(dt,newCameraCFrame, newCameraFocus)
	return newCameraCFrame, newCameraFocus
end
local function getStaticCameraModules()
	local mods = {}
	local playerModule = game:GetService("ReplicatedStorage").PlayerModule
	mods.BaseCamera = require(playerModule.CameraModule.BaseCamera)
	mods.CameraModule = require(playerModule.CameraModule)
	return mods
end

type BaseCamera = typeof(getStaticCameraModules().BaseCamera)
type CameraModule = typeof(getStaticCameraModules().CameraModule)
local CameraModule = PlayerModule:WaitForChild("CameraModule")

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
		local controllerInfo = {
			Name = camScript.Name,
			Script = camScript,
			ControllerSelf = newSelfTable,
		}
		cameraControllers[controllerInfo.Name] = controllerInfo
		function newSelfTable:Update(dt)
			local cameraControllerMeta:BaseCamera = getmetatable(self) -- this is the underlying camera controller __index and metatable
			local newCameraCFrame, newCameraFocus 
				=  cameraControllerMeta.Update(self, dt) -- get cframe and focus from underlying camera controller update
			return self:UpdateWithUpVector(dt, newCameraCFrame, newCameraFocus)
		end
		-- sanity check:
		function newSelfTable:Enable(enable: boolean)
			if self~=newSelfTable then
				print("Something is wrong. expected self==baseTable. There will be problems")
			end
			local cameraControllerMeta:BaseCamera = getmetatable(self)
			print("Enabling camera controller:", controllerInfo.Name)
			cameraControllerMeta.Enable(self, enable)
		end
	else
		print("Can't find script calling BaseCamera.new", env)
	end
	return newSelfTable


local Camera = require(CameraModule)
print(cameraControllers)
end
