local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local sharedInventory = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Inventory")
local ItemData = require(sharedInventory:WaitForChild("ItemData"))

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {
		InventoryUpdated = Knit.CreateSignal(),
	},
})

local function createPhysicalTool(itemConfig)
	local tool = Instance.new("Tool")
	tool.Name = itemConfig.Name or "Objeto"
	tool.ToolTip = itemConfig.Description or ""

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 4, 1)
	handle.Transparency = 0.5

	if itemConfig.WeaponType == "Sword" then
		handle.Color = Color3.fromRGB(180, 180, 200)
	elseif itemConfig.WeaponType == "Bow" then
		handle.Color = Color3.fromRGB(139, 69, 19)
	elseif itemConfig.WeaponType == "Staff" then
		handle.Color = Color3.fromRGB(138, 43, 226)
	elseif itemConfig.WeaponType == "Hammer" then
		handle.Color = Color3.fromRGB(100, 100, 100)
		handle.Size = Vector3.new(2, 5, 2)
	end

	handle.Parent = tool
	return tool
end

function InventoryService:KnitStart()
    print("🟢 [InventoryService] Servicio iniciado e integraciones de Knit listas.")
end

function InventoryService:GetPlayerDataManager()
	return Knit.GetService("PlayerDataManager")
end

function InventoryService:GetRawInventory(player: Player)
	local PlayerDataManager = self:GetPlayerDataManager()
	if PlayerDataManager then
		local activeSlot = PlayerDataManager:GetActiveSlot(player)
		if activeSlot and activeSlot.Inventory then
			return activeSlot.Inventory
		end
	end
	return {}
end

function InventoryService:GetFormattedInventory(player: Player)
	local rawItems = self:GetRawInventory(player)

	local hotbarData = {}
	local inventoryItemsData = {}

	for slotKey, rawItem in pairs(rawItems) do
		local slotIndex = tonumber(slotKey)
		if not slotIndex or not rawItem then continue end

		-- Extraer la ID real del ítem buscando fallback en Id, Name o en la string direct
		local itemId = nil
		if typeof(rawItem) == "table" then
			itemId = rawItem.Id or rawItem.Name
		elseif typeof(rawItem) == "string" then
			itemId = rawItem
		end

		if not itemId then
			warn(`⚠️ [InventoryService] No se pudo determinar itemId para slot {slotKey}:`, rawItem)
			continue
		end

		local baseConfig = ItemData.Items[itemId]

		-- Si no se encuentra coincidencia exacta en ItemData.Items, intentar fallback iterativo
		if not baseConfig then
			for possibleId, config in pairs(ItemData.Items) do
				if possibleId == itemId or config.Name == itemId then
					baseConfig = config
					itemId = possibleId
					break
				end
			end
		end

		if baseConfig then
			local fullItem = if typeof(rawItem) == "table" then table.clone(rawItem) else {}
			for k, v in pairs(baseConfig) do
				if fullItem[k] == nil then
					fullItem[k] = v
				end
			end

			fullItem.Id = itemId
			fullItem.Icon = fullItem.Icon or fullItem.Texture or fullItem.Image or ""
			fullItem.SlotIndex = slotIndex

			if slotIndex <= 5 then
				hotbarData[slotIndex] = fullItem
			else
				inventoryItemsData[slotIndex - 5] = fullItem
			end
		else
			warn(`⚠️ [InventoryService] No existe configuración en ItemData.Items para itemId: '{tostring(itemId)}'`)
		end
	end

	return {
		Items = inventoryItemsData,
		Hotbar = hotbarData,
	}
end

function InventoryService:AddItem(player: Player, itemId: string): boolean
	print(`🔍 [InventoryService] Intentando añadir ítem '{itemId}' a {player.Name}...`)

	local itemConfig = ItemData.Items[itemId]
	if not itemConfig then
		warn(`❌ [InventoryService] El ítem '{itemId}' NO existe en ItemData.`)
		return false
	end

	local PlayerDataManager = self:GetPlayerDataManager()
	if not PlayerDataManager then
		warn(`❌ [InventoryService] PlayerDataManager no estuvo disponible al añadir '{itemId}'.`)
		return false
	end

	local rawInventory = self:GetRawInventory(player)
	print(`📦 [InventoryService] Estado actual del inventario raw de {player.Name}:`, rawInventory)

	local alreadyOwned = false
	for slot, existingItem in pairs(rawInventory) do
		local idToCheck = typeof(existingItem) == "table" and existingItem.Id or existingItem
		if idToCheck == itemId then
			alreadyOwned = true
			print(`ℹ️ [InventoryService] El ítem '{itemId}' ya existe en el slot {slot}.`)
			break
		end
	end

	if not alreadyOwned then
		local targetSlot = nil
		for i = 1, 29 do
			if rawInventory[tostring(i)] == nil and rawInventory[i] == nil then
				targetSlot = i
				break
			end
		end

		if targetSlot then
			rawInventory[tostring(targetSlot)] = itemId
			print(`✅ [InventoryService] Ítem '{itemId}' asignado al slot {targetSlot} en la estructura de datos.`)
		else
			warn(`⚠ [InventoryService] Inventario lleno para {player.Name}.`)
			return false
		end
	end

	-- Verificación de la Tool física y el Backpack
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	print(`👤 [InventoryService] Estado del jugador -> Backpack: {backpack ~= nil}, Character: {character ~= nil}`)

	if backpack then
		local toolExists = backpack:FindFirstChild(itemConfig.Name) or (character and character:FindFirstChild(itemConfig.Name))
		if not toolExists then
			local tool = createPhysicalTool(itemConfig)
			tool.Parent = backpack
			print(`🗡️ [InventoryService] Tool física '{itemConfig.Name}' creada y colocada en el Backpack de {player.Name}.`)
		else
			print(`ℹ️ [InventoryService] La Tool física '{itemConfig.Name}' ya existe en el Backpack/Character.`)
		end
	else
		warn(`⚠️️ [InventoryService] {player.Name} NO tiene Backpack disponible en este momento. La Tool física no se pudo instanciar.`)
	end

	-- Notificar SIEMPRE al cliente sobre el estado del inventario formateado
	local formattedData = self:GetFormattedInventory(player)
	print(`📡 [InventoryService] Emitiendo 'InventoryUpdated' a {player.Name} con la siguiente data:`, formattedData)
	self.Client.InventoryUpdated:Fire(player, formattedData)

	return true
