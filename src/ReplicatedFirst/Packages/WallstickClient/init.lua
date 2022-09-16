--!strict
-- CONSTANTS

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONSTANTS = require(script:WaitForChild("Constants"))

local ZERO3 = Vector3.new(0, 0, 0)
local UNIT_Y = Vector3.new(0, 1, 0)
local VOID = nil :: any

local WallstickConfig = require(script:FindFirstChild("WallstickConfig"))
local RemotesParent = WallstickConfig.Get.RemoteParent()


local Remotes = --script:WaitForChild("Remotes")
	RemotesParent:WaitForChild("WallstickRemotes")
	--workspace:WaitForChild("Remotes")
local Utility = script:WaitForChild("Utility")
local Maid = require(Utility:WaitForChild("Maid"))
local Signal = require(Utility:WaitForChild("Signal"))


local CharacterModules = script:WaitForChild("CharacterModules")
local Camera = require(CharacterModules:WaitForChild("Camera"))
local Control = require(CharacterModules:WaitForChild("Control"))
local Animation = require(CharacterModules:WaitForChild("Animation"))
local Physics = require(script:WaitForChild("Physics"))

local ReplicatePhysics:RemoteEvent = Remotes:WaitForChild("ReplicatePhysics") :: any
local SetCollidable:RemoteEvent = Remotes:WaitForChild("SetCollidable") :: any

-- Class

type CameraModeEnum = CONSTANTS.CameraModeEnum
type Physics = Physics.PhysicsInstance --typeof(Physics.new(nil :: any))
type Camera = Camera.CameraInstance -- typeof(Camera.new(nil :: any))
type Control = typeof(Control.new(VOID :: WallstickInstance))
type Animation = typeof(Animation.new(VOID :: WallstickInstance))
local typeDefs = {}

local WallstickClass = {
	--HRP = (nil :: any) :: BasePart,
	--Physics = (nil :: any) :: Physics,
	--_camera = (nil :: any) :: Camera,
}
WallstickClass.__index = WallstickClass
WallstickClass.ClassName = "Wallstick"

local WallstickModule = {}; WallstickModule = WallstickClass

-- Public Constructors
function getNewWallstickState()
	local self = {}
	self._seated = false
	self._replicateTick = -1
	self._collisionParts = {}
	self._fallStart = 0

	self.Normal = UNIT_Y
	self.Part = VOID :: BasePart
	self.Mode = VOID :: CameraModeEnum

	self.Maid = Maid.new()
	self.Changed = Signal.new()
	
	
	return self :: typeof(self) & {
		--Player: string -- wallstick for an NPC would need a character, but not a player
		-- mgmTodo, but that's a problem for another time
		-- these properties are assigned in WallstickModule.new(Player)
		Player: Player,
		Character: Model,
		Humanoid: Humanoid,
		HRP: BasePart,
	}
end

--[[ this can be removed. 
--This method got added to account for initializing Wallstick before Player.Character.Humanoid.RootPart might be fully present
--Instead, Wallstick requires these to be present before initializing
function WallstickClass:CharacterAdded(character:Model)
	self.Character = character
	local humanoid:Humanoid = character:WaitForChild("Humanoid") :: any
	self.Humanoid = humanoid
	self.HRP = humanoid.RootPart :: BasePart
end
]]

typeDefs.WallstickState = VOID :: (typeof(getNewWallstickState()) & {
	-- these properties require a wallstick instance to be created before they can be set. would be good to refactor that
	Physics: Physics,
	_camera: Camera,
	_control: Control,
	_animation: Animation,
})

