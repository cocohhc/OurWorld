local QuestTypes = require(script.Parent.QuestTypes)

local QuestData = {}
QuestData.Quests = {} :: { [string]: QuestTypes.Quest }
local isLoaded = false

local function loadQuests()
	if isLoaded then return end

	local QuestsFolder = script.Parent:WaitForChild("Quests", 15)
	if QuestsFolder then
		for _, moduleScript in ipairs(QuestsFolder:GetChildren()) do
			if moduleScript:IsA("ModuleScript") then
				local zoneQuests = require(moduleScript)
				for questId, questConfig in pairs(zoneQuests) do
					if QuestData.Quests[questId] then
						warn(`⚠️ [QuestData] ID duplicado detectado: {questId} en {moduleScript.Name}`)
					else
						QuestData.Quests[questId] = questConfig
					end
				end
			end
		end
		isLoaded = true
	else
		warn("⚠️ [QuestData] No se encontró la carpeta 'Quests' dentro de ReplicatedStorage.Shared.Systems.Quest")
	end
end

-- Ejecutar carga inicial en segundo plano
task.spawn(loadQuests)

function QuestData.GetQuest(questId: string): QuestTypes.Quest?
	if not isLoaded then loadQuests() end
	return QuestData.Quests[questId]
end

return QuestData