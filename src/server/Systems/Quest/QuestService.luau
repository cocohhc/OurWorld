local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local sharedQuest = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Quest")
local QuestData = require(sharedQuest:WaitForChild("QuestData"))

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		QuestDataUpdated = Knit.CreateSignal(),
	},
})

function QuestService:KnitStart()
	print("[QuestService] Servicio de misiones iniciado.")
end

function QuestService:GetPlayerDataManager()
	return Knit.GetService("PlayerDataManager")
end

-- Obtener misiones activas y completadas del perfil del jugador
function QuestService:GetRawQuestData(player: Player)
	local PlayerDataManager = self:GetPlayerDataManager()
	if PlayerDataManager then
		local activeSlot = PlayerDataManager:GetActiveSlot(player)
		if activeSlot then
			activeSlot.Quests = activeSlot.Quests or {
				Active = {},    -- { [QuestId]: { ObjectivesProgress = { [index]: currentAmount } } }
				Completed = {}, -- { [QuestId] = true }
			}
			return activeSlot.Quests
		end
	end
	return { Active = {}, Completed = {} }
end

-- Intentar aceptar una misión lineal
function QuestService.Client:AcceptQuest(player: Player, questId: string): boolean
	local questConfig = QuestData.GetQuest(questId)
	if not questConfig then return false end

	local questData = self.Server:GetRawQuestData(player)

	-- Validaciones
	if questData.Completed[questId] or questData.Active[questId] then
		return false
	end

	if questConfig.PrerequisiteQuestId and not questData.Completed[questConfig.PrerequisiteQuestId] then
		warn(`[QuestService] {player.Name} no cumple el prerrequisito para {questId}`)
		return false
	end

	-- Inicializar progreso de objetivos
	local initialObjectivesProgress = {}
	for index, _ in ipairs(questConfig.Objectives) do
		initialObjectivesProgress[index] = 0
	end

	questData.Active[questId] = {
		ObjectivesProgress = initialObjectivesProgress,
	}

	self.Server.Client.QuestDataUpdated:Fire(player, questData)
	print(`📜 [QUEST] {player.Name} aceptó la misión: {questConfig.Title}`)
	return true
end

function QuestService.Client:GetQuestData(player: Player)
	return self.Server:GetRawQuestData(player)
end

return QuestService