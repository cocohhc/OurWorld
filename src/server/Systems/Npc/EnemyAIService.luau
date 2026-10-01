-- src/server/Systems/Npc/EnemyAIService.luau
-- Servicio central de IA Táctica para Enemigos con Knit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Importar módulo estático de configuración de IA
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = Shared:WaitForChild("Systems")
local NpcShared = Systems:WaitForChild("Npc")
local EnemyAIData = require(NpcShared:WaitForChild("EnemyAIData"))

local EnemyAIService = Knit.CreateService({
	Name = "EnemyAIService",
	Client = {},
})

export type ActiveEnemyState = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Config: EnemyAIData.EnemyAIConfig,
	State: "Idle" | "Patrol" | "Alert" | "Combat" | "Heal",
	TargetPlayer: Player?,
	LastAttackTime: number,
	LastHealTime: number,
	LastParryTime: number,
	OriginCFrame: CFrame,
}

local activeEnemies: { [Model]: ActiveEnemyState } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

---------------------------------------------------------------------------
-- MÉTODOS AUXILIARES Y LÍNEA DE VISTA (LoS)
---------------------------------------------------------------------------

-- Dibuja temporalmente la Hitbox de ataque en 3D (roja semitransparente)
local function VisualizeHitbox(cframe: CFrame, size: Vector3)
	local debugPart = Instance.new("Part")
	debugPart.Name = "DebugAttackHitbox"
	debugPart.Size = size
	debugPart.CFrame = cframe
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.Material = Enum.Material.ForceField
	debugPart.Color = Color3.fromRGB(255, 50, 50)
	debugPart.Transparency = 0.5
	debugPart.Parent = Workspace

	task.delay(0.35, function()
		if debugPart and debugPart.Parent then
			debugPart:Destroy()
		end
	end)
end

-- Dibuja temporalmente los rayos de visión LoS (Verde = Visible/Despejado, Naranja = Bloqueado/Fuera)
local function VisualizeRay(origin: Vector3, direction: Vector3, targetHit: boolean)
	local distance = direction.Magnitude
	if distance <= 0.1 then return end

	local rayPart = Instance.new("Part")
	rayPart.Name = "DebugVisionRay"
	rayPart.Size = Vector3.new(0.15, 0.15, distance)
	rayPart.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -distance / 2)
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.CanQuery = false
	rayPart.Material = Enum.Material.Neon
	rayPart.Color = if targetHit then Color3.fromRGB(0, 255, 120) else Color3.fromRGB(255, 140, 0)
	rayPart.Transparency = 0.4
	rayPart.Parent = Workspace

	task.delay(0.25, function()
		if rayPart and rayPart.Parent then
			rayPart:Destroy()
		end
	end)
end

-- Evalúa si la posición objetivo está dentro del cono de visión y sin muros intermedios
function EnemyAIService:HasLineOfSight(npc: Model, target: Model, config: EnemyAIData.EnemyAIConfig, isChasing: boolean?): boolean
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	local targetPart = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
	if not primaryPart or not targetPart then return false end

	local origin = primaryPart.Position
	local targetPos = targetPart.Position
	local direction = targetPos - origin
	local distance = direction.Magnitude

	-- 1. Descarte por distancia máxima de visión
	if distance > config.VisionDistance then
		return false
	end

	-- 2. Cono de visión (FOV)
	-- Respeta el punto ciego a menos que estés dentro del rango de alerta por proximidad (AlertDistance)
	if distance > config.AlertDistance then
		local forward = primaryPart.CFrame.LookVector
		local directionUnit = if distance > 0 then direction.Unit else Vector3.zero
		local dot = math.clamp(forward:Dot(directionUnit), -1, 1)
		local angle = math.deg(math.acos(dot))

		if angle > (config.FieldOfView / 2) then
			return false
		end
	end

	-- 3. Verificación de obstáculos físicos (Raycast)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { npc, target }

	local result = workspace:Raycast(origin, direction, raycastParams)
	local hasLoS = (result == nil)

	-- Visualizar la línea de vista del NPC en tiempo real
	VisualizeRay(origin, direction, hasLoS)

	return hasLoS
end

