--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PackageConfig = require(script:WaitForChild("PackageConfig"))

local void = nil :: any

--export type ConfigData = typeof(script.WallstickConfig)
--local configDef:ConfigData = script:FindFirstChild("WallstickConfig") 

type ConfigDefinition = typeof(script:FindFirstChild("WallstickConfig"))
local config:ConfigDefinition = script:WaitForChild("WallstickConfig")

local TypedFinder = PackageConfig
.Create(config)

--TypedFinder = TypedFinder
--:Wait(function(find:Configuration) return find:WaitForChild("WallstickConfig") end)

local TypedConfig = TypedFinder:Init()
local propInfo = {
	ConfigParent = TypedConfig:ValueGetter_Instance(config:FindFirstChild("WallstickConfigParent"), ReplicatedStorage),
	RemoteParent = TypedConfig:ValueGetter_Instance(config:FindFirstChild("WallstickRemoteParent"), ReplicatedStorage)
}

local get = {
	ConfigParent = propInfo.ConfigParent.GetValue,
	RemoteParent = propInfo.RemoteParent.GetValue
}

local function updateValues(inTable)
	local values = {}
	if inTable then values=inTable end
	values.ConfigParent = get.ConfigParent()
	values.RemoteParent = get.RemoteParent()
	return values
end
local values = updateValues(void)

if values.ConfigParent~=TypedConfig.CurrentConfig then
	local deployConfig:ConfigDefinition = values.ConfigParent:FindFirstChild(config.Name)
	if deployConfig==nil then
		if game:GetService("RunService"):IsServer() then
			deployConfig = config:Clone()
			deployConfig.Parent = values.ConfigParent
			TypedConfig:Init(deployConfig)
			updateValues(values)
		else
			deployConfig = values.ConfigParent:WaitForChild(config.Name)
			TypedConfig:Init(deployConfig)
			updateValues(values)
		end
	end
end

local WallstickConfig = {} --setmetatable({}, TypedConfig)
WallstickConfig.__index = WallstickConfig




WallstickConfig.Get = get

--TypedConfig.
--WallstickConfig

local ConfigData = script:WaitForChild("WallstickConfig")

--type WallstickConfig = typeof(WallstickConfig) & typeof(TypedConfig)

return WallstickConfig
