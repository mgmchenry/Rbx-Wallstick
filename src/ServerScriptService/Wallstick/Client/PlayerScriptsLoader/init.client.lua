--[[
	PlayerScriptsLoader - This script requires and instantiates the PlayerModule singleton

	2018 PlayerScripts Update - AllYourBlox
	2020 CameraModule Public Access Override & modifications - EgoMoose
--]]

local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)
local ZERO3 = Vector3.new(0, 0, 0)

local PlayerModule = script.Parent:WaitForChild("PlayerModule")
--local CameraInjector = script:WaitForChild("CameraInjector")
--require(CameraInjector)

-- Control Modifications

local Control = require(PlayerModule:WaitForChild("ControlModule"))
local TouchJump = require(PlayerModule.ControlModule:WaitForChild("TouchJump"))

function Control:IsJumping()
	if self.activeController then
		return self.activeController:GetIsJumping()
			or (self.touchJumpController and self.touchJumpController:GetIsJumping())
	end
	return false
end

local oldEnabled = TouchJump.UpdateEnabled

function TouchJump:UpdateEnabled()
	self.jumpStateEnabled = true
	oldEnabled(self)
end

-- Camera Modifications

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

local UserSettings = require(script:WaitForChild("FakeUserSettings"))
local UserGameSettings = 
	--game:GetService("UserGameSettings") 
	UserSettings():GetService("UserGameSettings")

--local FFlagUserFlagEnableNewVRSystem = UserSettings():SafeIsUserFeatureEnabled("UserFlagEnableNewVRSystem")

-- Camera variables

local transitionRate = 0.15
local upVector = Vector3.new(0, 1, 0)
local upCFrame = CFrame.new()

local spinPart = workspace.Terrain
local prevSpinPart = spinPart
local prevSpinCFrame = spinPart.CFrame
local twistCFrame = CFrame.new()

-- Camera Utilities

local Utils = require(CameraModule:WaitForChild("CameraUtils"))

function Utils.GetAngleBetweenXZVectors(v1, v2)
	v1 = upCFrame:VectorToObjectSpace(v1)
	v2 = upCFrame:VectorToObjectSpace(v2)
	return math.atan2(v2.X*v1.Z-v2.Z*v1.X, v2.X*v1.X+v2.Z*v1.Z)
end

local cameraControllers = {}
local BaseCamera:BaseCamera = require(CameraModule:WaitForChild("BaseCamera"))
local BaseCamera_new = BaseCamera.new
function BaseCamera:UpdateWithUpVector(dt,newCameraCFrame, newCameraFocus)
	return newCameraCFrame, newCameraFocus
end
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
end

local Camera = require(CameraModule)
print(cameraControllers)

-- Popper Camera

local Poppercam = require(CameraModule:WaitForChild("Poppercam"))
local ZoomController = require(CameraModule:WaitForChild("ZoomController"))

function Poppercam:Update(renderDt, desiredCameraCFrame, desiredCameraFocus, cameraController)
	local rotatedFocus = desiredCameraFocus * (desiredCameraCFrame - desiredCameraCFrame.p)
	local extrapolation = self.focusExtrapolator:Step(renderDt, rotatedFocus)
	local zoom = ZoomController.Update(renderDt, rotatedFocus, extrapolation)
	return rotatedFocus*CFrame.new(0, 0, zoom), desiredCameraFocus
end

-- Base Camera

--local BaseCamera = require(CameraModule:WaitForChild("BaseCamera"))

function BaseCamera:CalculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)
	local currLookVector = suppliedLookVector or self:GetCameraLookVector()
	currLookVector = upCFrame:VectorToObjectSpace(currLookVector)

	local currPitchAngle = math.asin(currLookVector.y)
	local yTheta = math.clamp(rotateInput.y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput = Vector2.new(rotateInput.x, yTheta)
	local startCFrame = CFrame.new(ZERO3, currLookVector)
	local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.x, 0) * startCFrame * CFrame.Angles(-constrainedRotateInput.y,0,0)

	return newLookCFrame
end

function BaseCamera:CalculateNewLookCFrame(suppliedLookVector)
	return self:CalculateNewLookCFrameFromArg(suppliedLookVector, self.rotateInput)
end

local defaultUpdateMouseBehavior = BaseCamera.UpdateMouseBehavior

function BaseCamera:UpdateMouseBehavior()
	defaultUpdateMouseBehavior(self)
	if UserGameSettings.RotationType == Enum.RotationType.CameraRelative then
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative
	end
end

-- Vehicle Camera

local VehicleCamera = require(CameraModule:WaitForChild("VehicleCamera"))
local VehicleCameraCore = require(CameraModule.VehicleCamera:WaitForChild("VehicleCameraCore"))
local setTransform = VehicleCameraCore.setTransform

function VehicleCameraCore:setTransform(transform)
	transform = upCFrame:ToObjectSpace(transform - transform.p) + transform.p
	return setTransform(self, transform)
end

-- Camera Module

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if dot < -0.99999 then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