function WallstickModule.new( player:Player)
	local self: WallstickInstance = setmetatable(getNewWallstickState(), WallstickClass) :: any
	
	assert(player~=nil and player:IsA("Player"), "Can't create wallstick controller without player. yet.")
	self.Player = player
	
	assert(player.Character~=nil and player.Character:IsA("Model"), "Can't create wallstick controller without a player character model")
	self.Character = player.Character
	
	local humanoid:Instance? = self.Character:FindFirstChild("Humanoid")
	assert(humanoid~=nil and humanoid:IsA("Humanoid"), "Can't create wallstick controller without a character model humanoid")	
	self.Humanoid = humanoid
	
	assert(humanoid.RootPart~=nil and humanoid.RootPart:IsA("BasePart"), "Can't create wallstick controller without a humanoid root part")
	self.HRP = humanoid.RootPart :: BasePart
	
	-- mgmTodo: Refactor these sanity checks I added for testing/qa purposes
	-- they most likely aren't needed or should only be enabled in debug mode
	self.Maid:Mark(
		player.CharacterAdded:Connect(function(character:Model)
			warn("possibly stale wallstick controller is attached to a player that fired CharacterAdded") 
		end)
	)
	self.Maid:Mark(
		player.CharacterRemoving:Connect(function(character:Model)
			warn("stale wallstick controller needs to be shut down on player that fired CharacterRemoving") 
		end)
	)
	self.Maid:Mark(
		--humanoid.Died?
		humanoid.Destroying:Connect(function()
			warn("stale wallstick controller needs to be shut down on player that fired humanoid.Destroying") 
		end)
	)
	self.Maid:Mark(
		humanoid:GetPropertyChangedSignal("RootPart"):Connect(function()
			error("wallstick controller needs to deal with a changed humanoid.RootPart") 
		end)
	)
	
	self.Physics = Physics.new(self)
	self._camera = Camera.new(self)
	self._control = Control.new(self)
	self._animation = Animation.new(self)
	
	self:_init()

	return self
end


-- Private Methods


local function setCollisionGroupId(array: {Instance}, id: number)
	for _, part in pairs(array) do
		if part:IsA("BasePart") then
			part.CollisionGroupId = id
		end
	end
end

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if dot < -0.99999 then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

local function generalStep(self: WallstickInstance, dt)
	self.HRP.Velocity = ZERO3
	self.HRP.RotVelocity = ZERO3
	self.HRP.CFrame = self.Part.CFrame * self.Physics.Floor.CFrame:ToObjectSpace(self.Physics.HRP.CFrame)

	if not self.Part:IsDescendantOf(workspace) then
		self:Set(workspace.Terrain, UNIT_Y)
	end

	self.Physics:MatchHumanoid(self.Humanoid)
	self.Physics:UpdateGyro()
	self._camera:SetUpVector(self.Part.CFrame:VectorToWorldSpace(self.Normal))
end

