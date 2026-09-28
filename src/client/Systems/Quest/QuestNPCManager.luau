local CollectionService = game:GetService("CollectionService")

local QuestNPCManager = {}
QuestNPCManager.__index = QuestNPCManager

function QuestNPCManager.new(onInteractedCallback)
	local self = setmetatable({}, QuestNPCManager)
	self.OnInteractedCallback = onInteractedCallback

	self:SetupNPCs()
	
	-- Escuchar NPCs que aparezcan dinámicamente
	CollectionService:GetInstanceAddedSignal("QuestNPC"):Connect(function(npcObject)
		self:AttachPrompt(npcObject)
	end)

	return self
end

function QuestNPCManager:SetupNPCs()
	for _, npcObject in ipairs(CollectionService:GetTagged("QuestNPC")) do
		self:AttachPrompt(npcObject)
	end
end

function QuestNPCManager:AttachPrompt(npcObject: Instance)
	task.spawn(function()
		local targetPart: BasePart? = nil

		if npcObject:IsA("BasePart") then
			targetPart = npcObject
		else
			-- Esperar la parte principal sin usar métodos inexistentes
			targetPart = npcObject:WaitForChild("HumanoidRootPart", 5) 
				or npcObject:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		end

		if not targetPart then
			warn(`⚠️ [QuestNPCManager] No se encontró una parte válida para colocar el Prompt en {npcObject.Name}`)
			return
		end

		if targetPart:FindFirstChild("QuestPrompt") then return end

		local npcId = npcObject:GetAttribute("NPCId") or npcObject.Name

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QuestPrompt"
		prompt.ActionText = "Hablar"
		prompt.ObjectText = npcObject.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = targetPart

		prompt.Triggered:Connect(function(player)
			if self.OnInteractedCallback then
				self.OnInteractedCallback(npcId, npcObject.Name)
			end
		end)
	end)
end

return QuestNPCManager