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
	print("[InventoryService] Servicio de inventario iniciado.")
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
		local slotIndex = tonumber(slotKey) or slotKey
		local itemId = typeof(rawItem) == "table" and rawItem.Id or rawItem
		local baseConfig = ItemData.Items[itemId]

		if baseConfig and slotIndex then
			local fullItem = typeof(rawItem) == "table" and table.clone(rawItem) or {}
			for k, v in pairs(baseConfig) do
				if fullItem[k] == nil then
					fullItem[k] = v
				end
			end

			fullItem.Icon = fullItem.Icon or fullItem.Texture or fullItem.Image or ""
			fullItem.SlotIndex = slotIndex

			if slotIndex <= 5 then
				hotbarData[slotIndex] = fullItem
			else
				inventoryItemsData[slotIndex - 5] = fullItem
			end
		end
	end

	return {
		Items = inventoryItemsData,
		Hotbar = hotbarData,
	}
end

function InventoryService:AddItem(player: Player, itemId: string): boolean
	local itemConfig = ItemData.Items[itemId]

	if not itemConfig then
		warn(`[InventoryService] El ítem '{itemId}' no existe en ItemData.`)
		return false
	end

	local PlayerDataManager = self:GetPlayerDataManager()
	if PlayerDataManager then
		local rawInventory = self:GetRawInventory(player)

		local alreadyOwned = false
		for _, existingItem in pairs(rawInventory) do
			local idToCheck = typeof(existingItem) == "table" and existingItem.Id or existingItem
			if idToCheck == itemId then
				alreadyOwned = true
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
			end
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local toolExists = false

	if backpack and backpack:FindFirstChild(itemConfig.Name) then
		toolExists = true
	elseif character and character:FindFirstChild(itemConfig.Name) then
		toolExists = true
	end

	if backpack and not toolExists then
		local tool = createPhysicalTool(itemConfig)
		tool.Parent = backpack
	end

	local formattedData = self:GetFormattedInventory(player)
	self.Client.InventoryUpdated:Fire(player, formattedData)

	print(`🎒 [INVENTARIO] {itemConfig.Name} verificado/sincronizado para {player.Name}`)
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

function InventoryService.Client:MoveItem(player: Player, fromSlot: number, toSlot: number)
	local PlayerDataManager = self.Server:GetPlayerDataManager()
	if PlayerDataManager then
		local rawInventory = self.Server:GetRawInventory(player)
		local fromKey = tostring(fromSlot)
		local toKey = tostring(toSlot)

		local itemAtFrom = rawInventory[fromKey] or rawInventory[fromSlot]
		local itemAtTo = rawInventory[toKey] or rawInventory[toSlot]

		rawInventory[fromKey] = itemAtTo
		rawInventory[fromSlot] = nil
		rawInventory[toKey] = itemAtFrom
		rawInventory[toSlot] = nil

		local formattedData = self.Server:GetFormattedInventory(player)
		self.Server.Client.InventoryUpdated:Fire(player, formattedData)
		return true
	end
	return false
end

function InventoryService.Client:GetInventoryData(player: Player)
	return self.Server:GetFormattedInventory(player)
end

return InventoryService