local function collisionStep(self: WallstickInstance, dt)
	local parts = workspace:FindPartsInRegion3WithIgnoreList(Region3.new(
		self.HRP.Position - CONSTANTS.COLLIDER_SIZE2,
		self.HRP.Position + CONSTANTS.COLLIDER_SIZE2
	), {self.Character, self.Physics.World}, 1000)

	local newCollisionParts = {}
	local collisionParts = self._collisionParts

	local stickPart = self.Part
	local stickPartCF = stickPart.CFrame
	local floorCF = self.Physics.Floor.CFrame

	for _, part in pairs(parts) do
		if collisionParts[part] then
			local physicsPart = collisionParts[part]
			physicsPart.CFrame = floorCF:ToWorldSpace(stickPartCF:ToObjectSpace(part.CFrame))
			physicsPart.CanCollide = part.CanCollide

			if physicsPart.Name == "CharacterPart" then
				if not CONSTANTS.PLAYER_COLLISIONS then
					physicsPart.CanCollide = false
				else
					physicsPart.CanCollide = CONSTANTS.CHARACTER_COLLISION_PART_NAMES[part.Name]
				end
			end

			newCollisionParts[part] = physicsPart
		elseif part ~= stickPart and part.CanCollide then
			local physicsPart

			if CONSTANTS.IGNORE_CLASS_PART[part.ClassName] then
				physicsPart = Instance.new("Part")
				physicsPart.CanCollide = part.CanCollide
				physicsPart.Size = part.Size
			else
				local character = CONSTANTS.CHARACTER_PART_NAMES[part.Name] and part.Parent
				local player = Players:GetPlayerFromCharacter(character)

				if player then
					physicsPart = Instance.new("Part")
					physicsPart.Name = "CharacterPart"
					physicsPart.Size = part.Size

					if not CONSTANTS.PLAYER_COLLISIONS then
						physicsPart.CanCollide = false
					else
						physicsPart.CanCollide = CONSTANTS.CHARACTER_COLLISION_PART_NAMES[part.Name]
					end

					if part.CollisionGroupId == CONSTANTS.PHYSICS_ID then
						physicsPart.CollisionGroupId = 0
					end
				else
					physicsPart = part:Clone()
					physicsPart.Name = "Part"
					physicsPart:ClearAllChildren()
				end
			end

			physicsPart.CFrame = floorCF:ToWorldSpace(stickPartCF:ToObjectSpace(part.CFrame))
			physicsPart.Transparency = CONSTANTS.DEBUG_TRANSPARENCY
			physicsPart.Anchored = true
			physicsPart.CastShadow = false
			
			-- mgmtodo: figure out if I can just use the non-depricated properties
			physicsPart.Velocity = ZERO3
			physicsPart.RotVelocity = ZERO3
			--[[
				mgm 2022-0912 - I tested switching away from the depricated properties in WallstickClient and it didn't cause obvious problems like changing it in Physics
				Once I understand what the difference is, I'll reconsider getting rid of Velocity and RotVelocity
				
				Roblox script analysis claims: 
				DeprecatedApi: (187,2) Member 'BasePart.Velocity' is deprecated, use 'AssemblyLinearVelocity' instead
				DeprecatedApi: (188,2) Member 'BasePart.RotVelocity' is deprecated, use 'AssemblyAngularVelocity' instead
				however, they do not fully acomplish the same result as setting the Velocity and RotVelocity of a part
			--]]
			physicsPart.AssemblyLinearVelocity = ZERO3
			physicsPart.AssemblyAngularVelocity = ZERO3
			
			physicsPart.Parent = self.Physics.Collision

			newCollisionParts[part] = physicsPart
			collisionParts[part] = physicsPart
		end
	end

	self.Physics.Floor.CanCollide = stickPart.CanCollide

	for part, physicsPart in pairs(collisionParts) do
		if not newCollisionParts[part] then
			collisionParts[part] = nil
			physicsPart:Destroy()
		end
	end
end

local VRService = game:GetService("VRService")

local function characterStep(self: WallstickInstance, dt)
	local move = self._control:GetMoveVector()
	local cameraCF = workspace.Camera.CFrame
	--local viewAdjustment = CFrame.identity
	if VRService.VREnabled then
		-- mgmTodo: VR Support has far to go. This does not work
		-- Several VRCamera methods need separate overrides on them in UpVectorCamera
		local headCF = VRService:GetUserCFrame(Enum.UserCFrame.Head)
		move = headCF:VectorToObjectSpace(move)
		cameraCF = cameraCF * headCF
	end
	
	if self.Mode ~= "Debug" then
		local physicsCameraCF = self.Physics.HRP.CFrame * self.HRP.CFrame:ToObjectSpace(cameraCF)

		local c, s
		local _, _, _, R00, R01, R02, _, R11, R12, _, _, R22 =  physicsCameraCF:GetComponents()
		local q = math.sign(R11)

		if R12 < 1 and R12 > -1 then
			c = R22
			s = R02
		else
			c = R00
			s = -R01*math.sign(R12)
		end
		
		local norm = math.sqrt(c*c + s*s)
		move = Vector3.new(
			(c*move.x*q + s*move.z)/norm,
			0,
			(c*move.z - s*move.x*q)/norm
		)
	
		self.Physics.Humanoid:Move(move, false)
	else
		self.Physics.Humanoid:Move(move, true)
	end

	local physicsHRPCF = self.Physics.HRP.CFrame
	self.HRP.Velocity = self.HRP.CFrame:VectorToWorldSpace(physicsHRPCF:VectorToObjectSpace(self.Physics.HRP.Velocity))
	self.HRP.RotVelocity = self.HRP.CFrame:VectorToWorldSpace(physicsHRPCF:VectorToObjectSpace(self.Physics.HRP.RotVelocity))