end

-- 📥 Mover ítem de la Hotbar (1-5) hacia la Mochila (6 en adelante)
function InventoryService.Client:StoreHotbarItem(player: Player, hotbarSlot: number)
	local PlayerDataManager = self.Server:GetPlayerDataManager()
	if PlayerDataManager then
		local rawInventory = self.Server:GetRawInventory(player)
		local hotbarKey = tostring(hotbarSlot)

		local itemToStore = rawInventory[hotbarKey] or rawInventory[hotbarSlot]
		if not itemToStore then
			return false
		end

		-- Buscar la primera casilla libre en la mochila (slots 6 a 29)
		local targetSlot = nil
		for i = 6, 29 do
			local key = tostring(i)
			if rawInventory[key] == nil and rawInventory[i] == nil then
				targetSlot = i
				break
			end
		end

		if targetSlot then
			-- Mover el ítem al inventario general y vaciar la hotbar
			rawInventory[tostring(targetSlot)] = itemToStore
			rawInventory[hotbarKey] = nil
			rawInventory[hotbarSlot] = nil

			local formattedData = self.Server:GetFormattedInventory(player)
			self.Server.Client.InventoryUpdated:Fire(player, formattedData)
			print(`📦 [HOTBAR] Ítem de la casilla {hotbarSlot} guardado en el slot {targetSlot}`)
			return true
		else
			warn("⚠️ [HOTBAR] No hay espacio libre en la mochila para guardar el objeto.")
		end
	end
	return false
end

-- src/server/Systems/Inventory/InventoryService.luau

function InventoryService.Client:MoveItem(player: Player, fromSlot: number, toSlot: number)
	print(`🔄 [SERVER:MoveItem] Petición de mover slot {fromSlot} -> slot {toSlot} por {player.Name}`)

	if typeof(fromSlot) ~= "number" or typeof(toSlot) ~= "number" or fromSlot <= 0 or toSlot <= 0 or fromSlot == toSlot then
		return {}
	end

	local PlayerDataManager = self.Server:GetPlayerDataManager()
	if PlayerDataManager then
		local rawInventory = self.Server:GetRawInventory(player)
		local fromStr = tostring(fromSlot)
		local toStr = tostring(toSlot)

		-- Buscar ítem considerando clave string y numérica
		local itemAtFrom = rawInventory[fromStr] or rawInventory[fromSlot]
		local itemAtTo = rawInventory[toStr] or rawInventory[toSlot]

		print(`📦 [SERVER:MoveItem] Estado origen ({fromSlot}):`, itemAtFrom, `| Estado destino ({toSlot}):`, itemAtTo)

		-- Limpiar ambas representaciones en las casillas
		rawInventory[fromStr] = nil
		rawInventory[fromSlot] = nil
		rawInventory[toStr] = nil
		rawInventory[toSlot] = nil

		-- Asignar los ítems con clave tipo string estándar (intercambio correcto)
		if itemAtFrom then
			rawInventory[toStr] = itemAtFrom
		end
		if itemAtTo then
			rawInventory[fromStr] = itemAtTo
		end

		print(`✅ [SERVER:MoveItem] Movidas completadas. Generando inventario formateado...`)
		local formattedData = self.Server:GetFormattedInventory(player)

		print(`📡 [SERVER:MoveItem] Emitiendo InventoryUpdated a {player.Name}:`, formattedData)
		self.Server.Client.InventoryUpdated:Fire(player, formattedData)
		return formattedData
	end
	return {}
end

function InventoryService.Client:GetInventory(player: Player)
	return self.Server:GetFormattedInventory(player)
end

function InventoryService.Client:EquipItem(player: Player, slotIndex: number)
	local formattedData = self.Server:GetFormattedInventory(player)
	local slotData = formattedData.Hotbar[slotIndex] or formattedData.Items[slotIndex - 5]

	if not slotData or not slotData.Name then
		return false
	end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then return false end

	local tool = backpack:FindFirstChild(slotData.Name) or character:FindFirstChild(slotData.Name)

	-- Si la Tool física aún no existe en el cliente/servidor, la instanciamos
	if not tool then
		tool = createPhysicalTool(slotData)
		tool.Parent = backpack
	end

	if tool then
		humanoid:EquipTool(tool)
		return true
	end

	return false
end

return InventoryService
