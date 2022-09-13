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

local activeCameraController: types.BaseCamera = nil 
local transitionRate = 0.15
local upVector = Vector3.new(0, 1, 0)
local upCFrame = CFrame.new()

local spinPart:BasePart = workspace.Terrain
local prevSpinPart:Instance = spinPart
local prevSpinCFrame = spinPart.CFrame
local twistCFrame = CFrame.new()

BaseCameraExtender.ExtendCamera = function(self, controllerInfo)
	activeCameraController = controllerInfo.ControllerSelf
end

function UpVectorCamera:GetUpVector(oldUpVector:Vector3)
	return oldUpVector	
end

function UpVectorCamera.SetUpVector(newUpVector:Vector3)
	upVector = newUpVector
end

function UpVectorCamera:SetSpinPart(part)
	spinPart = part
end

function UpVectorCamera:SetTransitionRate(rate)
	transitionRate = rate
end

function UpVectorCamera:GetTransitionRate()
	return transitionRate
end

function UpVectorCamera:IsCamRelative() : boolean
	if activeCameraController then
		return activeCameraController.inFirstPerson or activeCameraController.inMouseLockedMode
		--return activeCameraController:GetIsMouseLocked() or activeCameraController:IsInFirstPerson()
	end
	return false
end


--[[
-- These functions are no longer used:
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
]]

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if dot < -0.99999 then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

local function twistAngle(cf:CFrame, direction)
	local axis:Vector3, theta:number = cf:ToAxisAngle()
	local w, v = math.cos(theta/2),  math.sin(theta/2)*axis
	local proj:Vector3 = v:Dot(direction)*direction
	local twist = CFrame.new(0, 0, 0, proj.X, proj.Y, proj.Z, w)
	local nAxis, nTheta = twist:ToAxisAngle()
	return math.sign(v:Dot(direction))*nTheta
end

local function calculateUpCFrame(dt:number)
	--mgmTodo: factor in dt?
	local newUpVector = UpVectorCamera:GetUpVector(upVector)

	local axis = workspace.CurrentCamera.CFrame.RightVector
	local sphericalArc = getRotationBetween(upVector, newUpVector, axis)
	local transitionCF = CFrame.new():Lerp(sphericalArc, transitionRate)

	upVector = transitionCF * upVector
	upCFrame = transitionCF * upCFrame
end


local function calculateSpinCFrame()
	local theta = 0

	if spinPart == prevSpinPart then
		local rotation = spinPart.CFrame - spinPart.CFrame.Position
		local prevRotation = prevSpinCFrame - prevSpinCFrame.Position

		local spinAxis = rotation:VectorToObjectSpace(upVector)
		theta = twistAngle(prevRotation:ToObjectSpace(rotation), spinAxis)
	end

	twistCFrame = CFrame.fromEulerAnglesYXZ(0, theta, 0)

	prevSpinPart = spinPart
	prevSpinCFrame = spinPart.CFrame
end

local CameraExtensions = BaseCameraExtender:GetExtensionFunctions()

-- mgmTodo: Hook MouseLockController.new
local MouseLockController:types.MouseLockController = nil

function CameraExtensions:Update(dt:number, ...)
	local cameraControllerMeta:BaseCamera = getmetatable(self) -- this is the underlying camera controller __index and metatable
	local newCameraCFrame, newCameraFocus 
		=  cameraControllerMeta.Update(self, dt, ...) -- get cframe and focus from underlying camera controller update
	
	--return self:UpdateWithUpVector(dt, newCameraCFrame, newCameraFocus)
	newCameraFocus = CFrame.new(newCameraFocus.p) -- vehicle camera fix

	calculateUpCFrame(dt)
	calculateSpinCFrame()

	local lockOffset = Vector3.new(0, 0, 0)
	if MouseLockController and MouseLockController:GetIsMouseLocked() then
		lockOffset = MouseLockController:GetMouseLockOffset()
	end

	local offset = newCameraFocus:ToObjectSpace(newCameraCFrame)
	local camRotation = upCFrame * twistCFrame * offset
	newCameraFocus = newCameraFocus - newCameraCFrame:VectorToWorldSpace(lockOffset) + camRotation:VectorToWorldSpace(lockOffset)
	newCameraCFrame = newCameraFocus * camRotation
	
	

	self.lastCameraTransform = newCameraCFrame
	self.lastCameraFocus = newCameraFocus
	
	return newCameraCFrame, newCameraFocus, ...
end

