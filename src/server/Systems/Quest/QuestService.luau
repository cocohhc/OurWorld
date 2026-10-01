local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local sharedQuest = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Quest")
local QuestData = require(sharedQuest:WaitForChild("QuestData"))

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		QuestDataUpdated = Knit.CreateSignal(),
	},
})

function QuestService:KnitStart()
	self.PlayerDataManager = Knit.GetService("PlayerDataManager")
	print("📜 [QuestService] Servicio de misiones cargado con reclamo mediante NPC.")

	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerQuestData(player)
	end)
end

-- Obtener la referencia directa a los datos de misiones en la ranura activa
function QuestService:GetPlayerQuestData(player: Player)
	if not self.PlayerDataManager then return nil end

	local activeSlot = nil
	if type(self.PlayerDataManager.GetActiveSlot) == "function" then
		activeSlot = self.PlayerDataManager:GetActiveSlot(player)
	end

	if not activeSlot then
		local profile = nil
		if type(self.PlayerDataManager.GetProfile) == "function" then
			profile = self.PlayerDataManager:GetProfile(player)
		elseif type(self.PlayerDataManager.GetPlayerProfile) == "function" then
			profile = self.PlayerDataManager:GetPlayerProfile(player)
		elseif type(self.PlayerDataManager.GetProfileData) == "function" then
			profile = self.PlayerDataManager:GetProfileData(player)
		elseif self.PlayerDataManager.Profiles then
			profile = self.PlayerDataManager.Profiles[player]
		end

		if profile then
			activeSlot = profile.Data or profile
		end
	end

	if not activeSlot then return nil end

	activeSlot.Quests = activeSlot.Quests or {}
	activeSlot.Quests.Active = activeSlot.Quests.Active or {}
	activeSlot.Quests.Completed = activeSlot.Quests.Completed or {}

	return activeSlot.Quests
end

function QuestService.Client:GetQuestData(player: Player)
	local questData = self.Server:GetPlayerQuestData(player)
	if not questData then
		return { Active = {}, Completed = {} }
	end
	return questData
end

-- Aceptar misión
function QuestService.Client:AcceptQuest(player: Player, questId: string)
	local questConfig = QuestData.GetQuest(questId) or QuestData.Quests[questId]
	if not questConfig then
		warn(`⚠️ [QuestService] Misión no encontrada: '{questId}'`)
		return false
	end

	local questData = self.Server:GetPlayerQuestData(player)
	if not questData then return false end

	if questData.Active[questId] or questData.Completed[questId] then
		return false
	end

	if questConfig.PrerequisiteQuestId and questConfig.PrerequisiteQuestId ~= "" then
		if not questData.Completed or not questData.Completed[questConfig.PrerequisiteQuestId] then
			warn(`⚠️ [QuestService] {player.Name} no cumple el prerrequisito para '{questId}'`)
			return false
		end
	end

	local initialObjectives = {}
	if questConfig.Objectives then
		for index, _ in ipairs(questConfig.Objectives) do
			table.insert(initialObjectives, { Progress = 0 })
		end
	end

	questData.Active[questId] = {
		Objectives = initialObjectives,
		AcceptedAt = os.time(),
		ReadyToTurnIn = false, -- Marcador de lista para reclamar
	}

	self.Server.Client.QuestDataUpdated:Fire(player, questData)
	print(`📜 [QuestService] {player.Name} inició la misión '{questConfig.Title}' ({questId}).`)
	return true
end

-- Registrar bajas / avances
function QuestService:RegisterKill(player: Player, targetId: string)
	local questData = self:GetPlayerQuestData(player)
	if not questData or not questData.Active then return end

	local updated = false

	for questId, activeQuest in pairs(questData.Active) do
		local questConfig = QuestData.GetQuest(questId) or QuestData.Quests[questId]
		if not questConfig or not questConfig.Objectives then continue end

		for index, objConfig in ipairs(questConfig.Objectives) do
			if (objConfig.Type == "Kill" or objConfig.Type == "Interact") and objConfig.TargetId == targetId then
				local currentProgress = activeQuest.Objectives[index].Progress or 0
				local maxAmount = objConfig.RequiredAmount or 1

				if currentProgress < maxAmount then
					activeQuest.Objectives[index].Progress = currentProgress + 1
					updated = true
					print(`⚔️ [QuestService] {player.Name} progresó en '{questId}': {activeQuest.Objectives[index].Progress}/{maxAmount}`)

					self:CheckQuestStatus(player, questId)
				end
			end
		end
	end

	if updated then
		self.Client.QuestDataUpdated:Fire(player, questData)
	end
