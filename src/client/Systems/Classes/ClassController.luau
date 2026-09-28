local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)
local ClassSelectionView = require(Players.LocalPlayer.PlayerScripts.Client.UI.Views.ClassSelectionView)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ACTION_FREEZE = "DisableMovementForUI"

local ClassController = Knit.CreateController({
	Name = "ClassController",
})

function ClassController:KnitStart()
	print("[ClassController] Iniciando selector multiranura...")
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
	self:FreezePlayer()

	local view = ClassSelectionView.new()
	view:Mount(PlayerGui)

	-- 1. Obtenemos el servicio remoto de Knit
	local ClassService = Knit.GetService("ClassService")

	-- 2. Llamamos al método expuesto en el servidor (usando los Promises de Knit)
	ClassService:GetCharacterSlots():andThen(function(slots)
		view:SetCharacterSlots(slots or {})
	end):catch(function(err)
		warn("[ClassController] Error al obtener las ranuras del personaje:", err)
	end)

	-- Evento 1: Cargar Personaje Guardado Existente
	view.OnSelectExistingConfirmed.Event:Connect(function(slotId: string)
		ClassService:SelectCharacter(slotId):andThen(function(success)
			if success then
				view:ShowLoadingUI()
				self:StartWorldPreload(view)
			end
		end):catch(warn)
	end)

	-- Evento 2: Crear Nuevo Personaje en nueva ranura
	view.OnCreateNewConfirmed.Event:Connect(function(className: string, subtype: string?, charName: string)
		ClassService:CreateCharacter(className, subtype, charName):andThen(function(success)
			if success then
				view:ShowLoadingUI()
				self:StartWorldPreload(view)
			end
		end):catch(warn)
	end)
end

function ClassController:StartWorldPreload(view)
	local isSkipped = false

    local function completeLoad()
		view:Destroy()
		self:UnfreezePlayer()

		-- 🚀 MONTAR LA UI Y JALAR EL INVENTARIO AL FINALIZAR LA CARGA
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:MountUI()
		end

		print("[ClassController] Jugador ingresó al juego correctamente.")
	end

	local skipConnection
	skipConnection = view.OnSkipLoading.Event:Connect(function()
		isSkipped = true
		if skipConnection then skipConnection:Disconnect() end
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
				if child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Sound") or child:IsA("MeshPart") then
					table.insert(instancesToPreload, child)
				end
			end
		end

		local total = #instancesToPreload
		if total == 0 then total = 1 end

		for index, instance in ipairs(instancesToPreload) do
			if isSkipped then break end

			ContentProvider:PreloadAsync({ instance })
			local progress = index / total
			view:UpdateProgress(progress)

			task.wait()
		end

		if not isSkipped then
			if skipConnection then skipConnection:Disconnect() end
			completeLoad()
		end
	end)
end

return ClassController