function CameraExtensions:CalculateNewLookCFrameFromArg(suppliedLookVector: Vector3?, rotateInput:Vector2, ...)
	local currLookVector = suppliedLookVector or self:GetCameraLookVector()
	currLookVector = upCFrame:VectorToObjectSpace(currLookVector, ...)
	
	-- get underlying camera controller __index and metatable
	local cameraControllerMeta:BaseCamera = getmetatable(self)
	return cameraControllerMeta.CalculateNewLookCFrameFromArg(self, currLookVector, rotateInput, ...)
end

--[[
-- Depricated after FFlagUserCameraInputRefactor:
local CameraInput: types.CameraInput = require(CameraModuleScript:WaitForChild("CameraInput"))
function CameraExtensions:CalculateNewLookCFrame(suppliedLookVector)
	local rotateInput = CameraInput.getRotation()
	-- self.rotateInput is no longer a property of camera controllers
	return self:CalculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)
end
]]

local CameraUtils:CameraUtils = require(CameraModuleScript:WaitForChild("CameraUtils"))

-- todo: see if this is still needed
function CameraExtensions:UpdateMouseBehavior()
	-- get underlying camera controller __index and metatable
	local cameraControllerMeta:BaseCamera = getmetatable(self)
	cameraControllerMeta.UpdateMouseBehavior(self)
	CameraUtils.setRotationTypeOverride(Enum.RotationType.MovementRelative)
	--[[
	if UserGameSettings.RotationType == Enum.RotationType.CameraRelative then
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative
	end
	]]
end


-- Popper Camera

local Poppercam = require(CameraModuleScript:WaitForChild("Poppercam"))
local ZoomController = require(CameraModuleScript:WaitForChild("ZoomController"))

function Poppercam:Update(renderDt, desiredCameraCFrame, desiredCameraFocus, cameraController)
	local rotatedFocus = desiredCameraFocus * (desiredCameraCFrame - desiredCameraCFrame.p)
	local extrapolation = self.focusExtrapolator:Step(renderDt, rotatedFocus)
	local zoom = ZoomController.Update(renderDt, rotatedFocus, extrapolation)
	return rotatedFocus*CFrame.new(0, 0, zoom), desiredCameraFocus
end

local cameraUtils_base = {
	GetAngleBetweenXZVectors = CameraUtils.GetAngleBetweenXZVectors
}


-- Vehicle Camera
local VehicleCamera = require(CameraModuleScript:WaitForChild("VehicleCamera"))
local VehicleCameraCore = require(CameraModuleScript.VehicleCamera:WaitForChild("VehicleCameraCore"))
local setTransform = VehicleCameraCore.setTransform

function VehicleCameraCore:setTransform(transform)
	transform = upCFrame:ToObjectSpace(transform - transform.p) + transform.p
	return setTransform(self, transform)
end

function UpVectorCamera.EnableUpVector()
	function CameraUtils.GetAngleBetweenXZVectors(v1, v2)
		v1 = upCFrame:VectorToObjectSpace(v1)
		v2 = upCFrame:VectorToObjectSpace(v2)
		return math.atan2(v2.X*v1.Z-v2.Z*v1.X, v2.X*v1.X+v2.Z*v1.Z)
	end
end

function UpVectorCamera.DisableUpVector()
	CameraUtils.GetAngleBetweenXZVectors = cameraUtils_base.GetAngleBetweenXZVectors
end



local function considerRemovingTheseFunctions()
	-- Control Modifications
	local Control = require(PlayerModuleScript:WaitForChild("ControlModule"))
	local TouchJump = require(PlayerModuleScript:WaitForChild("ControlModule")
		:WaitForChild("TouchJump"))
	
	--[[ 
	-- ControlModule.IsJumping() is never called by any code anywhere
	function Control:IsJumping()
		if self.activeController then
			return self.activeController:GetIsJumping()
				or (self.touchJumpController and self.touchJumpController:GetIsJumping())
		end
		return false
	end
	]]
	
	
	local oldEnabled = TouchJump.UpdateEnabled
	function TouchJump:UpdateEnabled()
		if not self.jumpStateEnabled then
			print("jumpState is not enabled, so TouchJump:UpdateEnabled override was used")
			self.jumpStateEnabled = true
			--[[
				mgmTodo - I don't know if this is needed.
				TouchJump.jumpStateEnabled is set to false potentially here:
				function TouchJump:HumanoidStateEnabledChanged(state, isEnabled)
					if state == Enum.HumanoidStateType.Jumping then
						self.jumpStateEnabled = isEnabled
						self:UpdateEnabled()
					end
				end
				
				or near end of TouchJump:CharacterAdded(char):
				
				self.jumpStateEnabled = self.humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
				
			]]
		end
		oldEnabled(self)
	end
end
considerRemovingTheseFunctions()
UpVectorCamera.EnableUpVector()

return UpVectorCamera