end

-- Verificar si la misión completó sus objetivos para marcarla lista para entregar
function QuestService:CheckQuestStatus(player: Player, questId: string)
	local questData = self:GetPlayerQuestData(player)
	local activeQuest = questData and questData.Active and questData.Active[questId]
	local questConfig = QuestData.GetQuest(questId) or QuestData.Quests[questId]

	if not activeQuest or not questConfig then return end

	local allCompleted = true
	for index, objConfig in ipairs(questConfig.Objectives) do
		local progress = activeQuest.Objectives[index].Progress or 0
		if progress < (objConfig.RequiredAmount or 1) then
			allCompleted = false
			break
		end
	end

	if allCompleted then
		activeQuest.ReadyToTurnIn = true
		print(`📍 [QuestService] {player.Name} completó los objetivos de '{questConfig.Title}'. ¡Debe volver al NPC!`)
	end
end

-- Reclamar recompensa directamente desde el NPC (Cliente -> Servidor)
function QuestService.Client:ClaimReward(player: Player, questId: string)
	local questData = self.Server:GetPlayerQuestData(player)
	if not questData or not questData.Active then return false end

	local activeQuest = questData.Active[questId]
	local questConfig = QuestData.GetQuest(questId) or QuestData.Quests[questId]

	if not activeQuest or not questConfig then return false end

	-- Verificar que los objetivos estén al 100%
	local allCompleted = true
	for index, objConfig in ipairs(questConfig.Objectives) do
		local progress = activeQuest.Objectives[index].Progress or 0
		if progress < (objConfig.RequiredAmount or 1) then
			allCompleted = false
			break
		end
	end

	if not allCompleted then
		warn(`⚠️ [QuestService] {player.Name} intentó reclamar '{questId}' sin completar los objetivos.`)
		return false
	end

	-- Pasar a completadas y quitar de activas
	questData.Active[questId] = nil
	questData.Completed[questId] = true

	-- Entregar recompensas
	self.Server:GiveRewards(player, questConfig.Rewards)

	-- Sincronizar con el cliente
	self.Server.Client.QuestDataUpdated:Fire(player, questData)
	print(`🎁 [QuestService] {player.Name} reclamó la recompensa de '{questConfig.Title}'!`)
	return true
end

-- Entregar recompensas
function QuestService:GiveRewards(player: Player, rewards: table)
	if not rewards or not self.PlayerDataManager then return end

	local targetData = nil
	if type(self.PlayerDataManager.GetActiveSlot) == "function" then
		targetData = self.PlayerDataManager:GetActiveSlot(player)
	end

	if not targetData then
		local profile = nil
		if type(self.PlayerDataManager.GetProfile) == "function" then
			profile = self.PlayerDataManager:GetProfile(player)
		elseif type(self.PlayerDataManager.GetPlayerProfile) == "function" then
			profile = self.PlayerDataManager:GetPlayerProfile(player)
		elseif type(self.PlayerDataManager.GetProfileData) == "function" then
			profile = self.PlayerDataManager:GetProfileData(player)
		elseif self.PlayerDataManager.Profiles then
			profile = self.PlayerDataManager.Profiles[player]
		end

		if profile then
			targetData = profile.Data or profile
		end
	end

	if not targetData then return end

	for _, reward in ipairs(rewards) do
		if reward.Type == "Exp" then
			targetData.Experience = (targetData.Experience or 0) + reward.Amount
		elseif reward.Type == "Gold" then
			targetData.Gold = (targetData.Gold or 0) + reward.Amount
		end
	end
end

function QuestService:SavePlayerQuestData(player: Player)
	local questData = self:GetPlayerQuestData(player)
	if questData then
		print(`💾 [QuestService] Misiones guardadas para {player.Name}.`)
	end
end

return QuestService
