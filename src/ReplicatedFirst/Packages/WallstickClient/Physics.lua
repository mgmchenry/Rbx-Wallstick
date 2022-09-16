--!strict
-- CONSTANTS

local STRIP = {
	["Part"] = true,
	["MeshPart"] = true,
	["Motor6D"] = true,
	["Humanoid"] = true,
}

local CONSTANTS = require(script.Parent:WaitForChild("Constants"))
type Wallstick = typeof(require(script.Parent.WallstickState)) & {
	-- required WallstickState definition is missing some fields:
	-- todoMgm refactor - this is fallout from clumsy workaround of circular type dependency
	Physics: PhysicsInstance,
	Humanoid: Humanoid,
}

local UpVectorCamera = require(game:GetService("ReplicatedFirst")
	:WaitForChild("Packages")
	:WaitForChild("BaseCameraExtender")
	:WaitForChild("UpVectorCamera"))

local VOID = nil :: any
local ZERO3 = Vector3.new(0, 0, 0)
local UNIT_X = Vector3.new(1, 0, 0)
local UNIT_Y = Vector3.new(0, 1, 0)
local VEC_XZ = Vector3.new(1, 0, 1)

-- Class
local typeDefs = {}
typeDefs.PhysicsInstanceState = {
	Wallstick = VOID :: Wallstick,
	World = VOID :: Model,
	Collision = VOID :: Model,
	Floor = VOID :: BasePart,
	_floorResized = VOID :: RBXScriptConnection?,
	--mgmTodo refactor - _floorResized connection:
	-- 1) should it not get a maid for consitency and safety? it is cleaned up in PhysicsClass:Destroy and PhysicsClass:UpdateFloor
	-- 2) should it not get a name that sounds more like an event handler connection?
	
	Character = VOID :: Model,
	Humanoid = VOID :: Humanoid,
	HRP = VOID :: BasePart,
	Gyro = VOID :: BodyGyro,
}
local PhysicsClass = {}
PhysicsClass.__index = PhysicsClass
PhysicsClass.ClassName = "Physics"


local function PhysicsClass_new(wallstick:Wallstick)
	local self:PhysicsInstance = setmetatable({}, PhysicsClass) :: any

	self.Wallstick = wallstick

	self.World = Instance.new("Model")
	self.World.Name = "PhysicsWorld"
	self.World.Parent = workspace.CurrentCamera

	self.Collision = Instance.new("Model")
	self.Collision.Name = "PhysicsCollision"
	self.Collision.Parent = self.World

	self.Floor = VOID
	self._floorResized = nil
	
	local character:Model = wallstick.Player.Character :: any
	self.Character = stripCopyCharacter(character)
	self.Humanoid = self.Character:WaitForChild("Humanoid") :: Humanoid
	self.HRP = self.Humanoid.RootPart :: BasePart
	
	self.Gyro = Instance.new("BodyGyro")
	self.Gyro.D = 0
	self.Gyro.MaxTorque = Vector3.new(100000, 100000, 100000)
	self.Gyro.P = 25000

	self.Character.Parent = self.World

	return self
end

-- Private Methods

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if dot < -0.99999 then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

function stripCopyCharacter(character: Model)
	local clone = nil
	local archivable = character.Archivable

	character.Archivable = true
	clone = character:Clone()
	character.Archivable = archivable

	for _, part in pairs(clone:GetDescendants()) do
		if not STRIP[part.ClassName] then
			part:Destroy()
		elseif part:IsA("BasePart") then
			part.Transparency = CONSTANTS.DEBUG_TRANSPARENCY
		end
	end

	local humanoid = clone:WaitForChild("Humanoid") :: Humanoid

	humanoid:ClearAllChildren()
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	return clone
end
 
-- Public Methods

-- selfy PhysicsClass:MatchHumanoid
function PhysicsClass.MatchHumanoid(self: PhysicsInstance, humanoid: Humanoid)
	self.Humanoid.WalkSpeed = humanoid.WalkSpeed
	self.Humanoid.JumpPower = humanoid.JumpPower
end