end

local function replicateStep(self, dt)
	local t = os.clock()
	if CONSTANTS.SEND_REPLICATION and t - self._replicateTick >= CONSTANTS.REPLICATE_RATE then
		local offset = self.Physics.Floor.CFrame:ToObjectSpace(self.Physics.HRP.CFrame)
		ReplicatePhysics:FireServer(self.Part, offset, false, false)
		self._replicateTick = t
	end
end

local function setSeated(self: WallstickInstance, bool)
	if self._seated == bool then
		return
	end

	if not bool then
		self.Physics.HRP.Anchored = false
		self._animation.ReplicatedHumanoid.Value = self.Physics.Humanoid
		setCollisionGroupId(self.Character:GetChildren(), CONSTANTS.PHYSICS_ID)
		self.Humanoid.PlatformStand = true
		self:Set(self.Part, self.Normal)
	elseif self.Humanoid.SeatPart==nil then
		warn("WallstickClient called setseated with unseated humanoid")
		setSeated(self, false)
	else
		self:Set(self.Humanoid.SeatPart, UNIT_Y)
		self.Physics.HRP.Anchored = true
		self._animation.ReplicatedHumanoid.Value = self.Humanoid
		setCollisionGroupId(self.Character:GetChildren(), 0)
		ReplicatePhysics:FireServer(nil, nil, nil, true)
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Seated)
	end

	self._seated = bool
end

function WallstickClass._init(self:WallstickInstance)
	setCollisionGroupId(self.Character:GetChildren(), CONSTANTS.PHYSICS_ID)
	SetCollidable:FireServer(false)

	self.Humanoid.PlatformStand = true
	self:SetMode(CONSTANTS.GetDefaultCameraMode()) --CONSTANTS.DEFAULT_CAMERA_MODE)
	self:Set(workspace.Terrain, UNIT_Y)

	self.Maid:Mark(self._camera)
	self.Maid:Mark(self._control)
	self.Maid:Mark(self._animation)
	self.Maid:Mark(self.Physics)

	setSeated(self, not not self.Humanoid.SeatPart)
	self.Maid:Mark(self.Humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		setSeated(self, not not self.Humanoid.SeatPart)
	end))

	self.Maid:Mark(self.Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if self.Humanoid.Jump then
			self.Physics.Humanoid.Jump = true
		end
	end))

	self.Maid:Mark(self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))

	self.Maid:Mark(self.Character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Destroy()
		end
	end))

	self.Maid:Mark(self.Physics.Humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			self._fallStart = (self.Physics :: Physics).HRP.Position.Y
		end
	end))

	RunService:BindToRenderStep("WallstickStep", Enum.RenderPriority.Camera.Value - 1, function(dt) self:WallstickStep(dt) end)
end

function WallstickClass:WallstickStep(dt)
	if self._seated then
		self._camera:SetUpVector(self.HRP.CFrame.YVector)
		return
	end

	generalStep(self, dt)
	collisionStep(self, dt)
	characterStep(self, dt)
	replicateStep(self, dt)

	local height, distance = self:GetFallHeight()
	if height <= workspace.FallenPartsDestroyHeight then
		self:Destroy()
	end	
end

-- Public Methods

