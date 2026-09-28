local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local ViewsFolder = PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Views")

local HotbarView = require(ViewsFolder:WaitForChild("HotbarView"))
local InventoryView = require(ViewsFolder:WaitForChild("InventoryView"))

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

local function disableRobloxBackpack()
	local success = false
	local attempts = 0
	while not success and attempts < 15 do
		success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if not success then
			task.wait(0.2)
			attempts += 1
		end
	end
end

function InventoryController:KnitStart()
	self.Hotbar = nil
	self.Inventory = nil
	self.IsMounted = false
	self.EquippedSlot = nil
	self.CurrentInventoryData = nil

	task.spawn(disableRobloxBackpack)
	self:MountUI()
end

function InventoryController:UnequipCurrentItem()
	if self.EquippedSlot then
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		self.EquippedSlot = nil
		if self.Hotbar then
			self.Hotbar:HighlightSlot(0)
		end
	end
end

function InventoryController:MountUI()
	if self.IsMounted then return end

	task.spawn(disableRobloxBackpack)

	self.Hotbar = HotbarView.new()
	self.Inventory = InventoryView.new(24)
	self.IsMounted = true

	if self.Hotbar and self.Hotbar.ScreenGui then
		self.Hotbar.ScreenGui.ResetOnSpawn = false
	end
	if self.Inventory and self.Inventory.ScreenGui then
		self.Inventory.ScreenGui.ResetOnSpawn = false
	end

	-- 1. Guardar ítem de Hotbar a Mochila
	if self.Hotbar and self.Hotbar.OnStoreRequested then
		self.Hotbar.OnStoreRequested.Event:Connect(function(hotbarSlotIndex: number)
			if self.EquippedSlot == hotbarSlotIndex then
				self:UnequipCurrentItem()
			end

			local InventoryService = Knit.GetService("InventoryService")
			InventoryService:StoreHotbarItem(hotbarSlotIndex):andThen(function(success)
				if success then
					print(`📦 [InventoryController] Objeto en casilla {hotbarSlotIndex} guardado en la mochila.`)
				end
			end):catch(warn)
		end)
	end

	-- 2. Botón "Usar/Equipar" en la Mochila -> Mover al primer slot libre de la Hotbar ⚡
	if self.Inventory and self.Inventory.OnItemAction then
		self.Inventory.OnItemAction.Event:Connect(function(actionName: string, fromRealSlot: number, itemData: table)
			if actionName == "Use" then
				local freeHotbarSlot = self:GetFirstFreeHotbarSlot()

				if freeHotbarSlot then
					print(`🎒 Moviendo ítem de la mochila (slot {fromRealSlot}) al espacio libre de Hotbar ({freeHotbarSlot})`)
					local InventoryService = Knit.GetService("InventoryService")
					InventoryService:MoveItem(fromRealSlot, freeHotbarSlot):catch(warn)
				else
					warn("⚠️ [Hotbar Llena] No hay espacios libres en la barra de acceso rápido.")
				end
			end
		end)
	end

	-- 3. Mover objetos (Drag & Drop)
	if self.Inventory and self.Inventory.OnItemDropped then
		self.Inventory.OnItemDropped.Event:Connect(function(realFromSlot: number, realToSlot: number)
			if self.EquippedSlot == realFromSlot or self.EquippedSlot == realToSlot then
				self:UnequipCurrentItem()
			end

			local InventoryService = Knit.GetService("InventoryService")
			InventoryService:MoveItem(realFromSlot, realToSlot):catch(warn)
		end)
	end

	-- 4. Equipar al hacer clic en Hotbar
	if self.Hotbar and self.Hotbar.OnSlotSelected then
		self.Hotbar.OnSlotSelected.Event:Connect(function(slotIndex)
			self:EquipSlotItem(slotIndex)
		end)
	end

	-- 5. Teclas de acceso rápido (1-5 y E/I)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.I then
			if self.Inventory then
				self.Inventory:Toggle()
			end
		end

		local keyMap = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
			[Enum.KeyCode.Five] = 5,
		}

		local slot = keyMap[input.KeyCode]
		if slot then
			self:EquipSlotItem(slot)
		end
	end)

	-- 6. Sincronización con el servidor
	local InventoryService = Knit.GetService("InventoryService")

	InventoryService.InventoryUpdated:Connect(function(data)
		self:UpdateInventoryData(data)
	end)

	InventoryService:GetInventoryData():andThen(function(initialData)
		if initialData then
			self:UpdateInventoryData(initialData)
		end
	end):catch(warn)

	print("🎒 [InventoryController] UI montada e inventario sincronizado.")
end

function InventoryController:GetFirstFreeHotbarSlot(): number?
	if not self.CurrentInventoryData or not self.CurrentInventoryData.Hotbar then
		return 1
	end

	for slotIndex = 1, 5 do
		local slotData = self.CurrentInventoryData.Hotbar[slotIndex]
		if not slotData or not slotData.Name or slotData.Name == "" then
			return slotIndex
		end
	end

	return nil
end

function InventoryController:EquipSlotItem(slotIndex: number)
	if not self.Hotbar or not self.Hotbar.Slots[slotIndex] then return end

	local slot = self.Hotbar.Slots[slotIndex]
	local slotData = slot.Data
	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if self.EquippedSlot == slotIndex then
		self:UnequipCurrentItem()
		return
	end

	if not slotData or not slotData.Name then
		self:UnequipCurrentItem()
		return
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local tool = nil

	if backpack then
		tool = backpack:FindFirstChild(slotData.Name)
	end
	if not tool then
		tool = character:FindFirstChild(slotData.Name)
	end

	if tool and tool:IsA("Tool") then
		self:UnequipCurrentItem()
		self.EquippedSlot = slotIndex
		self.Hotbar:HighlightSlot(slotIndex)
		humanoid:EquipTool(tool)
	else
		warn(`🎒 [InventoryController] No se encontró la herramienta física '{slotData.Name}'.`)
	end
end

function InventoryController:UpdateInventoryData(inventoryData)
	if not inventoryData then return end

	self.CurrentInventoryData = inventoryData

	if self.Inventory and inventoryData.Items then
		self.Inventory:SetItems(inventoryData.Items)
	end

	if self.Hotbar and inventoryData.Hotbar then
		self.Hotbar:SetHotbarData(inventoryData.Hotbar)
	end
end

return InventoryController