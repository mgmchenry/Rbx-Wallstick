--!strict
local PhysicsService = game:GetService("PhysicsService")

local CONSTANTS = {
	DEFAULT_CAMERA_MODE = (nil :: any) :: CameraModeEnum
}

CONSTANTS.WORLD_CENTER = CFrame.new(10000, 0, 0)
CONSTANTS.COLLIDER_SIZE2 = Vector3.new(32, 32, 32)
CONSTANTS.PHYSICS_ID = PhysicsService:GetCollisionGroupId("WallstickCharacters")

CONSTANTS.SEND_REPLICATION = true -- only disable if only using wallstick on the client
CONSTANTS.REPLICATE_RATE = 0.1 -- send an update every x seconds

CONSTANTS.DEBUG = false
CONSTANTS.DEBUG_TRANSPARENCY = CONSTANTS.DEBUG and 0 or 1

--[[
mgmTodo: Refactor this terrible messy attempt at creating a simple enum in luau
it went through at least 5 iterations before it was giving appropriate script analysis messages
mgmTodo: need to better communicate the intention of "Default" camera mode
a) In Camera module, "Default" seems to mean roblox defualt camera without UpVector adjustment
b) In Physics module, DEFAULT_CAMERA_MODE seems to indicate the camera mode to use for wallstick initialization
]]
export type CameraModeEnum = ("Debug" | "Custom" | "Default")
local CameraModeEnum = {
	Debug = "Debug" :: CameraModeEnum,
	Custom = "Custom" :: CameraModeEnum,
	Default = "Custom" :: CameraModeEnum
	-- mgmTodo - is Default ever used?
}

function CONSTANTS.GetDefaultCameraMode() : CameraModeEnum
	if CONSTANTS.DEBUG then return CameraModeEnum.Debug end
	return CameraModeEnum.Custom
end

local defaultCameraMode: CameraModeEnum = -- Custom or Default 
	CONSTANTS.GetDefaultCameraMode()
CameraModeEnum.Default = defaultCameraMode :: CameraModeEnum

CONSTANTS.CameraModeEnum = CameraModeEnum

CONSTANTS.DEFAULT_CAMERA_MODE = defaultCameraMode :: ("Debug" | "Custom" | "Default")

CONSTANTS.CUSTOM_CAMERA_SPIN = true -- if in custom camera match the part spin
CONSTANTS.MAINTAIN_WORLD_VELOCITY = true -- maintains world space velocity when using the :Set() method
CONSTANTS.PLAYER_COLLISIONS = true -- if you can collide with other players

CONSTANTS.IGNORE_CLASS_PART = {
	["Terrain"] = true,
	["SpawnLocation"] = true,
	["Seat"] = true,
	["VehicleSeat"] = true
}

CONSTANTS.CHARACTER_PART_NAMES = {
	["HumanoidRootPart"] = true,
	["Head"] = true,
	["UpperTorso"] = true,
	["LowerTorso"] = true,
	["LeftFoot"] = true,
	["LeftLowerLeg"] = true,
	["LeftUpperLeg"] = true,
	["RightFoot"] = true,
	["RightLowerLeg"] = true,
	["RightUpperLeg"] = true,
	["LeftHand"] = true,
	["LeftLowerArm"] = true,
	["LeftUpperArm"] = true,
	["RightHand"] = true,
	["RightLowerArm"] = true,
	["RightUpperArm"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	["Torso"] = true,
}

CONSTANTS.CHARACTER_COLLISION_PART_NAMES = {
	["HumanoidRootPart"] = true,
	["Head"] = true,
	["UpperTorso"] = true,
	["LowerTorso"] = true,
	["Torso"] = true,
}

CONSTANTS.IGNORE_STATES = {
	[Enum.HumanoidStateType.None] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

return CONSTANTS