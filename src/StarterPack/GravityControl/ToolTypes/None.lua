local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WallstickClass = require(--ReplicatedStorage:WaitForChild("Wallstick"))
	game:GetService("ReplicatedFirst")
	:WaitForChild("Packages")
	:WaitForChild("WallstickClient")
)
local wallstick = nil

local module = {}

module.Name = script.Name

function module.equip()
	wallstick = WallstickClass.new(Players.LocalPlayer)
end

function module.unequip()
	wallstick:Destroy()
end

return module