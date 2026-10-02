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
	print("🟢 [InventoryController] Iniciando controlador del cliente...")

	local InventoryService = Knit.GetService("InventoryService")

	-- 1. Montar las interfaces (se crean en memoria)
	self:MountUI()

	-- 2. Escuchar teclado (E, B, I para Mochila y 1..5 para Equipar Slots)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Alternar mochila
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
			self:ToggleInventory()
			return
		end

		-- Equipar slots de la Hotbar (1 al 5)
		local slotKeyMap = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
			[Enum.KeyCode.Five] = 5,
		}

		local selectedSlot = slotKeyMap[input.KeyCode]
		if selectedSlot then
			self:EquipSlotItem(selectedSlot)
		end
	end)

	-- 3. Conectar Click directo en las casillas de la HotbarView
	if self.Hotbar and self.Hotbar.OnSlotSelected then
		self.Hotbar.OnSlotSelected.Event:Connect(function(slotIndex: number)
			self:EquipSlotItem(slotIndex)
		end)
	end

	-- 4. Escuchar actualizaciones enviadas desde el Servidor
	InventoryService.InventoryUpdated:Connect(function(inventoryData)
		print("📩 [InventoryController] Evento 'InventoryUpdated' RECIBIDO desde el servidor:")
		self:UpdateInventoryData(inventoryData)
	end)

	-- 5. Cargar inventario inicial silenciosamente
	task.spawn(function()
		print("🔄 [InventoryController] Solicitando inventario inicial al servidor...")

		local success, initialData = InventoryService:GetInventory():await()

		if success and initialData then
			print("✅ [InventoryController] Inventario inicial recibido con éxito.")
			self:UpdateInventoryData(initialData)
		else
			warn("❌ [InventoryController] No se pudo obtener el inventario inicial del servidor. Error:", initialData)
		end
	end)

	-- 6. Sincronización en tiempo real de XP y Radiación
	self:SetupStatsListeners()
end

function InventoryController:ToggleInventory()
	-- Asegurar que la UI esté montada si aún no lo está
	if not self.IsMounted then
		self:MountUI()
	end

	if not self.Inventory or not self.Inventory.ScreenGui then
		warn("⚠️ [InventoryController] No se encontró la vista o ScreenGui de la mochila.")
		return
	end

	local screenGui = self.Inventory.ScreenGui

	-- Garantizar que esté emparentado al PlayerGui
	if screenGui.Parent ~= LocalPlayer:WaitForChild("PlayerGui") then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Alternar visibilidad
	local newState = not screenGui.Enabled
	screenGui.Enabled = newState

	-- Forzar visibilidad del contenedor principal interno si existe
	local mainContainer = screenGui:FindFirstChildWhichIsA("Frame") or screenGui:FindFirstChildOfClass("CanvasGroup")
	if mainContainer then
		mainContainer.Visible = newState
	end

end

function InventoryController:ShowHotbar()
	if self.Hotbar then
		if typeof(self.Hotbar.SetVisible) == "function" then
			self.Hotbar:SetVisible(true)
		end
		if self.Hotbar.ScreenGui then
			self.Hotbar.ScreenGui.Enabled = true
		end
	end

	-- Actualización inmediata de las barras de estado (XP y Radiación)
	local currentXP = LocalPlayer:GetAttribute("XP") or 0
	local maxXP = LocalPlayer:GetAttribute("MaxXP") or 100
	local currentRadiation = LocalPlayer:GetAttribute("Radiation") or 0
	local maxRadiation = LocalPlayer:GetAttribute("MaxRadiation") or 100

	if self.Hotbar then
		if typeof(self.Hotbar.UpdateXP) == "function" then
			self.Hotbar:UpdateXP(currentXP, maxXP)
		end
		if typeof(self.Hotbar.UpdateRadiation) == "function" then
			self.Hotbar:UpdateRadiation(currentRadiation, maxRadiation)
		end
	end

	-- 🎒 Solicitar datos del inventario usando la API pública de cliente de Knit
	local InventoryService = Knit.GetService("InventoryService")
	if InventoryService then
		local getInventoryFn = InventoryService.GetInventory or InventoryService.GetInventoryClient
		if typeof(getInventoryFn) == "function" then
			getInventoryFn(InventoryService):andThen(function(inventoryData)
				if type(inventoryData) == "table" then
					self:UpdateInventoryData(inventoryData)
				end
			end):catch(warn)
		end
	end