-- mgmTodo: I refactored self.Wallstick.Physics.HRP to self.HRP. Once I'm sure that's not a problem, remove neverHappened
local neverHappened = true
local isStudio = game:GetService("RunService"):IsStudio()
-- selfy PhysicsClass:UpdateGyro
function PhysicsClass.UpdateGyro(self: PhysicsInstance)
	local cameraCF = workspace.CurrentCamera.CFrame
	local isRelative = --self.Wallstick._camera.CameraModule:IsCamRelative()
		UpVectorCamera:IsCamRelative()

	local physicsHRPCF = --self.Wallstick.Physics.HRP.CFrame
		(self.HRP :: BasePart).CFrame
	local physicsCameraCF = physicsHRPCF *
		(self.Wallstick :: Wallstick).HRP.CFrame:ToObjectSpace(cameraCF)
	
	if neverHappened and self.Wallstick.Physics.HRP ~= self.HRP then
		warn("Wallstick PhysicsClass UpdateGyro - issue with refactor of self.Wallstick.Physics.HRP to self.HRP")
		warn("They are not equal and it was assumed that is not possible")
		if isStudio then
			error("Now you know")
		else
			neverHappened = false
		end
	end
	
	self.Gyro.CFrame = CFrame.lookAt(physicsHRPCF.Position, physicsHRPCF.Position + physicsCameraCF.LookVector * VEC_XZ)
	self.Gyro.Parent = isRelative and 
		--self.Wallstick.Physics.HRP
		self.HRP
		or nil
	
	if isRelative then
		self.Humanoid.AutoRotate = false
	else
		self.Humanoid.AutoRotate = self.Wallstick.Humanoid.AutoRotate
	end
end

-- selfy PhysicsClass:UpdateFloor(
function PhysicsClass.UpdateFloor(self:PhysicsInstance , prevPart: BasePart, newPart: BasePart, prevNormal: Vector3, newNormal: Vector3)
	if self.Floor then
		self.Floor:Destroy()
		self.Floor = VOID
	end

	local floor:BasePart = nil
	if CONSTANTS.IGNORE_CLASS_PART[newPart.ClassName] then
		local isTerrain = newPart:IsA("Terrain")
		floor = Instance.new("Part")
		floor.CanCollide = not isTerrain and newPart.CanCollide or false
		floor.Size = not isTerrain and newPart.Size or ZERO3
	else
		floor = newPart:Clone()
		floor:ClearAllChildren()
	end

	floor.Name = "PhysicsFloor"
	floor.Transparency = CONSTANTS.DEBUG_TRANSPARENCY
	floor.Anchored = true
	floor.CastShadow = false
	
	-- mgmTodo: See if there is a non-depricated workaround for setting Velocity and RotVelocity
	-- If the following lines are commented out, the character model will drift or spin incorrectly while standing on a spinning object 
	floor.Velocity = ZERO3
	floor.RotVelocity = ZERO3
	
	--[[
		Roblox script analysis claims: 
		DeprecatedApi: (187,2) Member 'BasePart.Velocity' is deprecated, use 'AssemblyLinearVelocity' instead
		DeprecatedApi: (188,2) Member 'BasePart.RotVelocity' is deprecated, use 'AssemblyAngularVelocity' instead
		however, they do not fully acomplish the same result as setting the Velocity and RotVelocity of a part
	--]]
	floor.AssemblyLinearVelocity = ZERO3
	floor.AssemblyAngularVelocity = ZERO3
	
	
	floor.CFrame = CONSTANTS.WORLD_CENTER * getRotationBetween(newNormal, UNIT_Y, UNIT_X)
	floor.Parent = self.World

	if self._floorResized then
		self._floorResized:Disconnect()
	end

	self._floorResized = newPart:GetPropertyChangedSignal("Size"):Connect(function()
		floor.Size = newPart.Size
	end)

	self.Floor = floor
end

-- selfy PhysicsClass:Destroy()
function PhysicsClass.Destroy(self:PhysicsInstance)	
	if self._floorResized then
		self._floorResized:Disconnect()
		self._floorResized = nil :: any
	end
	self.World:Destroy()
	self.Gyro:Destroy()
end

function typeDefs.GetPhysicsClassDefinition()
	return PhysicsClass
end

local PhysicsModule = {}; PhysicsModule = PhysicsClass
PhysicsModule.new = PhysicsClass_new
PhysicsModule.TypeDefs = typeDefs

typeDefs.PhysicsClass = VOID :: PhysicsClass
typeDefs.PhysicsInstanceState = VOID :: PhysicsInstanceState
typeDefs.PhysicsInstance = VOID :: PhysicsInstance
typeDefs.PhysicsModule = VOID :: PhysicsModule

export type PhysicsInstanceState = typeof(typeDefs.PhysicsInstanceState)
export type PhysicsClass = typeof(typeDefs.GetPhysicsClassDefinition())
export type PhysicsInstance = PhysicsInstanceState & PhysicsClass
export type PhysicsModule = typeof(PhysicsModule) -- & PhysicsClass

return PhysicsModule :: PhysicsModule & PhysicsClass