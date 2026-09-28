local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local sharedQuest = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Quest")
local QuestData = require(sharedQuest:WaitForChild("QuestData"))

local ViewsFolder = PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Views")
local QuestDialogView = require(ViewsFolder:WaitForChild("QuestDialogView"))
local QuestNPCManager = require(script.Parent:WaitForChild("QuestNPCManager"))

local QuestController = Knit.CreateController({
	Name = "QuestController",
})

function QuestController:KnitStart()
	self.CurrentQuestData = nil
	self.DialogView = QuestDialogView.new()

	-- Manejar respuesta al presionar ACEPTAR en la interfaz
	self.DialogView.OnQuestAccepted.Event:Connect(function(questId: string)
		local QuestService = Knit.GetService("QuestService")
		QuestService:AcceptQuest(questId):andThen(function(success)
			if success then
				print(`📜 [QuestController] Misión '{questId}' aceptada con éxito.`)
			end
		end):catch(warn)
	end)

	-- Inicializar el manejador de NPCs en Workspace
	self.NPCManager = QuestNPCManager.new(function(npcId: string, npcName: string)
		self:OpenNPCMenu(npcId, npcName)
	end)

	-- Sincronización con el servidor
	local QuestService = Knit.GetService("QuestService")

	QuestService.QuestDataUpdated:Connect(function(data)
		self.CurrentQuestData = data
		print("📜 [QuestController] Datos de misiones actualizados.", data)
	end)

	QuestService:GetQuestData():andThen(function(data)
		if data then
			self.CurrentQuestData = data
		end
	end):catch(warn)

	print("📜 [QuestController] Controlador de misiones e interacciones iniciado.")
end

-- Buscar qué misión le corresponde a este NPC
function QuestController:OpenNPCMenu(npcId: string, npcName: string)
	local availableQuest = nil

	-- Buscar en la base de datos una misión donde este NPC sea el objetivo o que pertenezca a la zona
	for _, quest in pairs(QuestData.Quests) do
		local isAlreadyCompleted = self.CurrentQuestData and self.CurrentQuestData.Completed and self.CurrentQuestData.Completed[quest.Id]
		local isAlreadyActive = self.CurrentQuestData and self.CurrentQuestData.Active and self.CurrentQuestData.Active[quest.Id]

		if not isAlreadyCompleted and not isAlreadyActive then
			-- Si el primer objetivo de la misión es interactuar con este NPC
			local firstObjective = quest.Objectives[1]
			if firstObjective and firstObjective.Type == "Interact" and firstObjective.TargetId == npcId then
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
end

return QuestController