end

function InventoryController:SetupStatsListeners()
	local function updateXP()
		local currentXP = LocalPlayer:GetAttribute("XP") or 0
		local maxXP = LocalPlayer:GetAttribute("MaxXP") or 100
		if self.Hotbar and typeof(self.Hotbar.UpdateXP) == "function" then
			self.Hotbar:UpdateXP(currentXP, maxXP)
		end
	end

	local function updateRadiation(currentRad: number?, maxRad: number?)
		local currentRadiation = currentRad or LocalPlayer:GetAttribute("Radiation") or 0
		local maxRadiation = maxRad or LocalPlayer:GetAttribute("MaxRadiation") or 100

		if self.Hotbar and typeof(self.Hotbar.UpdateRadiation) == "function" then
			self.Hotbar:UpdateRadiation(currentRadiation, maxRadiation)
		end
	end

	-- 1. Escuchar cambios de atributos en el personaje
	LocalPlayer:GetAttributeChangedSignal("XP"):Connect(updateXP)
	LocalPlayer:GetAttributeChangedSignal("MaxXP"):Connect(updateXP)
	LocalPlayer:GetAttributeChangedSignal("Radiation"):Connect(function()
		updateRadiation()
	end)
	LocalPlayer:GetAttributeChangedSignal("MaxRadiation"):Connect(function()
		updateRadiation()
	end)

	-- 2. Escuchar actualización remota en tiempo real de CombatService
	task.spawn(function()
		local CombatService = Knit.GetService("CombatService")
		if CombatService and CombatService.RadiationUpdated then
			CombatService.RadiationUpdated:Connect(function(currentRad: number, maxRad: number)
				updateRadiation(currentRad, maxRad)
			end)
		end
	end)

	-- 3. Inicialización inmediata
	updateXP()
	updateRadiation()
end

function InventoryController:HideHotbar()
	if self.Hotbar then
		if typeof(self.Hotbar.SetVisible) == "function" then
			self.Hotbar:SetVisible(false)
		end
		if self.Hotbar.ScreenGui then
			self.Hotbar.ScreenGui.Enabled = false
		end
	end
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

	-- 🙈 Ocultar Hotbar e Inventario por defecto hasta que el jugador seleccione personaje
	if self.Hotbar and self.Hotbar.ScreenGui then
		self.Hotbar.ScreenGui.ResetOnSpawn = false
		self.Hotbar.ScreenGui.Enabled = false
	end

	if self.Inventory and self.Inventory.ScreenGui then
		self.Inventory.ScreenGui.ResetOnSpawn = false
		self.Inventory.ScreenGui.Enabled = false
	end

	-- 🔗 Enlazar Hotbar con la Mochila para Drag & Drop bidireccional
	if self.Inventory and self.Hotbar then
		self.Inventory:SetHotbarReference(self.Hotbar)
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

    -- 2. Botón "Usar/Equipar" en la Mochila -> Mover al primer slot libre de la Hotbar
	if self.Inventory and self.Inventory.OnItemAction then
		self.Inventory.OnItemAction.Event:Connect(function(actionName: string, fromRealSlot: number, itemData: table)
			if actionName == "Use" then
				local freeHotbarSlot = self:GetFirstFreeHotbarSlot()

				if freeHotbarSlot then
					-- Detectar slot global (si viene en itemData.SlotIndex o si fromRealSlot ya es >= 6)
					local globalInventorySlot = (itemData and typeof(itemData) == "table" and itemData.SlotIndex)
						or (if fromRealSlot >= 6 then fromRealSlot else (fromRealSlot + 5))

					print(`🎒 Moviendo ítem de la mochila (slot global {globalInventorySlot}) al espacio libre de Hotbar ({freeHotbarSlot})`)
					local InventoryService = Knit.GetService("InventoryService")

					InventoryService:MoveItem(globalInventorySlot, freeHotbarSlot):andThen(function(result)
						self:UpdateInventoryData(result)
					end):catch(warn)
				else
					warn("⚠️️ [Hotbar Llena] No hay espacios libres en la barra de acceso rápido.")
				end
			end
		end)
	end

	-- 3. Drag & Drop entre casillas de la mochila y hotbar
	if self.Inventory and self.Inventory.OnItemDropped then
		self.Inventory.OnItemDropped.Event:Connect(function(realFromSlot: number, realToSlot: number)
			if self.EquippedSlot == realFromSlot or self.EquippedSlot == realToSlot then
				self:UnequipCurrentItem()
			end

			local InventoryService = Knit.GetService("InventoryService")
			InventoryService:MoveItem(realFromSlot, realToSlot):andThen(function(result)
				self:UpdateInventoryData(result)
			end):catch(warn)
		end)
	end
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

	-- Si se presiona el mismo slot equipado, desequipar
	if self.EquippedSlot == slotIndex then
		self:UnequipCurrentItem()
		return
	end

	if not slotData or not slotData.Name or slotData.Name == "" then
		self:UnequipCurrentItem()
		return
	end

	local InventoryService = Knit.GetService("InventoryService")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild(slotData.Name) or character:FindFirstChild(slotData.Name)

	-- Si la Tool existe en la jerarquía del cliente, la equipamos directo
	if tool and tool:IsA("Tool") then
		self:UnequipCurrentItem()
		self.EquippedSlot = slotIndex
		self.Hotbar:HighlightSlot(slotIndex)
		humanoid:EquipTool(tool)
	elseif InventoryService and InventoryService.EquipItem then
		-- Si no existe físicamente en el cliente, solicitamos al servidor que la equipe/instancie
		InventoryService:EquipItem(slotIndex):andThen(function(success)
			if success then
				self.EquippedSlot = slotIndex
				if self.Hotbar then
					self.Hotbar:HighlightSlot(slotIndex)
				end
			end
		end):catch(warn)
	else
		warn(`🎒 [InventoryController] No se encontró la herramienta física '{slotData.Name}'.`)
	end