function WallstickClass.SetMode(self: WallstickInstance, mode: CameraModeEnum)
	self.Mode = mode
	self._camera:SetMode(mode)
end

function WallstickClass:GetTransitionRate()
	return self._camera.UpVectorCamera:GetTransitionRate()
end

function WallstickClass:SetTransitionRate(rate)
	(self._camera :: Camera).UpVectorCamera:SetTransitionRate(rate)
end

function WallstickClass:GetFallHeight()
	local self = self :: WallstickInstance
	
	local height = self.Physics.HRP.Position.Y
	return height, height - self._fallStart
end

function WallstickClass.Set(self: WallstickInstance, part: BasePart, normal: Vector3, teleportCF:CFrame?)
	if self._seated then
		return
	end

	local physicsHRP = self.Physics.HRP
	local vel = physicsHRP.CFrame:VectorToObjectSpace(physicsHRP.Velocity)
	local rotVel = physicsHRP.CFrame:VectorToObjectSpace(physicsHRP.RotVelocity)

	local oldPart = self.Part
	local oldNormal = self.Normal

	self.Physics:UpdateFloor(self.Part, part, self.Normal, normal)
	self.Part = part
	self.Normal = normal

	if self._collisionParts[part] then
		self._collisionParts[part]:Destroy()
		self._collisionParts[part] = nil
	end

	local camera = workspace.CurrentCamera
	local cameraOffset = self.Physics.HRP.CFrame:ToObjectSpace(camera.CFrame)
	local focusOffset = self.Physics.HRP.CFrame:ToObjectSpace(camera.Focus)

	local targetCF = self.Physics.Floor.CFrame * part.CFrame:ToObjectSpace(teleportCF or self.HRP.CFrame)
	local sphericalArc = getRotationBetween(targetCF.YVector, UNIT_Y, targetCF.XVector)

	physicsHRP.CFrame = (sphericalArc * (targetCF - targetCF.Position)) + targetCF.Position
	self._fallStart = self.Physics.HRP.Position.Y
	
	if CONSTANTS.MAINTAIN_WORLD_VELOCITY then
		physicsHRP.Velocity = targetCF:VectorToWorldSpace(vel)
		physicsHRP.RotVelocity = targetCF:VectorToWorldSpace(rotVel)
	end

	self._camera:SetSpinPart(part)

	if self.Mode == "Debug" then
		camera.CFrame = self.Physics.HRP.CFrame:ToWorldSpace(cameraOffset)
		camera.Focus = self.Physics.HRP.CFrame:ToWorldSpace(focusOffset)
	end

	if teleportCF then
		local offset = self.Physics.Floor.CFrame:ToObjectSpace(self.Physics.HRP.CFrame)
		ReplicatePhysics:FireServer(self.Part, offset, true, false)
		self._replicateTick = os.clock()
	end

	self.Changed:Fire(oldPart, oldNormal, part, normal)
end

function WallstickClass:Destroy()
	print("wallstick controller is being destroyed and cleaning up") 
	self.Humanoid.PlatformStand = false
	setCollisionGroupId(self.Character:GetChildren(), 0)
	RunService:UnbindFromRenderStep("WallstickStep")
	ReplicatePhysics:FireServer(nil, nil, nil, true)
	SetCollidable:FireServer(true)
	self.Maid:Sweep()
end

WallstickModule.TypeDefs = typeDefs
typeDefs.WallstickClass = VOID :: WallstickClass
typeDefs.WallstickState = VOID :: WallstickState
typeDefs.WallstickInstance = VOID :: WallstickInstance
typeDefs.WallstickModule = VOID :: WallstickModule

export type WallstickState = typeof(typeDefs.WallstickState)
export type WallstickClass = typeof(WallstickClass)
export type WallstickInstance = WallstickState & WallstickClass -- typeof(WallstickModule.new(VOID :: Player))
export type WallstickModule = typeof(WallstickModule)

return WallstickModule