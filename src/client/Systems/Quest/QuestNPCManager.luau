local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local QuestNPCManager = {}
QuestNPCManager.__index = QuestNPCManager

function QuestNPCManager.new(onInteractedCallback)
	local self = setmetatable({}, QuestNPCManager)
	self.OnInteractedCallback = onInteractedCallback

	-- Escuchar NPCs que aparezcan dinámicamente por Tag
	CollectionService:GetInstanceAddedSignal("QuestNPC"):Connect(function(npcObject)
		self:AttachPrompt(npcObject)
	end)

	-- Escuchar NPCs en Workspace directamente
	Workspace.ChildAdded:Connect(function(child)
		if child:GetAttribute("NPCId") or child:HasTag("QuestNPC") or string.sub(child.Name, 1, 4) == "NPC_" then
			self:AttachPrompt(child)
		end
	end)

	-- Escuchar NPCs que aparezcan en Workspace.NPCs o Workspace.NPCs.PrimeraZona
	local npcsFolder = Workspace:FindFirstChild("NPCs")
	if npcsFolder then
		npcsFolder.ChildAdded:Connect(function(child)
			if child:GetAttribute("NPCId") or child:HasTag("QuestNPC") or string.sub(child.Name, 1, 4) == "NPC_" then
				self:AttachPrompt(child)
			end
		end)

		local primeraZonaFolder = npcsFolder:FindFirstChild("PrimeraZona")
		if primeraZonaFolder then
			primeraZonaFolder.ChildAdded:Connect(function(child)
				if child:GetAttribute("NPCId") or child:HasTag("QuestNPC") or string.sub(child.Name, 1, 4) == "NPC_" then
					self:AttachPrompt(child)
				end
			end)
		end
	end

	-- Ejecutar búsqueda inicial dando tiempo a que Workspace termine de cargar
	task.defer(function()
		self:SetupNPCs()
	end)

	return self
end

function QuestNPCManager:SetupNPCs()
	for _, npcObject in ipairs(CollectionService:GetTagged("QuestNPC")) do
		self:AttachPrompt(npcObject)
	end

	-- Buscar directamente en raíz de Workspace
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and (child:GetAttribute("NPCId") or string.sub(child.Name, 1, 4) == "NPC_") then
			if not CollectionService:HasTag(child, "QuestNPC") then
				CollectionService:AddTag(child, "QuestNPC")
			end
			self:AttachPrompt(child)
		end
	end

	-- Buscar también en la estructura de carpetas Workspace.NPCs.PrimeraZona
	local npcsFolder = Workspace:FindFirstChild("NPCs")
	if npcsFolder then
		local primeraZonaFolder = npcsFolder:FindFirstChild("PrimeraZona")
		local targetFolder = primeraZonaFolder or npcsFolder

		for _, child in ipairs(targetFolder:GetChildren()) do
			if child:IsA("Model") and (child:GetAttribute("NPCId") or string.sub(child.Name, 1, 4) == "NPC_") then
				if not CollectionService:HasTag(child, "QuestNPC") then
					CollectionService:AddTag(child, "QuestNPC")
				end
				self:AttachPrompt(child)
			end
		end
	end
end

function QuestNPCManager:AttachPrompt(npcObject: Instance)
	task.spawn(function()
		local targetPart: BasePart? = nil

		if npcObject:IsA("BasePart") then
			targetPart = npcObject
		elseif npcObject:IsA("Model") then
			-- Esperar activamente a las partes principales del modelo
			targetPart = npcObject.PrimaryPart
				or npcObject:WaitForChild("HumanoidRootPart", 10) :: BasePart?
				or npcObject:WaitForChild("Head", 5) :: BasePart?

			if not targetPart then
				-- Si no encuentra RootPart ni Head, esperar a cualquier BasePart que replique
				local hrp = npcObject:FindFirstChildOfClass("BasePart")
				if not hrp then
					local childAddedConnection
					childAddedConnection = npcObject.ChildAdded:Connect(function(child)
						if child:IsA("BasePart") then
							targetPart = child
						end
					end)

					local start = os.clock()
					while not targetPart and (os.clock() - start) < 10 do
						task.wait(0.2)
					end

					if childAddedConnection then
						childAddedConnection:Disconnect()
					end
				else
					targetPart = hrp
				end
			end
		end

		if not targetPart then
			warn(`⚠️ [QuestNPCManager] No se encontró una parte válida para colocar el Prompt en {npcObject.Name}`)
			return
		end

		if targetPart:FindFirstChild("QuestPrompt") then return end

		local npcId = npcObject:GetAttribute("NPCId")
		if not npcId or npcId == "" then
			npcId = npcObject.Name
		end

		print(`✅ [QuestNPCManager] Prompt de interacción vinculado exitosamente a {npcObject.Name} (NPCId: '{npcId}')`)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QuestPrompt"
		prompt.ActionText = "Hablar"
		prompt.ObjectText = npcObject.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = targetPart

		prompt.Triggered:Connect(function(player)
			print(`👆 [QuestNPCManager] Interacción detectada con {npcObject.Name}`)
			if self.OnInteractedCallback then
				self.OnInteractedCallback(npcId, npcObject.Name)
			end
		end)
	end)
end

return QuestNPCManager