local function twistAngle(cf, direction)
	local axis, theta = cf:ToAxisAngle()
	local w, v = math.cos(theta/2),  math.sin(theta/2)*axis
	local proj = v:Dot(direction)*direction
	local twist = CFrame.new(0, 0, 0, proj.x, proj.y, proj.z, w)
	local nAxis, nTheta = twist:ToAxisAngle()
	return math.sign(v:Dot(direction))*nTheta
end

local function calculateUpCFrame(self)
	local newUpVector = self:GetUpVector(upVector)

	local axis = workspace.CurrentCamera.CFrame.RightVector
	local sphericalArc = getRotationBetween(upVector, newUpVector, axis)
	local transitionCF = CFrame.new():Lerp(sphericalArc, transitionRate)

	upVector = transitionCF * upVector
	upCFrame = transitionCF * upCFrame
end

local function calculateSpinCFrame(self)
	local theta = 0
	
	if spinPart == prevSpinPart then
		local rotation = spinPart.CFrame - spinPart.CFrame.p
		local prevRotation = prevSpinCFrame - prevSpinCFrame.p

		local spinAxis = rotation:VectorToObjectSpace(upVector)
		theta = twistAngle(prevRotation:ToObjectSpace(rotation), spinAxis)
	end

	twistCFrame = CFrame.fromEulerAnglesYXZ(0, theta, 0)

	prevSpinPart = spinPart
	prevSpinCFrame = spinPart.CFrame
end

--local Camera = require(CameraModule)
local CameraInput = require(CameraModule:WaitForChild("CameraInput"))

function Camera:GetUpVector(oldUpVector)
	return oldUpVector
end

function Camera:SetSpinPart(part)
	spinPart = part
end

function Camera:SetTransitionRate(rate)
	transitionRate = rate
end

function Camera:GetTransitionRate()
	return transitionRate
end

BaseCamera.UpdateWithUpVector = function(self, dt, newCameraCFrame, newCameraFocus)
	newCameraFocus = CFrame.new(newCameraFocus.p) -- vehicle camera fix

	calculateUpCFrame(Camera, dt)
	calculateSpinCFrame(Camera)

	local lockOffset = Vector3.new(0, 0, 0)
	if Camera.activeMouseLockController and Camera.activeMouseLockController:GetIsMouseLocked() then
		lockOffset = Camera.activeMouseLockController:GetMouseLockOffset()
	end

	local offset = newCameraFocus:ToObjectSpace(newCameraCFrame)
	local camRotation = upCFrame * twistCFrame * offset
	newCameraFocus = newCameraFocus - newCameraCFrame:VectorToWorldSpace(lockOffset) + camRotation:VectorToWorldSpace(lockOffset)
	newCameraCFrame = newCameraFocus * camRotation
	return newCameraCFrame, newCameraFocus
end

function Camera:UpdateXXX(dt)
	if self.activeCameraController then
		self.activeCameraController:UpdateMouseBehavior()

		local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)
		newCameraFocus = CFrame.new(newCameraFocus.p) -- vehicle camera fix
		--self.activeCameraController:ApplyVRTransform()

		calculateUpCFrame(self, dt)
		calculateSpinCFrame(self)

		local lockOffset = Vector3.new(0, 0, 0)
		if self.activeMouseLockController and self.activeMouseLockController:GetIsMouseLocked() then
			lockOffset = self.activeMouseLockController:GetMouseLockOffset()
		end

		local offset = newCameraFocus:ToObjectSpace(newCameraCFrame)
		local camRotation = upCFrame * twistCFrame * offset
		newCameraFocus = newCameraFocus - newCameraCFrame:VectorToWorldSpace(lockOffset) + camRotation:VectorToWorldSpace(lockOffset)
		newCameraCFrame = newCameraFocus * camRotation

		if self.activeOcclusionModule then
			newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
		end

		-- Here is where the new CFrame and Focus are set for this render frame
		local currentCamera = game.Workspace.CurrentCamera :: Camera
		currentCamera.CFrame = newCameraCFrame
		currentCamera.Focus = newCameraFocus

		-- Update to character local transparency as needed based on camera-to-subject distance
		if self.activeTransparencyController then
			self.activeTransparencyController:Update(dt)
		end

		if CameraInput.getInputEnabled() then
			CameraInput.resetInputForFrameEnd()
		end
	end
end

function Camera:IsFirstPerson()
	if self.activeCameraController then
		return self.activeCameraController.inFirstPerson
	end
	return false
end

function Camera:IsMouseLocked()
	if self.activeCameraController then
		return self.activeCameraController:GetIsMouseLocked()
	end
	return false
end

function Camera:IsToggleMode()
	if self.activeCameraController then
		return self.activeCameraController.isCameraToggle
	end
	return false
end

function Camera:IsCamRelative()
	return self:IsMouseLocked() or self:IsFirstPerson()
	--return self:IsToggleMode(), self:IsMouseLocked(), self:IsFirstPerson()
end

--

require(PlayerModule)