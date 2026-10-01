local QuestTypes = require(script.Parent.QuestTypes)

local QuestData = {}
QuestData.Quests = {} :: { [string]: QuestTypes.Quest }

local isLoaded = false

local function loadQuests()
	if isLoaded then return end

	-- Buscar la carpeta Quests dentro del módulo Quest
	local QuestsFolder = script.Parent:FindFirstChild("Quests") or script.Parent:WaitForChild("Quests", 5)

	if QuestsFolder then
		for _, moduleScript in ipairs(QuestsFolder:GetChildren()) do
			if moduleScript:IsA("ModuleScript") then
				local success, zoneQuests = pcall(require, moduleScript)
				if success and type(zoneQuests) == "table" then
					for questId, questConfig in pairs(zoneQuests) do
						if QuestData.Quests[questId] then
							warn(`⚠️ [QuestData] ID duplicado detectado: {questId} en {moduleScript.Name}`)
						else
							QuestData.Quests[questId] = questConfig
						end
					end
				else
					warn(`⚠️ [QuestData] Error al requerir el módulo de misiones: {moduleScript.Name}`)
				end
			end
		end
		isLoaded = true
	else
		warn("⚠️ [QuestData] No se encontró la carpeta 'Quests' dentro de " .. script.Parent:GetFullName())
	end
end

-- Cargar inmediatamente al requerir
loadQuests()

function QuestData.GetQuest(questId: string): QuestTypes.Quest?
	if not isLoaded then loadQuests() end
	return QuestData.Quests[questId]
end

function QuestData.GetAllQuests(): { [string]: QuestTypes.Quest }
	if not isLoaded then loadQuests() end
	return QuestData.Quests
end

return QuestData