-- Encuentra al jugador visible más cercano dentro de la Línea de Vista
local function FindClosestVisibleTarget(enemyState: ActiveEnemyState): (Player?, number)
	local closestPlayer: Player? = nil
	local minDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - enemyState.RootPart.Position).Magnitude
				if dist < minDistance then
					local isChasing = (enemyState.State == "Combat" or enemyState.State == "Alert")
					if EnemyAIService:HasLineOfSight(enemyState.Model, character, enemyState.Config, isChasing) then
						minDistance = dist
						closestPlayer = player
					end
				end
			end
		end
	end

	return closestPlayer, minDistance
end

local function GetDistanceToClosestPlayer(enemyState: ActiveEnemyState): number
	local minDistance = math.huge
	if not enemyState.RootPart then return minDistance end
	local npcPos = enemyState.RootPart.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - npcPos).Magnitude
				if dist < minDistance then
					minDistance = dist
				end
			end
		end
	end

	return minDistance
end

---------------------------------------------------------------------------
-- LÓGICA TÁCTICA Y FSM DE ENEMIGOS
---------------------------------------------------------------------------

local function ExecuteAttack(enemyState: ActiveEnemyState, targetCharacter: Model)
	local now = os.clock()
	if now - enemyState.LastAttackTime < enemyState.Config.AttackCooldown then
		return
	end

	enemyState.LastAttackTime = now
	local root = enemyState.RootPart

	-- Calcular CFrame y dimensión de la Hitbox en 3D en dirección del ataque
	local attackRange = enemyState.Config.AttackRange
	local hitboxSize = Vector3.new(5, 6, attackRange)
	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -attackRange / 2)

	-- Dibujar Hitbox visual de ataque en Workspace
	VisualizeHitbox(hitboxCFrame, hitboxSize)

	-- Detección física 3D en área
	overlapParams.FilterDescendantsInstances = { enemyState.Model }
	local partsInBox = Workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)

	local hitHumanoids: { [Humanoid]: boolean } = {}
	local hitCount = 0

	for _, part in ipairs(partsInBox) do
		local charModel = part:FindFirstAncestorOfClass("Model")
		if charModel and charModel ~= enemyState.Model then
			local hum = charModel:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not hitHumanoids[hum] then
				hitHumanoids[hum] = true
				hitCount += 1
				hum:TakeDamage(10)
				print(string.format("⚔️ [EnemyAIService] [HITBOX] %s asestó un golpe de 10 DMG a '%s'", enemyState.Model.Name, charModel.Name))
			end
		end
	end

	if hitCount == 0 then
		print(string.format("💨 [EnemyAIService] [HITBOX] %s atacó al aire (el objetivo salió de la Hitbox)", enemyState.Model.Name))
	end
end

local function ExecuteHeal(enemyState: ActiveEnemyState)
	local now = os.clock()
	if now - enemyState.LastHealTime < enemyState.Config.HealCooldown then
		return
	end

	enemyState.LastHealTime = now
	enemyState.State = "Heal"
	print(string.format("[EnemyAIService] [HEAL] %s ejecutando curación táctica (+%d HP)", enemyState.Model.Name, enemyState.Config.HealAmount))

	local hum = enemyState.Humanoid
	hum.Health = math.min(hum.MaxHealth, hum.Health + enemyState.Config.HealAmount)

	task.delay(1.5, function()
		if enemyState.State == "Heal" then
			enemyState.State = "Combat"
		end
	end)
end

