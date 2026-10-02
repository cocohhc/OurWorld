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
	Client = {
		ClassSelected = Knit.CreateSignal(), -- Signal requerida por MenuController
	},
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

	-- 1. Forzar la aparición física del personaje en el juego
	player:LoadCharacter()

	-- 2. Aplicar apariencia y personalidad al modelo recién instanciado
	if player.Character then
		self.Server.ClassAppearanceService:ApplyAppearance(player.Character, slot.Class, slot.Subtype)
		if slot.Personality and typeof(self.Server.ClassAppearanceService.ApplyPersonalityAnimations) == "function" then
			self.Server.ClassAppearanceService:ApplyPersonalityAnimations(player.Character, slot.Personality)
		end
	end

	-- 3. Entregar ítems e inventario
	local InventoryService = Knit.GetService("InventoryService")
	local classInfo = ClassData.Classes[slot.Class]
	if classInfo and InventoryService then
		local itemId = classInfo.DefaultItemId
		if slot.Class == "Warrior" and slot.Subtype ~= "" and classInfo.Subtypes[slot.Subtype] then
			itemId = classInfo.Subtypes[slot.Subtype].DefaultItemId
		end
		InventoryService:AddItem(player, itemId)
	end

	-- Notificar a los controladores del cliente (ej. MenuController)
	self.ClassSelected:Fire(player, slot)

	print(`[ClassService] Personaje cargado manualmente para {player.Name}`)
	return true
end

-- Crea un personaje nuevo, guarda la ranura y le aplica la skin y animaciones
function ClassService.Client:CreateCharacter(player: Player, className: string, subtype: string?, charName: string, personalityKey: string?)
	local classInfo = ClassData.Classes[className]
	if not classInfo then return false end

	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	local slot = PlayerDataManager:CreateCharacterSlot(player, className, subtype, charName, personalityKey)
	if not slot then return false end

	-- 1. Forzar la aparición física del personaje
	player:LoadCharacter()

	-- 2. Aplicar la apariencia y personalidad
	if player.Character then
		self.Server.ClassAppearanceService:ApplyAppearance(player.Character, className, subtype)
		if slot.Personality and typeof(self.Server.ClassAppearanceService.ApplyPersonalityAnimations) == "function" then
			self.Server.ClassAppearanceService:ApplyPersonalityAnimations(player.Character, slot.Personality)
		end
	end

	-- 3. Entregar arma inicial
	local itemIdToGive = classInfo.DefaultItemId
	if className == "Warrior" and subtype and classInfo.Subtypes and classInfo.Subtypes[subtype] then
		itemIdToGive = classInfo.Subtypes[subtype].DefaultItemId
	end

	local InventoryService = Knit.GetService("InventoryService")
	if InventoryService and itemIdToGive then
		InventoryService:AddItem(player, itemIdToGive)
	end

	-- Notificar a los controladores del cliente (ej. MenuController)
	self.ClassSelected:Fire(player, slot)

	print(`[ClassService] Nuevo personaje instanciado para {player.Name}`)
	return true
end

-- Pone en reposo los sistemas del servidor y desvincula el personaje activo del jugador
function ClassService:DeselectCharacter(player: Player): boolean
	print(`🚪 [ClassService] Poniendo en reposo y deseleccionando personaje para: {player.Name}`)

	-- 1. Resetear la ranura activa en PlayerDataManager
	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	if PlayerDataManager then
		if typeof(PlayerDataManager.DeselectSlot) == "function" then
			PlayerDataManager:DeselectSlot(player)
		elseif typeof(PlayerDataManager.SetActiveSlot) == "function" then
			PlayerDataManager:SetActiveSlot(player, nil)
		end
	end

	-- 2. Limpiar herramientas físicas en Backpack y Personaje
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") then
				item:Destroy()
			end
		end
		-- 3. Remover el modelo del personaje del mundo
		player.Character:Destroy()
		player.Character = nil
	end

	print(`✅ [ClassService] Sistemas en el servidor puestos en reposo para {player.Name}.`)
	return true
end

-- Método expuesto en la API cliente
function ClassService.Client:DeselectCharacter(player: Player): boolean
	return self.Server:DeselectCharacter(player)
end

return ClassService
