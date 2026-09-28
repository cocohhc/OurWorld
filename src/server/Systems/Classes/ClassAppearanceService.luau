local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Esperamos a que los componentes del sistema Classes existan en ReplicatedStorage
local sharedClasses = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("Systems")
	:WaitForChild("Classes")

local PersonalityData = require(sharedClasses:WaitForChild("PersonalityData"))
local ClassAppearanceService = {}
function ClassAppearanceService:ApplyAppearance(character: Model, className: string, subtype: string?)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- 1. Limpiar ropa y accesorios previos del avatar del jugador
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Clothing") or child:IsA("Accessory") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end

	-- 2. Cambiar color base/material según la clase
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso then
		if className == "Warrior" then
			torso.Color = Color3.fromRGB(180, 50, 50) -- Rojo Guerrero
		elseif className == "Mage" then
			torso.Color = Color3.fromRGB(120, 50, 200) -- Morado Mago
		elseif className == "Giant" then
			torso.Color = Color3.fromRGB(80, 100, 110) -- Gris Piedra
		end
	end

	-- 3. Cargar accesorios predefinidos desde ReplicatedStorage (si existen en Assets)
	local classAssets = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("ClassAppearances")
	if classAssets and classAssets:FindFirstChild(className) then
		local appearanceData = classAssets[className]
		for _, item in ipairs(appearanceData:GetChildren()) do
			local clone = item:Clone()
			if clone:IsA("Accessory") then
				humanoid:AddAccessory(clone)
			else
				clone.Parent = character
			end
		end
	end
end

return ClassAppearanceService