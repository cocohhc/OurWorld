local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local systemsFolder = PlayerScripts:WaitForChild("Client"):WaitForChild("Systems")

for _, systemFolder in ipairs(systemsFolder:GetChildren()) do
	for _, module in ipairs(systemFolder:GetChildren()) do
		if module:IsA("ModuleScript") and module.Name:find("Controller$") then
			require(module)
		end
	end
end

Knit.Start():catch(warn)