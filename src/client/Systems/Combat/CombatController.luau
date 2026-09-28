local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- RUTA NUEVA (Sistema Inventory dentro de Shared):
local sharedInventory = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("Systems")
	:WaitForChild("Inventory")

local ItemData = require(sharedInventory:WaitForChild("ItemData"))
local LocalPlayer = Players.LocalPlayer

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

function CombatController:KnitStart()
	print("[CombatController] Controlador de combate cargado.")

	-- Detectar clics del mouse / toques
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:TryAttack()
		end
	end)
end

function CombatController:TryAttack()
	local character = LocalPlayer.Character
	if not character then return end

	-- Obtener la herramienta equipada actualmente en la mano
	local equippedTool = character:FindFirstChildOfClass("Tool")
	if not equippedTool then return end

	-- Buscar el ID correspondiente en ItemData a partir del nombre
	local weaponId = nil
	for id, item in pairs(ItemData.Items) do
		if item.Name == equippedTool.Name then
			weaponId = id
			break
		end
	end

	if weaponId then
		local CombatService = Knit.GetService("CombatService")
		CombatService.AttackRequested:Fire(weaponId)
	end
end

return CombatController
