local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

-- Referencia segura a MenuView desde la estructura de UI
local ClientFolder = PlayerScripts:WaitForChild("Client")
local MenuView = require(ClientFolder:WaitForChild("UI"):WaitForChild("Views"):WaitForChild("MenuView"))

local MenuController = Knit.CreateController({
	Name = "MenuController",
})

function MenuController:KnitInit()
	print("🍔 [MenuController] Inicializando controlador de menú de acceso rápido...")
end

function MenuController:KnitStart()
	print("🚀 [MenuController] Iniciando controlador e instanciando MenuView...")

	self.MenuView = MenuView.new()

	-- Escuchar la selección de personaje para restaurar la visibilidad tras relog/logout
	local ClassService = Knit.GetService("ClassService")
	ClassService.ClassSelected:Connect(function(_classData)
		if self.MenuView then
			self.MenuView:SetVisible(true)
			print("👁️ [MenuController] MenuView reactivado tras la selección de personaje")
		end
	end)

	-- Evento: Abrir / Cerrar Mochila
	self.MenuView.OnToggleInventory.Event:Connect(function()
		print("🎒 [MenuController] Toggle Mochila solicitado.")
		local inventoryController = Knit.GetController("InventoryController")
		if inventoryController and inventoryController.ToggleInventory then
			inventoryController:ToggleInventory()
		else
			warn("⚠️ [MenuController] InventoryController.ToggleInventory no encontrado.")
		end
	end)

	-- Evento: Abrir / Cerrar Misiones
self.MenuView.OnToggleQuests.Event:Connect(function()
		print("📜 [MenuController] Toggle Misiones solicitado.")
		local questController = Knit.GetController("QuestController")
		if questController then
			if typeof(questController.ToggleQuestWindow) == "function" then
				questController:ToggleQuestWindow()
			elseif typeof(questController.ToggleQuestTracker) == "function" then
				questController:ToggleQuestTracker()
			elseif typeof(questController.ToggleWindow) == "function" then
				questController:ToggleWindow()
			elseif typeof(questController.ToggleQuestLog) == "function" then
				questController:ToggleQuestLog()
			elseif typeof(questController.Toggle) == "function" then
				questController:Toggle()
			else
				warn("⚠️ [MenuController] QuestController no posee un método de apertura conocido (ToggleQuestWindow, ToggleQuestTracker, ToggleWindow, etc.).")
			end
		else
			warn("❌ [MenuController] No se pudo obtener QuestController desde Knit.")
		end
	end)

	-- Evento: Confirmar Salir / Volver a Selección de Personaje
	self.MenuView.OnLogout.Event:Connect(function()
		print("🚪 [MenuController] Jugador solicitó salir al menú de selección de personajes.")

		-- Ocultar menú desplegable/HUD
		if self.MenuView then
			self.MenuView:SetVisible(false)
		end

		local classController = Knit.GetController("ClassController")
		if classController then
			if typeof(classController.InitializeSelectionFlow) == "function" then
				classController:InitializeSelectionFlow()
			elseif typeof(classController.OpenSelectionView) == "function" then
				classController:OpenSelectionView()
			elseif typeof(classController.ShowSelectionView) == "function" then
				classController:ShowSelectionView()
			elseif typeof(classController.OpenClassSelection) == "function" then
				classController:OpenClassSelection()
			elseif typeof(classController.OpenView) == "function" then
				classController:OpenView()
			else
				warn("⚠️ [MenuController] ClassController no posee un método conocido para abrir la interfaz.")
			end
		else
			warn("❌ [MenuController] No se pudo obtener ClassController desde Knit.")
		end
	end)

	print("✅ [MenuController] Controlador de menú activo e interfaz vinculada.")
end

return MenuController
