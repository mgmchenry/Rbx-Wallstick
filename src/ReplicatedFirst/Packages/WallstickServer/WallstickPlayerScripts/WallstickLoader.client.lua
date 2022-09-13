--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local WallstickClient = ReplicatedFirst:WaitForChild("Packages"):WaitForChild("WallstickClient")
local WallstickPlayerscript = WallstickClient:WaitForChild("WallstickPlayerscript")

require(WallstickPlayerscript)