-- src/server/Systems/Npc/EnemyService.luau
-- Gestor centralizado de enemigos, respawn con caché y otorgamiento de XP/Misiones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {},
})

-- Tabla de XP base por tipo/raza de enemigo
local ENEMY_XP_REWARDS = {
	["Scavenger"] = 10,
	["Bandido"] = 15,
	["Mutant_Rad"] = 40,
	["Elite_Soldier"] = 90,
	["Boss_Radiation"] = 350,
}

function EnemyService:KnitStart()
	self.QuestService = Knit.GetService("QuestService")
	self.EnemyAIService = Knit.GetService("EnemyAIService")
	self.ProgressionService = Knit.GetService("ProgressionService")

	self.Templates = {} -- Caché en memoria para los enemigos registrados en Workspace
	self.PreClonedEnemies = {} -- Cola de clones preparados para evitar lag

	-- Carpeta oculta para almacenar pre-clones inactivos
	self.EnemyCacheFolder = Instance.new("Folder")
	self.EnemyCacheFolder.Name = "EnemyPreClones"
	self.EnemyCacheFolder.Parent = ServerStorage

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

-- Estrategia de rendimiento: Clona el siguiente NPC en segundo plano
function EnemyService:PreCloneEnemy(enemyName: string)
	self.PreClonedEnemies[enemyName] = self.PreClonedEnemies[enemyName] or {}

	local template = self.Templates[enemyName]
	if not template then return end

	local clone = template:Clone()
	clone:SetAttribute("Registered", nil)
	clone.Parent = self.EnemyCacheFolder
	table.insert(self.PreClonedEnemies[enemyName], clone)
end

-- Cálculo y entrega de experiencia al jugador atacante
function EnemyService:GrantEnemyXP(killerPlayer: Player, enemyModel: Model, enemyType: string)
	if not killerPlayer or not enemyModel then return end

	local baseXP = ENEMY_XP_REWARDS[enemyType] or 15
	local enemyLevel = enemyModel:GetAttribute("Level") or 1
	local totalXP = math.floor(baseXP * (1 + (enemyLevel - 1) * 0.2))

	if self.ProgressionService then
		self.ProgressionService:AddXP(killerPlayer, totalXP)
	end

	print(`⚔️ [EnemyService] {killerPlayer.Name} eliminó a {enemyModel.Name} (Nivel {enemyLevel}) y ganó +{totalXP} XP.`)
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
	humanoid.BreakJointsOnDeath = false -- Evita la explosión de físicas nativa de Roblox

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

	if self.EnemyAIService then
		self.EnemyAIService:RegisterEnemy(enemyModel, targetId)
	end

	-- Evento de Muerte
	humanoid.Died:Once(function()
		if enemyModel:GetAttribute("IsDead") then return end
		enemyModel:SetAttribute("IsDead", true)

		-- 1. Detener la IA inmediatamente
		if self.EnemyAIService then
			self.EnemyAIService:UnregisterEnemy(enemyModel)
		end

		-- 2. Efecto de Caída "Ragdoll": Colapso mediante físicas nativas
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		local hrp = enemyModel:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CanCollide = false
		end

		-- 3. Registrar Misión y Experiencia
		local creatorTag = humanoid:FindFirstChild("creator")
		local playerWhoKilled = creatorTag and creatorTag.Value

		if playerWhoKilled and playerWhoKilled:IsA("Player") then
			print(`💀 [EnemyService] {enemyName} fue eliminado por {playerWhoKilled.Name}!`)
			if self.QuestService then
				self.QuestService:RegisterKill(playerWhoKilled, targetId)
			end

			local enemyType = enemyModel:GetAttribute("EnemyType") or targetId
			self:GrantEnemyXP(playerWhoKilled, enemyModel, enemyType)
		end

		-- 4. Preparar silenciosamente el clon del respawn mientras el cadáver reposa
		task.defer(function()
			self:PreCloneEnemy(enemyName)
		end)

		-- 5. Limpiar el cadáver tras 3 segundos de reposo en el suelo
		task.delay(3, function()
			if enemyModel and enemyModel.Parent then
				enemyModel:Destroy()
			end
		end)

		-- 6. Reaparición usando el caché preparado
		task.delay(respawnTime, function()
			print(`⏳ [EnemyService] Iniciando respawn de '{enemyName}'...`)
			self:SpawnEnemy(enemyName, spawnCFrame, parentFolder)
		end)
	end)
end

function EnemyService:SpawnEnemy(enemyName: string, spawnCFrame: CFrame, parentFolder: Instance)
	local newEnemy = nil

	-- 1. Intentar recuperar el enemigo pre-clonado desde la cola (0 lag)
	if self.PreClonedEnemies and self.PreClonedEnemies[enemyName] and #self.PreClonedEnemies[enemyName] > 0 then
		newEnemy = table.remove(self.PreClonedEnemies[enemyName], 1)
	end

	-- 2. Fallback: Búsqueda y clonación tradicional si falló la cola
	if not newEnemy then
		local template = self.Templates and self.Templates[enemyName]

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

		if not template then
			warn(`⚠️ [EnemyService] No se encontró la plantilla de '{enemyName}'.`)
			return
		end

		newEnemy = template:Clone()
		newEnemy:SetAttribute("Registered", nil)
	end

	-- Mover al mundo real (Operación ultraligera)
	newEnemy.Parent = parentFolder or Workspace:FindFirstChild("NPCs") or Workspace
	newEnemy:PivotTo(spawnCFrame)

	-- Registrar la nueva instancia creada
	task.defer(function()
		self:RegisterEnemy(newEnemy)
	end)

	print(`🔄 [EnemyService] '{newEnemy.Name}' ha reaparecido exitosamente.`)
end

return EnemyService
