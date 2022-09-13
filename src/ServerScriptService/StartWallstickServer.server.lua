local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerPackages = ReplicatedFirst:FindFirstChild("Packages")
local WallstickServer = require(ServerPackages:FindFirstChild("WallstickServer"))

WallstickServer.Start()