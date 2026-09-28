local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- 1. Referencia segura a la carpeta compartida del sistema Classes
local sharedClasses = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Classes")

-- 2. Carga de módulos y datos
local ClassData = require(sharedClasses:WaitForChild("ClassData"))

local ClassService = Knit.CreateService({
	Name = "ClassService",
	Client = {},
})

function ClassService:KnitStart()
	-- Importación del servicio de apariencia
	self.ClassAppearanceService = require(script.Parent.ClassAppearanceService)
	print("[ClassService] Servicio inicializado correctamente.")
end

-- Exponer obtención de ranuras/personajes al cliente
function ClassService.Client:GetCharacterSlots(player: Player)
	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	return PlayerDataManager:GetSlots(player)
end

-- Carga un personaje existente guardado y le aplica la skin y animaciones
function ClassService.Client:SelectCharacter(player: Player, slotId: string)
	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	local slot = PlayerDataManager:SelectSlot(player, slotId)
	if not slot then return false end

	-- 1. Aplicar la apariencia visual y la personalidad al personaje real en Workspace
	if player.Character then
		self.Server.ClassAppearanceService:ApplyAppearance(player.Character, slot.Class, slot.Subtype)
		if slot.Personality then
			self.Server.ClassAppearanceService:ApplyPersonalityAnimations(player.Character, slot.Personality)
		end
	end

	-- 2. Otorgar ítems/arma del personaje seleccionado
	local InventoryService = Knit.GetService("InventoryService")
	local classInfo = ClassData.Classes[slot.Class]
	if classInfo and InventoryService then
		local itemId = classInfo.DefaultItemId
		if slot.Class == "Warrior" and slot.Subtype ~= "" and classInfo.Subtypes[slot.Subtype] then
			itemId = classInfo.Subtypes[slot.Subtype].DefaultItemId
		end
		InventoryService:AddItem(player, itemId)
	end

	print(`[ClassService] Skin, personalidad y datos aplicados para {player.Name} ({slot.Name})`)
	return true
end

-- Crea un personaje nuevo, guarda la ranura y le aplica la skin y animaciones
function ClassService.Client:CreateCharacter(player: Player, className: string, subtype: string?, charName: string, personalityKey: string?)
	local classInfo = ClassData.Classes[className]
	if not classInfo then return false end

	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	local slot = PlayerDataManager:CreateCharacterSlot(player, className, subtype, charName, personalityKey)
	if not slot then return false end

	-- 1. Aplicar la apariencia y personalidad al personaje real en Workspace
	if player.Character then
		self.Server.ClassAppearanceService:ApplyAppearance(player.Character, className, subtype)
		if slot.Personality then
			self.Server.ClassAppearanceService:ApplyPersonalityAnimations(player.Character, slot.Personality)
		end
	end

	-- 2. Entregar arma inicial al inventario
	local itemIdToGive = classInfo.DefaultItemId
	if className == "Warrior" and subtype and classInfo.Subtypes and classInfo.Subtypes[subtype] then
		itemIdToGive = classInfo.Subtypes[subtype].DefaultItemId
	end

	local InventoryService = Knit.GetService("InventoryService")
	if InventoryService and itemIdToGive then
		InventoryService:AddItem(player, itemIdToGive)
	end

	print(`[ClassService] Nuevo personaje creado ({charName} - {className}) con personalidad: {slot.Personality}`)
	return true
end

return ClassService