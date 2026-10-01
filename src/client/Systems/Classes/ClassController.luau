local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local ViewsFolder = PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Views")
local ClassSelectionView = require(ViewsFolder:WaitForChild("ClassSelectionView"))

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ACTION_FREEZE = "DisableMovementForUI"

local ClassController = Knit.CreateController({
	Name = "ClassController",
})

function ClassController:KnitStart()
	print("🧙‍♂️ [ClassController] Iniciando selector multiranura...")
	self:InitializeSelectionFlow()
end

function ClassController:FreezePlayer()
	ContextActionService:BindActionAtPriority(
		ACTION_FREEZE,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
end

function ClassController:UnfreezePlayer()
	ContextActionService:UnbindAction(ACTION_FREEZE)
end

function ClassController:InitializeSelectionFlow()
	print("🔄 [ClassController] Poniendo sistemas en reposo e iniciando flujo de selección...")

	self:FreezePlayer()

	-- 1. Reposo UI del cliente
	local InventoryController = Knit.GetController("InventoryController")
	if InventoryController then
		if typeof(InventoryController.UnmountUI) == "function" then
			InventoryController:UnmountUI()
		elseif typeof(InventoryController.HideHotbar) == "function" then
			InventoryController:HideHotbar()
		end
	end

	-- Ocultar menú de acceso rápido al regresar a la selección
	local MenuController = Knit.GetController("MenuController")
	if MenuController and MenuController.MenuView then
		MenuController.MenuView:SetVisible(false)
	end

	if self.CurrentView then
		self.CurrentView:Destroy()
		self.CurrentView = nil
	end

	local ClassService = Knit.GetService("ClassService")

	-- 2. Esperar a que el servidor termine de limpiar antes de pedir y mostrar slots
	ClassService:DeselectCharacter():andThen(function()
		return ClassService:GetCharacterSlots()
	end):andThen(function(slots)
		local view = ClassSelectionView.new()
		self.CurrentView = view
		view:Mount(PlayerGui)
		view:SetCharacterSlots(slots or {})

		-- Evento 1: Cargar Personaje Guardado Existente
		view.OnSelectExistingConfirmed.Event:Connect(function(slotId: string)
			ClassService:SelectCharacter(slotId):andThen(function(success)
				if success then
					view:ShowLoadingUI()
					self:StartWorldPreload(view)
				end
			end):catch(warn)
		end)

		-- Evento 2: Crear Nuevo Personaje
		view.OnCreateNewConfirmed.Event:Connect(function(className: string, subtype: string?, charName: string)
			ClassService:CreateCharacter(className, subtype, charName):andThen(function(success)
				if success then
					view:ShowLoadingUI()
					self:StartWorldPreload(view)
				end
			end):catch(warn)
		end)
	end):catch(function(err)
		warn("⚠️ [ClassController] Error durante el flujo de inicio:", err)
	end)
end

function ClassController:StartWorldPreload(view)
	local isSkipped = false

	local function completeLoad()
		if isSkipped then return end
		isSkipped = true

		view:Destroy()
		self:UnfreezePlayer()

		-- 🚀 REVELAR INVENTARIO, HOTBAR Y MENÚ TRAS COMPLETAR LA CARGA E INGRESAR AL MUNDO
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:MountUI()
			InventoryController:ShowHotbar()
		end

		local MenuController = Knit.GetController("MenuController")
		if MenuController and MenuController.MenuView then
			MenuController.MenuView:SetVisible(true)
		end

		print("✅ [ClassController] Jugador ingresó al juego correctamente.")
	end

	local skipConnection
	skipConnection = view.OnSkipLoading.Event:Connect(function()
		if skipConnection then
			skipConnection:Disconnect()
			skipConnection = nil
		end
		completeLoad()
	end)

	task.spawn(function()
		local assetsToLoad = {
			workspace,
			ReplicatedStorage,
			LocalPlayer:WaitForChild("Backpack"),
		}

		local instancesToPreload = {}
		for _, parent in ipairs(assetsToLoad) do
			for _, child in ipairs(parent:GetDescendants()) do
				if child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Sound") or child:IsA("MeshPart") or child:IsA("Texture") then
					table.insert(instancesToPreload, child)
				end
			end
		end

		local total = #instancesToPreload
		if total == 0 then
			view:UpdateProgress(1)
			if skipConnection then skipConnection:Disconnect() end
			completeLoad()
			return
		end

		-- Carga por lotes para no ralentizar el hilo de la UI
		local batchSize = 10
		for i = 1, total, batchSize do
			if isSkipped then break end

			local batch = {}
			for j = i, math.min(i + batchSize - 1, total) do
				table.insert(batch, instancesToPreload[j])
			end

			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)

			local progress = math.min(i + batchSize - 1, total) / total
			view:UpdateProgress(progress)

			task.wait(0.03)
		end

		if not isSkipped then
			if skipConnection then
				skipConnection:Disconnect()
				skipConnection = nil
			end
			completeLoad()
		end
	end)
end

return ClassController
