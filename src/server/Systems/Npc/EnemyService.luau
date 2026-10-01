local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {},
})

function EnemyService:KnitStart()
	self.QuestService = Knit.GetService("QuestService")
	self.Templates = {} -- Caché en memoria para los enemigos registrados en Workspace

	local npcsFolder = Workspace:WaitForChild("NPCs", 10)
	if not npcsFolder then
		warn("⚠️ [EnemyService] No se encontró la carpeta Workspace.NPCs")
		return
	end

	-- Función para escanear y registrar cualquier enemigo dentro de las subcarpetas
	local function scanFolder(folder: Instance)
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				self:RegisterEnemy(child)
			elseif child:IsA("Folder") then
				scanFolder(child)
			end
		end

		folder.ChildAdded:Connect(function(child)
			task.wait(0.1)
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				self:RegisterEnemy(child)
			elseif child:IsA("Folder") then
				scanFolder(child)
			end
		end)
	end

	scanFolder(npcsFolder)
	print("👾 [EnemyService] Gestor centralizado de enemigos activado (Escaneo recursivo de zonas).")
end

function EnemyService:RegisterEnemy(enemyModel: Model)
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or enemyModel:GetAttribute("Registered") then return end

	-- Evitar registrar NPCs neutros/aliados si no tienen un ID de enemigo asignado
	local targetId = enemyModel:GetAttribute("EnemyId") or enemyModel:GetAttribute("NPCId") or enemyModel.Name
	if string.sub(enemyModel.Name, 1, 4) == "NPC_" and not enemyModel:GetAttribute("EnemyId") then
		return
	end

	enemyModel:SetAttribute("Registered", true)

	-- Guardar plantilla en memoria si aún no existe
	self.Templates = self.Templates or {}
	if not self.Templates[enemyModel.Name] then
		local templateCopy = enemyModel:Clone()
		templateCopy:SetAttribute("Registered", nil)
		local templateHumanoid = templateCopy:FindFirstChildOfClass("Humanoid")
		if templateHumanoid then
			templateHumanoid.Health = templateHumanoid.MaxHealth
		end
		self.Templates[enemyModel.Name] = templateCopy
		print(`📦 [EnemyService] Plantilla guardada en caché para: '{enemyModel.Name}'`)
	end

	-- Asegurar parte principal si no está configurada
	if not enemyModel.PrimaryPart then
		local hrp = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel:FindFirstChildWhichIsA("BasePart")
		if hrp then
			enemyModel.PrimaryPart = hrp
		end
	end

	local spawnCFrame = enemyModel:GetPivot()
	local enemyName = enemyModel.Name
	local parentFolder = enemyModel.Parent
	local respawnTime = enemyModel:GetAttribute("RespawnTime") or 5

	print(`✅ [EnemyService] Enemigo registrado: '{enemyName}' en {parentFolder:GetFullName()}`)

	humanoid.Died:Connect(function()
		local creatorTag = humanoid:FindFirstChild("creator")
		local playerWhoKilled = creatorTag and creatorTag.Value

		if playerWhoKilled and playerWhoKilled:IsA("Player") then
			print(`💀 [EnemyService] {enemyName} fue eliminado por {playerWhoKilled.Name}!`)
			if self.QuestService then
				self.QuestService:RegisterKill(playerWhoKilled, targetId)
			end
		else
			print(`💀 [EnemyService] {enemyName} ha muerto.`)
		end

		-- Limpieza del cadáver
		task.delay(2, function()
			if enemyModel and enemyModel.Parent then
				enemyModel:Destroy()
			end
		end)

		-- Reaparición (Respawn)
		task.delay(respawnTime, function()
			print(`⏳ [EnemyService] Iniciando respawn de '{enemyName}'...`)
			self:SpawnEnemy(enemyName, spawnCFrame, parentFolder)
		end)
	end)
end

function EnemyService:SpawnEnemy(enemyName: string, spawnCFrame: CFrame, parentFolder: Instance)
	-- 1. Intentar obtener la plantilla desde el caché interno
	local template: Model? = self.Templates and self.Templates[enemyName]

	-- 2. Búsqueda secundaria en ServerStorage si no está en caché
	if not template then
		local directFolders = { ServerStorage, ServerStorage:FindFirstChild("Enemigos"), ServerStorage:FindFirstChild("NPCs") }
		for _, folder in ipairs(directFolders) do
			if folder then
				local found = folder:FindFirstChild(enemyName)
				if found and found:IsA("Model") then
					template = found
					break
				end
			end
		end
	end

	-- 3. Búsqueda profunda en ServerStorage
	if not template then
		for _, descendant in ipairs(ServerStorage:GetDescendants()) do
			if descendant:IsA("Model") and string.lower(descendant.Name) == string.lower(enemyName) then
				template = descendant
				break
			end
		end
	end

	if not template then
		warn(`⚠️ [EnemyService] No se encontró la plantilla de '{enemyName}' en ServerStorage ni en caché.`)
		return
	end

	-- Instanciar y reaparecer
	local newEnemy = template:Clone()
	newEnemy:SetAttribute("Registered", nil)
	newEnemy.Parent = parentFolder or Workspace:FindFirstChild("NPCs") or Workspace
	newEnemy:PivotTo(spawnCFrame)

	-- Registrar la nueva instancia creada
	task.defer(function()
		self:RegisterEnemy(newEnemy)
	end)

	print(`🔄 [EnemyService] '{newEnemy.Name}' ha reaparecido exitosamente en {newEnemy.Parent.Name}.`)
end

return EnemyService