end

function InventoryController:UpdateInventoryData(updatedData: any)
	-- Validación defensiva para evitar intentar indexar booleanos o nil
	if type(updatedData) ~= "table" then
		local InventoryService = Knit.GetService("InventoryService")
		InventoryService:GetInventory():andThen(function(inventoryData)
			if type(inventoryData) == "table" then
				self:UpdateInventoryData(inventoryData)
			end
		end):catch(warn)
		return
	end

	self.CurrentInventoryData = updatedData

	local hotbarItems = {}
	local mainInventoryItems = {}

	if type(updatedData.Hotbar) == "table" then
		hotbarItems = updatedData.Hotbar
	end
	if type(updatedData.Mochila) == "table" then
		mainInventoryItems = updatedData.Mochila
	end

	-- Si viene el formato formateado de GetFormattedInventory con .Hotbar y .Items (donde .Items ya usa índices locales 1..24)
	if type(updatedData.Hotbar) == "table" and type(updatedData.Items) == "table" then
		mainInventoryItems = updatedData.Items
	else
		-- Formato crudo o mixto con índices globales (1..29)
		local itemsTable = type(updatedData.Items) == "table" and updatedData.Items or updatedData

		for key, itemData in pairs(itemsTable) do
			local slotNum = tonumber(key)
			if slotNum and type(itemData) == "table" then
				if slotNum >= 1 and slotNum <= 5 then
					if not updatedData.Hotbar then
						hotbarItems[slotNum] = itemData
					end
				elseif slotNum >= 6 then
					if not updatedData.Mochila then
						-- Convertir slot global (6..N) a slot local de la mochila (1..24)
						mainInventoryItems[slotNum - 5] = itemData
					end
				end
			end
		end
	end

	-- Renderizar en las vistas
	if self.Hotbar and typeof(self.Hotbar.SetHotbarData) == "function" then
		self.Hotbar:SetHotbarData(hotbarItems)
	end

	if self.Inventory and typeof(self.Inventory.SetItems) == "function" then
		self.Inventory:SetItems(mainInventoryItems)
	end
end

return InventoryController
