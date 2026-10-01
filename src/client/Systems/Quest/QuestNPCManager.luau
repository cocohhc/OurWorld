local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local QuestNPCManager = {}
QuestNPCManager.__index = QuestNPCManager

function QuestNPCManager.new(onInteractedCallback)
	local self = setmetatable({}, QuestNPCManager)
	self.OnInteractedCallback = onInteractedCallback

	-- Función auxiliar para verificar y vincular NPCs
	local function checkAndAttach(instance: Instance)
		if instance:IsA("Model") and (instance:GetAttribute("NPCId") or instance:HasTag("QuestNPC") or string.sub(instance.Name, 1, 4) == "NPC_") then
			if not CollectionService:HasTag(instance, "QuestNPC") then
				CollectionService:AddTag(instance, "QuestNPC")
			end
			self:AttachPrompt(instance)
		end
	end

	-- 1. Escuchar asignaciones dinámicas por CollectionService Tag
	CollectionService:GetInstanceAddedSignal("QuestNPC"):Connect(function(npcObject)
		self:AttachPrompt(npcObject)
	end)

	-- 2. Escuchar cualquier nuevo NPC cargado dinámicamente en Workspace (incluyendo subcarpetas como Workspace.NPCs.Zone1)
	Workspace.DescendantAdded:Connect(function(descendant)
		checkAndAttach(descendant)
	end)

	-- 3. Ejecutar búsqueda inicial en diferido
	task.defer(function()
		self:SetupNPCs()
	end)

	return self
end

function QuestNPCManager:SetupNPCs()
	-- Procesar elementos etiquetados previamente
	for _, npcObject in ipairs(CollectionService:GetTagged("QuestNPC")) do
		self:AttachPrompt(npcObject)
	end

	-- Escaneo recursivo profundo de todo el Workspace (cubre Workspace.NPCs y cualquier subzona como Zone1, PrimeraZona, etc.)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and (descendant:GetAttribute("NPCId") or string.sub(descendant.Name, 1, 4) == "NPC_") then
			if not CollectionService:HasTag(descendant, "QuestNPC") then
				CollectionService:AddTag(descendant, "QuestNPC")
			end
			self:AttachPrompt(descendant)
		end
	end
end

function QuestNPCManager:AttachPrompt(npcObject: Instance)
	if not npcObject or not npcObject:IsDescendantOf(game) then return end
	if npcObject:FindFirstChild("QuestPrompt", true) then return end

	-- Evitar ejecuciones duplicadas en paralelo para la misma instancia
	self.AttachingMap = self.AttachingMap or {}
	if self.AttachingMap[npcObject] then return end
	self.AttachingMap[npcObject] = true

	task.spawn(function()
		local function findPart(): BasePart?
			if not npcObject or not npcObject:IsDescendantOf(game) then return nil end
			if npcObject:IsA("BasePart") then
				return npcObject
			elseif npcObject:IsA("Model") then
				if npcObject.PrimaryPart then
					return npcObject.PrimaryPart
				end
				local hrp = npcObject:FindFirstChild("HumanoidRootPart", true)
				if hrp and hrp:IsA("BasePart") then
					return hrp
				end
				local head = npcObject:FindFirstChild("Head", true)
				if head and head:IsA("BasePart") then
					return head
				end
				for _, descendant in ipairs(npcObject:GetDescendants()) do
					if descendant:IsA("BasePart") then
						return descendant
					end
				end
			end
			return nil
		end

		local targetPart = findPart()

		-- Escuchar continuamente sin limite arbitrario de tiempo mientras el objeto exista en la escena
		if not targetPart then
			local connection: RBXScriptConnection? = nil

			connection = npcObject.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") and not targetPart then
					targetPart = findPart()
				end
			end)

			while not targetPart and npcObject:IsDescendantOf(game) do
				targetPart = findPart()
				if targetPart then break end
				task.wait(0.5)
			end

			if connection then
				connection:Disconnect()
			end
		end

		self.AttachingMap[npcObject] = nil

		if not targetPart or not npcObject:IsDescendantOf(game) then
			return
		end

		if targetPart:FindFirstChild("QuestPrompt") or npcObject:FindFirstChild("QuestPrompt", true) then
			return
		end

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
