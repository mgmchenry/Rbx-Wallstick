local Types = {}

Types._all = function()
	local mods = {}
	local PlayerModuleScript = game:GetService("ReplicatedStorage").PlayerModule
	mods.PlayerModuleScript = PlayerModuleScript
	local CameraModuleScript = PlayerModuleScript.CameraModule
	mods.CameraModuleScript = CameraModuleScript
	mods.PlayerModule = require(mods.PlayerModuleScript)
	mods.BaseCamera = require(PlayerModuleScript.CameraModule.BaseCamera)
	mods.CameraModulePrivateApi = require(CameraModuleScript)
	mods.CameraUtils = require(CameraModuleScript.CameraUtils)
	mods.CameraInput = require(CameraModuleScript.CameraInput)
	mods.MouseLockController = require(CameraModuleScript.MouseLockController)
	-- just returns {}
	return mods
end
export type CameraUtils = typeof(Types._all().CameraUtils)
export type CameraInput = typeof(Types._all().CameraInput)
export type BaseCamera = typeof(Types._all().BaseCamera)
export type CameraModule = typeof({})
export type CameraModulePrivateApi = typeof(Types._all().CameraModulePrivateApi)
export type MouseLockController = typeof(Types._all().MouseLockController)

export type PlayerModuleScript = typeof(Types._all().PlayerModuleScript)
export type PlayerModule = typeof(Types._all().PlayerModule)

return Types
