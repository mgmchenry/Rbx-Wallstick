--!strict

--[[
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)
local ZERO3 = Vector3.new(0, 0, 0)
]]

local UpVectorCamera = {}
local BaseCameraExtender = require(script.Parent:WaitForChild("BaseCameraExtender"))

local types = require(script.Parent:FindFirstChild("TypeHelper"))
type PlayerModuleScript = types.PlayerModuleScript
type CameraUtils = types.CameraUtils
type BaseCamera = types.BaseCamera


local PlayerModuleScript:PlayerModuleScript = game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")
local CameraModuleScript = PlayerModuleScript:WaitForChild("CameraModule")

-- Camera variables

local transitionRate = 0.15
local upVector = Vector3.new(0, 1, 0)
local upCFrame = CFrame.new()

local spinPart = workspace.Terrain
local prevSpinPart = spinPart
local prevSpinCFrame = spinPart.CFrame
local twistCFrame = CFrame.new()
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

local CameraInput = require(CameraModule:WaitForChild("CameraInput"))
function BaseCamera:CalculateNewLookCFrame(suppliedLookVector)
	return self:CalculateNewLookCFrameFromArg(suppliedLookVector, self.rotateInput)
end
-- Base Camera





local defaultUpdateMouseBehavior = BaseCamera.UpdateMouseBehavior

function BaseCamera:UpdateMouseBehavior()
	defaultUpdateMouseBehavior(self)
	if UserGameSettings.RotationType == Enum.RotationType.CameraRelative then
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative
	end
end

-- Popper Camera

local Poppercam = require(CameraModule:WaitForChild("Poppercam"))
local ZoomController = require(CameraModule:WaitForChild("ZoomController"))

function Poppercam:Update(renderDt, desiredCameraCFrame, desiredCameraFocus, cameraController)
	local rotatedFocus = desiredCameraFocus * (desiredCameraCFrame - desiredCameraCFrame.p)
	local extrapolation = self.focusExtrapolator:Step(renderDt, rotatedFocus)
	local zoom = ZoomController.Update(renderDt, rotatedFocus, extrapolation)
	return rotatedFocus*CFrame.new(0, 0, zoom), desiredCameraFocus
end
-- Vehicle Camera

local VehicleCamera = require(CameraModule:WaitForChild("VehicleCamera"))
local VehicleCameraCore = require(CameraModule.VehicleCamera:WaitForChild("VehicleCameraCore"))
local setTransform = VehicleCameraCore.setTransform

function VehicleCameraCore:setTransform(transform)
	transform = upCFrame:ToObjectSpace(transform - transform.p) + transform.p
	return setTransform(self, transform)
end
-- Camera Utilities

local Utils = require(CameraModule:WaitForChild("CameraUtils"))

function Utils.GetAngleBetweenXZVectors(v1, v2)
	v1 = upCFrame:VectorToObjectSpace(v1)
	v2 = upCFrame:VectorToObjectSpace(v2)
	return math.atan2(v2.X*v1.Z-v2.Z*v1.X, v2.X*v1.X+v2.Z*v1.Z)
end
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