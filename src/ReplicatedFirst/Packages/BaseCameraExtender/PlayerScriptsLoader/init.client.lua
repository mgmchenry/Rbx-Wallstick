--!strict
--[[
	PlayerScriptsLoader - This script requires and instantiates the PlayerModule singleton

	2018 PlayerScripts Update - AllYourBlox
	2020 CameraModule Public Access Override & modifications - EgoMoose
	2022 Moved UpVector Implementation to ReplicatedFirst.Packages.BaseCameraExtender
.UpVectorCamera - mgmchenry
--]]


local PlayerModule = script.Parent:WaitForChild("PlayerModule")
--local CameraInjector = script:WaitForChild("CameraInjector")
--require(CameraInjector)

local cameraExtenderPath = game:GetService("ReplicatedFirst")
:WaitForChild("Packages")
:WaitForChild("BaseCameraExtender")

--local BaseCameraExtender = require(cameraExtenderPath:WaitForChild("BaseCameraExtender"))
local UpVectorCamera = require(cameraExtenderPath:WaitForChild("UpVectorCamera"))

-- Camera Modifications


--[[
local UserSettings = require(script:WaitForChild("FakeUserSettings"))
local UserGameSettings = 
	--game:GetService("UserGameSettings") 
	UserSettings():GetService("UserGameSettings")
]]
	
--local FFlagUserFlagEnableNewVRSystem = UserSettings():SafeIsUserFeatureEnabled("UserFlagEnableNewVRSystem")


require(PlayerModule)