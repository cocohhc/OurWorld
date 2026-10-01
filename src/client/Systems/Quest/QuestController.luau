local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local sharedQuest = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Quest")
local QuestData = require(sharedQuest:WaitForChild("QuestData"))

local ViewsFolder = PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Views")
local QuestDialogView = require(ViewsFolder:WaitForChild("QuestDialogView"))
local QuestTrackerView = require(ViewsFolder:WaitForChild("QuestTrackerView"))
local QuestNPCManager = require(script.Parent:WaitForChild("QuestNPCManager"))

local QuestController = Knit.CreateController({
	Name = "QuestController",
})

function QuestController:KnitStart()
	self.CurrentQuestData = { Active = {}, Completed = {} }

	-- Inicialización de Vistas
	self.DialogView = QuestDialogView.new()
	self.TrackerView = QuestTrackerView.new()

	-- Aceptar misión desde el menú del NPC
	self.DialogView.OnQuestAccepted.Event:Connect(function(questId: string)
		local QuestService = Knit.GetService("QuestService")
		QuestService:AcceptQuest(questId):andThen(function(success)
			if success then
				print(`📜 [QuestController] Misión '{questId}' aceptada.`)
			end
		end):catch(warn)
	end)

	-- Reclamar recompensa desde el menú del NPC
	if self.DialogView.OnQuestClaimed then
		self.DialogView.OnQuestClaimed.Event:Connect(function(questId: string)
			local QuestService = Knit.GetService("QuestService")
			QuestService:ClaimReward(questId):andThen(function(success)
				if success then
					print(`🎁 [QuestController] Recompensa de '{questId}' reclamada exitosamente.`)
					self.DialogView:Toggle(false) -- Fix: Usar Toggle(false) en vez de Hide()
				end
			end):catch(warn)
		end)
	end

	-- Entrada por teclado (Tecla M)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self.TrackerView:Toggle()
			if self.TrackerView.IsOpen then
				self:RefreshTrackerUI()
			end
		end
	end)

	-- Manejador de interacciones con NPCs
	self.NPCManager = QuestNPCManager.new(function(npcId: string, npcName: string)
		self:OpenNPCMenu(npcId, npcName)
	end)

	-- Sincronización continua con QuestService
	local QuestService = Knit.GetService("QuestService")

	QuestService.QuestDataUpdated:Connect(function(data)
		if data then
			self.CurrentQuestData = data
			self:RefreshTrackerUI()
		end
	end)

	-- Fix: Eliminado el bucle recursivo infinito que trababa el hilo si no habían misiones
	local function fetchInitialData()
		QuestService:GetQuestData():andThen(function(data)
			self.CurrentQuestData = data or { Active = {}, Completed = {} }
			self:RefreshTrackerUI()
		end):catch(warn)
	end

	fetchInitialData()

	print("📜 [QuestController] Controlador de misiones iniciado (Tecla M activada).")
end

function QuestController:RefreshTrackerUI()
	if self.TrackerView then
		local active = self.CurrentQuestData and self.CurrentQuestData.Active or {}
		local allQuests = QuestData.GetAllQuests and QuestData.GetAllQuests() or QuestData.Quests
		self.TrackerView:UpdateList(active, allQuests)
	end
end

-- Abrir menú de interacción con NPC
function QuestController:OpenNPCMenu(npcId: string, npcName: string)
	local QuestService = Knit.GetService("QuestService")

	-- Fix: Forzar la descarga de datos frescos antes de abrir la UI para evitar cruce de datos entre personajes
	QuestService:GetQuestData():andThen(function(data)
		self.CurrentQuestData = data or { Active = {}, Completed = {} }
		self:RefreshTrackerUI()

		local availableQuest = nil
		local readyToTurnInQuest = nil
		local allQuests = QuestData.GetAllQuests and QuestData.GetAllQuests() or QuestData.Quests

		-- 1. Buscar si el NPC tiene alguna misión lista para ser entregada/reclamada
		for id, activeQuest in pairs(self.CurrentQuestData.Active or {}) do
			local questConfig = allQuests[id]
			if questConfig then
				local hasSpecificNPC = (questConfig.GiverId ~= nil) or (questConfig.NPCId ~= nil)
				local isGiver = (questConfig.GiverId == npcId or questConfig.GiverId == npcName or questConfig.NPCId == npcId or questConfig.NPCId == npcName)

				-- Fix: Si la misión no requiere un NPC específico, permitir entregarla
				local canTurnInHere = if hasSpecificNPC then isGiver else true

				-- Verificar si completó todos los objetivos
				local allCompleted = true
				if questConfig.Objectives then
					for index, objConfig in ipairs(questConfig.Objectives) do
						local progress = activeQuest.Objectives and activeQuest.Objectives[index] and activeQuest.Objectives[index].Progress or 0
						if progress < (objConfig.RequiredAmount or 1) then
							allCompleted = false
							break
						end
					end
				end

				if canTurnInHere and (allCompleted or activeQuest.ReadyToTurnIn) then
					readyToTurnInQuest = questConfig
					break
				end
			end
		end

		-- Si hay una misión lista para entregar, mostrar diálogo para reclamar recompensa
		if readyToTurnInQuest then
			if type(self.DialogView.ShowClaimDialog) == "function" then
				self.DialogView:ShowClaimDialog(
					npcId,
					npcName,
					`¡Excelente trabajo! Has completado '{readyToTurnInQuest.Title}'. Aquí tienes tu recompensa.`,
					readyToTurnInQuest
				)
			else
				self.DialogView:ShowNPC(
					npcId,
					npcName,
					`¡Excelente trabajo! Reclama tu recompensa por: {readyToTurnInQuest.Title}`,
					readyToTurnInQuest
				)
			end
			return
		end

		-- 2. Si no hay entregas pendientes, buscar misiones disponibles para aceptar
		for id, quest in pairs(allQuests) do
			local isAlreadyCompleted = self.CurrentQuestData and self.CurrentQuestData.Completed and self.CurrentQuestData.Completed[quest.Id]
			local isAlreadyActive = self.CurrentQuestData and self.CurrentQuestData.Active and self.CurrentQuestData.Active[quest.Id]

			local prereqMet = true
			if quest.PrerequisiteQuestId and quest.PrerequisiteQuestId ~= "" then
				prereqMet = self.CurrentQuestData and self.CurrentQuestData.Completed and self.CurrentQuestData.Completed[quest.PrerequisiteQuestId] == true
			end

			if not isAlreadyCompleted and not isAlreadyActive and prereqMet then
				local firstObjective = quest.Objectives and quest.Objectives[1]

				local hasSpecificNPC = (quest.GiverId ~= nil) or (quest.NPCId ~= nil)
				local isGiver = (quest.GiverId == npcId or quest.GiverId == npcName or quest.NPCId == npcId or quest.NPCId == npcName)
				local isInteractTarget = firstObjective and firstObjective.Type == "Interact" and (firstObjective.TargetId == npcId or firstObjective.TargetId == npcName)

				if hasSpecificNPC or (firstObjective and firstObjective.Type == "Interact") then
					if isGiver or isInteractTarget then
						availableQuest = quest
						break
					end
				else
					availableQuest = quest
					break
				end
			end
		end

		if availableQuest then
			self.DialogView:ShowNPC(npcId, npcName, `¡Saludos! Tengo una tarea para ti: {availableQuest.Title}`, availableQuest)
		else
			self.DialogView:ShowNPC(npcId, npcName, "No tengo más misiones para ti por ahora.", nil)
		end

	end):catch(function(err)
		warn("⚠️ [QuestController] Error obteniendo datos del servidor:", err)
	end)
end

return QuestController