local function UpdateEnemyAI(enemyState: ActiveEnemyState)
	local hum = enemyState.Humanoid
	local root = enemyState.RootPart

	if not hum or hum.Health <= 0 or not root then
		return
	end

	-- 1. Evaluar curación táctica por umbral de salud
	local hpPercent = hum.Health / hum.MaxHealth
	if enemyState.Config.CanHeal and hpPercent <= enemyState.Config.HealThreshold then
		local now = os.clock()
		if now - enemyState.LastHealTime >= enemyState.Config.HealCooldown then
			ExecuteHeal(enemyState)
			return
		end
	end

	-- 2. Escaneo de objetivos en Línea de Vista
	local targetPlayer, dist = FindClosestVisibleTarget(enemyState)

	if targetPlayer then
		enemyState.TargetPlayer = targetPlayer
		local targetChar = targetPlayer.Character
		if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
			local targetHRP = targetChar.HumanoidRootPart

			if dist <= enemyState.Config.AttackRange then
				-- Detenerse para atacar cuando está dentro del alcance
				enemyState.State = "Combat"
				hum:MoveTo(root.Position)
				ExecuteAttack(enemyState, targetChar)
			else
				-- Persecución continua
				enemyState.State = "Combat"
				hum.WalkSpeed = enemyState.Config.ChaseSpeed
				hum:MoveTo(targetHRP.Position)
				print(string.format("🏃 [EnemyAIService] [MOVE] %s persiguiendo a '%s' (Distancia: %.1f studs)", enemyState.Model.Name, targetPlayer.Name, dist))
			end
		end
	else
		-- 3. Retorno continuo a la posición de origen si no hay objetivo en vista
		local distToOrigin = (root.Position - enemyState.OriginCFrame.Position).Magnitude

		if distToOrigin > 2.5 then
			if enemyState.State ~= "Idle" then
				print(string.format("[EnemyAIService] [DEBUG] %s perdió la línea de vista. Regresando a origen.", enemyState.Model.Name))
			end
			enemyState.State = "Idle"
			enemyState.TargetPlayer = nil
			hum.WalkSpeed = enemyState.Config.PatrolSpeed
			hum:MoveTo(enemyState.OriginCFrame.Position)
			print(string.format("🚶 [EnemyAIService] [MOVE] %s retornando a origen (Distancia restante: %.1f studs)", enemyState.Model.Name, distToOrigin))
		else
			if enemyState.State ~= "Idle" then
				enemyState.State = "Idle"
				enemyState.TargetPlayer = nil
				hum:MoveTo(root.Position)
				print(string.format("📍 [EnemyAIService] [MOVE] %s llegó a su punto de origen.", enemyState.Model.Name))
			end
		end
	end
end

---------------------------------------------------------------------------
-- REGISTRO Y BUCLE PRINCIPAL CON THROTTLING
---------------------------------------------------------------------------

function EnemyAIService:RegisterEnemy(enemyModel: Model, enemyType: string?)
	local hum = enemyModel:FindFirstChildOfClass("Humanoid")
	local root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart

	if not hum or not root then
		warn(string.format("[EnemyAIService] No se pudo registrar %s: falta Humanoid o PrimaryPart", enemyModel.Name))
		return
	end

	-- Forzar propiedad de red al servidor únicamente si la parte no está anclada
	if root:IsA("BasePart") and not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	local config = EnemyAIData.GetConfig(enemyType or enemyModel.Name)

	local state: ActiveEnemyState = {
		Model = enemyModel,
		Humanoid = hum,
		RootPart = root,
		Config = config,
		State = "Idle",
		TargetPlayer = nil,
		LastAttackTime = 0,
		LastHealTime = 0,
		LastParryTime = 0,
		OriginCFrame = root.CFrame,
	}

	activeEnemies[enemyModel] = state
	print(string.format("[EnemyAIService] Enemigo registrado exitosamente: %s (Tipo: %s)", enemyModel.Name, enemyType or enemyModel.Name))

	hum.Died:Connect(function()
		activeEnemies[enemyModel] = nil
		print(string.format("[EnemyAIService] Enemigo removido por muerte: %s", enemyModel.Name))
	end)
end

function EnemyAIService:UnregisterEnemy(enemyModel: Model)
	if activeEnemies[enemyModel] then
		activeEnemies[enemyModel] = nil
		print(string.format("[EnemyAIService] Enemigo desregistrado: %s", enemyModel.Name))
	end
end

function EnemyAIService:KnitStart()
	print("[EnemyAIService] Servicio de IA Táctica iniciado. Bucle principal activo.")

	-- Bucle principal optimizado con Throttling
	task.spawn(function()
		while true do
			for model, enemyState in pairs(activeEnemies) do
				if model and model.Parent then
					local rawDist = GetDistanceToClosestPlayer(enemyState)
					local tickInterval = 0.5

					if rawDist < 30 then
						tickInterval = 0.1 -- Frecuencia alta (Jugador cercano < 30 studs)
					elseif rawDist < 100 then
						tickInterval = 0.5 -- Frecuencia media (Alerta / Patrulla)
					else
						tickInterval = 2.0 -- Frecuencia baja / Suspendida
					end

					task.spawn(function()
						UpdateEnemyAI(enemyState)
					end)

					task.wait(tickInterval / math.max(1, #activeEnemies))
				else
					activeEnemies[model] = nil
				end
			end
			task.wait(0.1)
		end
	end)
end

function EnemyAIService:KnitInit()
	print("[EnemyAIService] Inicializando servicio de IA...")
end

return EnemyAIService
