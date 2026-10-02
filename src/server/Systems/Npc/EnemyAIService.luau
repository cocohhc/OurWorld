-- src/server/Systems/Npc/EnemyAIService.luau
-- Servicio central de IA Táctica para Enemigos con Toma de Decisiones Natural y Knit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

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
	State: "Idle" | "Patrol" | "Alert" | "Combat" | "Heal" | "Flee" | "Parrying",
	TargetPlayer: Player?,
	LastAttackTime: number,
	LastHealTime: number,
	LastParryTime: number,
	LastDodgeTime: number,
	OriginCFrame: CFrame,

	-- Sistema de Decisiones Naturales y Reacción
	CurrentPlan: string?,
	PlanEndTime: number?,
	CircleDirection: number?,
	StrafeAngleOffset: number?,

	-- Buffer de Retardo de Reacción Humana
	PendingPlan: string?,
	ReactionExecuteTime: number?,
}

local activeEnemies: { [Model]: ActiveEnemyState } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local DODGE_RADIATION_COST = 25
local DODGE_COOLDOWN = 3.5

---------------------------------------------------------------------------
-- VISUALIZACIÓN Y RAYCASTING (LoS)
---------------------------------------------------------------------------

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

function EnemyAIService:HasLineOfSight(npc: Model, target: Model, config: EnemyAIData.EnemyAIConfig, isChasing: boolean?): boolean
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	local targetPart = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
	if not primaryPart or not targetPart then return false end

	local origin = primaryPart.Position
	local targetPos = targetPart.Position
	local direction = targetPos - origin
	local distance = direction.Magnitude

	if distance > config.VisionDistance then return false end

	-- CORRECCIÓN: Si la IA está en combate, alerta o huyendo (isChasing), omitimos el límite del cono de visión frontal.
	if distance > config.AlertDistance and not isChasing then
		local forward = primaryPart.CFrame.LookVector
		local directionUnit = if distance > 0 then direction.Unit else Vector3.zero
		local dot = math.clamp(forward:Dot(directionUnit), -1, 1)
		local angle = math.deg(math.acos(dot))

		if angle > (config.FieldOfView / 2) then
			return false
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { npc, target }

	local result = workspace:Raycast(origin, direction, raycastParams)
	local hasLoS = (result == nil)

	VisualizeRay(origin, direction, hasLoS)
	return hasLoS
end

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
					-- CORRECCIÓN: Añadido "Flee" para que no pierda de vista al jugador al darle la espalda.
					local isChasing = (enemyState.State == "Combat" or enemyState.State == "Alert" or enemyState.State == "Flee")
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
-- MECÁNICAS REACTIVAS: ESQUIVE Y PARRY
---------------------------------------------------------------------------

local function TryEnemyDodge(enemyState: ActiveEnemyState, threatPosition: Vector3?): boolean
	local enemyModel = enemyState.Model
	local hum = enemyState.Humanoid
	local hrp = enemyState.RootPart

	if not hum or hum.Health <= 0 or not hrp then return false end
	if enemyModel:GetAttribute("IsDodging") or enemyModel:GetAttribute("IsParrying") then return false end

	local now = os.clock()
	if now - enemyState.LastDodgeTime < DODGE_COOLDOWN then return false end

	local currentRad = enemyModel:GetAttribute("Radiation") or 100
	if currentRad < DODGE_RADIATION_COST then return false end

	-- Consumir radiación y activar i-frames
	enemyModel:SetAttribute("Radiation", currentRad - DODGE_RADIATION_COST)
	enemyState.LastDodgeTime = now
	enemyModel:SetAttribute("IsDodging", true)

	local sideSign = if math.random() > 0.5 then 1 else -1
	local sideVector = hrp.CFrame.RightVector * sideSign
	local moveDir = Vector3.new(sideVector.X, 0, sideVector.Z)

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	local attachment = hrp:FindFirstChild("DodgeAttachment") or Instance.new("Attachment")
	attachment.Name = "DodgeAttachment"
	attachment.Parent = hrp

	local initialVelocity = moveDir * 32
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = 1e6
	linearVelocity.VectorVelocity = initialVelocity
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = hrp

	local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local speedTween = TweenService:Create(linearVelocity, tweenInfo, { VectorVelocity = Vector3.zero })
	speedTween:Play()

	speedTween.Completed:Connect(function()
		linearVelocity:Destroy()
		attachment:Destroy()
	end)

	task.delay(0.35, function()
		if enemyModel then
			enemyModel:SetAttribute("IsDodging", nil)
		end
	end)

	print(string.format("👻 [EnemyAIService] %s ejecutó esquive lateral.", enemyModel.Name))
	return true
end

local function TryEnemyParry(enemyState: ActiveEnemyState): boolean
	local now = os.clock()
	local config = enemyState.Config

	if now - enemyState.LastParryTime < config.ParryCooldown then return false end
	if math.random() > config.ParryChance then return false end

	enemyState.LastParryTime = now
	enemyState.State = "Parrying"
	enemyState.Model:SetAttribute("IsParrying", true)

	print(string.format("🛡️ [EnemyAIService] [PARRY] %s levanta postura defensiva.", enemyState.Model.Name))

	task.delay(0.65, function()
		if enemyState.Model then
			enemyState.Model:SetAttribute("IsParrying", nil)
			if enemyState.State == "Parrying" then
				enemyState.State = "Combat"
			end
		end
	end)

	return true
end

---------------------------------------------------------------------------
-- SISTEMA DE EVALUACIÓN DE UTILIDAD Y RETARDI DE REACCIÓN
---------------------------------------------------------------------------

-- Calcula los puntajes de utilidad para determinar la acción óptima del NPC
local function CalculateActionUtilities(enemyState: ActiveEnemyState, targetHrp: BasePart, distance: number): { [string]: number }
	local config = enemyState.Config
	local now = os.clock()
	local hum = enemyState.Humanoid
	local hpPercent = hum.Health / hum.MaxHealth

	local targetModel = targetHrp.Parent
	local playerLastAttack = targetModel and targetModel:GetAttribute("LastAttackTime") or 0
	local timeSincePlayerAttack = now - playerLastAttack

	local scores: { [string]: number } = {
		Approach = 0,
		Retreat = 0,
		Circle = 0,
		Punish = 0,
	}

	-- 1. Evaluador de Castigo (Punish): Jugador falló un ataque o está vulnerable
	if timeSincePlayerAttack < 0.85 and distance <= 20 then
		scores.Punish = (1.0 - (distance / 20)) * 80 * config.Aggressiveness
	end

	-- 2. Evaluador de Aproximación (Approach)
	local approachBase = math.clamp((distance - config.AttackRange) / 30, 0, 1) * 50
	scores.Approach = approachBase * config.Aggressiveness

	-- 3. Evaluador de Flanqueo (Circle / Strafe)
	local circleRangeFactor = if distance >= 8 and distance <= 22 then 1 else 0.3
	scores.Circle = 40 * config.FlankPreference * circleRangeFactor

	-- Ajuste post-ataque propio (evita spam frontal continuo)
	if now - enemyState.LastAttackTime < 1.2 then
		scores.Circle += 25
		scores.Retreat += 30
	end

	-- 4. Evaluador de Retirada Estratégica (Retreat)
	if distance < 7 then
		scores.Retreat += (1 - (distance / 7)) * 45
	end

	if config.Archetype == "Evasive" then
		scores.Retreat += 20 * (1 - hpPercent)
		scores.Circle += 15
	elseif config.Archetype == "Aggressive" then
		scores.Approach += 25
		scores.Punish += 20
		scores.Retreat *= 0.3
	elseif config.Archetype == "Tactical" then
		-- Prioriza el flanqueo constante y mantener rango seguro tras golpes
		scores.Circle += 35
		if timeSincePlayerAttack < 0.6 then
			scores.Retreat += 25
		end
	end

	-- Ruido estocástico (+/- 10%) para impredecibilidad
	for action, score in pairs(scores) do
		scores[action] = score * (0.9 + (math.random() * 0.2))
	end

	return scores
end

-- Selecciona el plan con mayor puntaje de utilidad
local function SelectBestUtilityPlan(enemyState: ActiveEnemyState, targetHrp: BasePart, distance: number): string
	local scores = CalculateActionUtilities(enemyState, targetHrp, distance)
	local bestPlan = "Approach"
	local highestScore = -math.huge

	for action, score in pairs(scores) do
		if score > highestScore then
			highestScore = score
			bestPlan = action
		end
	end

	return bestPlan
end

-- Programa un cambio de plan respetando el tiempo de reacción humana de la IA
local function QueueTacticalPlan(enemyState: ActiveEnemyState, targetHrp: BasePart, distance: number)
	local now = os.clock()
	local desiredPlan = SelectBestUtilityPlan(enemyState, targetHrp, distance)

	-- Si es un plan de castigo inmediato, reduce la latencia de reacción
	local reactionDelay = enemyState.Config.ReactionTime
	if desiredPlan == "Punish" then
		reactionDelay *= 0.5
	end

	enemyState.PendingPlan = desiredPlan
	enemyState.ReactionExecuteTime = now + reactionDelay
end

---------------------------------------------------------------------------
-- ACCIONES Y MOVIMIENTO ORGÁNICO
---------------------------------------------------------------------------

local function ExecuteAttack(enemyState: ActiveEnemyState, targetCharacter: Model)
	local now = os.clock()
	if now - enemyState.LastAttackTime < enemyState.Config.AttackCooldown then
		return
	end

	enemyState.LastAttackTime = now
	local root = enemyState.RootPart

	local attackRange = enemyState.Config.AttackRange
	local hitboxSize = Vector3.new(5, 6, attackRange)
	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -attackRange / 2)

	VisualizeHitbox(hitboxCFrame, hitboxSize)

	overlapParams.FilterDescendantsInstances = { enemyState.Model }
	local partsInBox = Workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)

	local hitHumanoids: { [Humanoid]: boolean } = {}
	local hitCount = 0

	for _, part in ipairs(partsInBox) do
		local charModel = part:FindFirstAncestorOfClass("Model")
		if charModel and charModel ~= enemyState.Model then
			local hum = charModel:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not hitHumanoids[hum] and not charModel:GetAttribute("IsDodging") then

				-- Si el jugador está haciendo parry, anular daño y aturdir al NPC
				if charModel:GetAttribute("IsParrying") then
					print(string.format("💥 [EnemyAIService] ¡%s fue BLOQUEADO por el parry de %s!", enemyState.Model.Name, charModel.Name))
					return
				end

				hitHumanoids[hum] = true
				hitCount += 1
				hum:TakeDamage(10)
				print(string.format("⚔️️ [EnemyAIService] %s infligió 10 DMG a '%s'", enemyState.Model.Name, charModel.Name))
			end
		end
	end
end

local function ExecuteHeal(enemyState: ActiveEnemyState)
	local now = os.clock()
	if now - enemyState.LastHealTime < enemyState.Config.HealCooldown then
		return
	end

	enemyState.LastHealTime = now
	enemyState.State = "Heal"
	print(string.format("💊 [EnemyAIService] [HEAL] %s se cura (+%d HP)", enemyState.Model.Name, enemyState.Config.HealAmount))

	local hum = enemyState.Humanoid
	hum.Health = math.min(hum.MaxHealth, hum.Health + enemyState.Config.HealAmount)

	task.delay(1.2, function()
		if enemyState.State == "Heal" then
			enemyState.State = "Combat"
		end
	end)
end

-- Desplazamiento orgánico con trayectorias en arco y variaciones estocásticas
local function ExecuteTacticalMovement(enemyState: ActiveEnemyState, targetHrp: BasePart, distance: number)
	local hrp = enemyState.RootPart
	local hum = enemyState.Humanoid
	if not hrp or not hum or hum.Health <= 0 then return end

	local now = os.clock()

	-- Procesar buffer de reacción pendiente
	if enemyState.PendingPlan and enemyState.ReactionExecuteTime and now >= enemyState.ReactionExecuteTime then
		enemyState.CurrentPlan = enemyState.PendingPlan
		enemyState.PendingPlan = nil
		enemyState.ReactionExecuteTime = nil
		enemyState.PlanEndTime = now + (math.random(14, 26) / 10)
		enemyState.CircleDirection = if math.random() > 0.5 then 1 else -1
		enemyState.StrafeAngleOffset = (math.random() - 0.5) * 0.4 -- Desviación angular orgánica en radianes

		print(string.format("🧠 [EnemyAIService] [DECISION] %s ejecutó cambio de plan a '%s' (Reacción completada)", enemyState.Model.Name, enemyState.CurrentPlan))

		if enemyState.CurrentPlan == "Retreat" and distance < 10 then
			if not TryEnemyParry(enemyState) then
				TryEnemyDodge(enemyState, targetHrp.Position)
			end
		end
	end

	-- Si expiró el plan actual o no hay ninguno activo, evaluar nuevas utilidades
	if not enemyState.CurrentPlan or now >= (enemyState.PlanEndTime or 0) then
		if not enemyState.PendingPlan then
			QueueTacticalPlan(enemyState, targetHrp, distance)
		end
	end

	local plan = enemyState.CurrentPlan

	-- Si está procesando una reacción y no tiene un plan activo, se queda a la expectativa
	if not plan and enemyState.PendingPlan then
		plan = "Hold"
	end

    plan = plan or "Approach"
	local targetPos = targetHrp.Position

	if plan == "Hold" then
		-- Simula la "duda" táctica: velocidad casi cero, pero encara al jugador
		hum.WalkSpeed = 2
		hum:MoveTo(hrp.Position + (targetPos - hrp.Position).Unit * 0.5)
    elseif plan == "Approach" or plan == "Punish" then
		hum.WalkSpeed = if plan == "Punish" then enemyState.Config.ChaseSpeed + 3 else enemyState.Config.ChaseSpeed

		-- Ligera desviación lateral estocástica para no avanzar en una línea perfectamente recta
		local toTarget = (targetPos - hrp.Position)
		local offsetVector = Vector3.new(-toTarget.Z, 0, toTarget.X).Unit * (enemyState.StrafeAngleOffset or 0) * distance
		hum:MoveTo(targetPos + offsetVector)

	elseif plan == "Retreat" then
		hum.WalkSpeed = math.max(10, enemyState.Config.ChaseSpeed - 2)
		local awayDir = (hrp.Position - targetPos)
		awayDir = if awayDir.Magnitude > 0 then awayDir.Unit else -hrp.CFrame.LookVector

		local retreatDestination = hrp.Position + (awayDir * 14)
		hum:MoveTo(retreatDestination)

	elseif plan == "Circle" then
		hum.WalkSpeed = enemyState.Config.ChaseSpeed
		local toPlayer = (targetPos - hrp.Position)
		if toPlayer.Magnitude > 0 then
			-- Flanqueo curvilíneo alrededor del jugador
			local tangent = Vector3.new(-toPlayer.Z, 0, toPlayer.X).Unit * (enemyState.CircleDirection or 1)
			local circleRadius = math.clamp(distance, 8, 14)
			local circleDestination = targetPos + (tangent * circleRadius) + (toPlayer.Unit * 3)
			hum:MoveTo(circleDestination)
		end
	end
end

---------------------------------------------------------------------------
-- BUCLE Y ACTUALIZACIÓN PRINCIPAL
---------------------------------------------------------------------------

local function UpdateEnemyAI(enemyState: ActiveEnemyState)
	local hum = enemyState.Humanoid
	local root = enemyState.RootPart

	if not hum or hum.Health <= 0 or not root then return end

	local now = os.clock()

	-- Regeneración de Radiación
	local currentRad = enemyState.Model:GetAttribute("Radiation") or 100
	local maxRad = enemyState.Model:GetAttribute("MaxRadiation") or 100
	local regenRate = enemyState.Model:GetAttribute("RadiationRegenRate") or 3
	if currentRad < maxRad then
		enemyState.Model:SetAttribute("Radiation", math.min(maxRad, currentRad + (regenRate * 0.2)))
	end

	-- NUEVO: Regeneración de Vida Natural (Pasiva fuera de combate)
	if enemyState.State ~= "Combat" and hum.Health < hum.MaxHealth then
		local lastRegen = enemyState.Model:GetAttribute("LastHpRegenTime") or 0
		if now - lastRegen >= 1.5 then
			enemyState.Model:SetAttribute("LastHpRegenTime", now)
			local hpRegenAmount = hum.MaxHealth * 0.04 -- Recupera 4% cada 1.5s
			hum.Health = math.min(hum.MaxHealth, hum.Health + hpRegenAmount)
		end
	end

	local hpPercent = hum.Health / hum.MaxHealth

	-- 1. Estado de Huida por Salud Crítica
	if hpPercent <= enemyState.Config.FleeThreshold then
		enemyState.State = "Flee"
		local targetPlayer, dist = FindClosestVisibleTarget(enemyState)

		if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local targetHRP = targetPlayer.Character.HumanoidRootPart
			hum.WalkSpeed = enemyState.Config.FleeSpeed

			local awayDir = (root.Position - targetHRP.Position)
			awayDir = if awayDir.Magnitude > 0 then awayDir.Unit else -root.CFrame.LookVector

			hum:MoveTo(root.Position + (awayDir * 22))

			if dist < 10 then
				TryEnemyDodge(enemyState, targetHRP.Position)
			end
			return
		end
	end

	-- 2. Curación Táctica
	if enemyState.Config.CanHeal and hpPercent <= enemyState.Config.HealThreshold then
		if now - enemyState.LastHealTime >= enemyState.Config.HealCooldown then
			ExecuteHeal(enemyState)
			return
		end
	end

	-- 3. Escaneo y Movimiento Táctico
	local targetPlayer, dist = FindClosestVisibleTarget(enemyState)

	if targetPlayer then
		enemyState.TargetPlayer = targetPlayer
		local targetChar = targetPlayer.Character
		if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
			local targetHRP = targetChar.HumanoidRootPart

			-- Reacción defensiva si el jugador ataca cerca
			local playerLastAttack = targetChar:GetAttribute("LastAttackTime") or 0
			if (now - playerLastAttack) < 0.25 and dist <= enemyState.Config.AttackRange + 3 then
				if not TryEnemyParry(enemyState) then
					TryEnemyDodge(enemyState, targetHRP.Position)
				end
			end

			if dist <= enemyState.Config.AttackRange then
				enemyState.State = "Combat"
				hum:MoveTo(root.Position)
				ExecuteAttack(enemyState, targetChar)
			else
				enemyState.State = "Combat"
				ExecuteTacticalMovement(enemyState, targetHRP, dist)
			end
		end
	else
		-- 4. Retorno a Punto de Origen de manera Inteligente
		if enemyState.State == "Flee" and hpPercent <= enemyState.Config.FleeThreshold then
			hum.WalkSpeed = 0
			return
		end

		local distToOrigin = (root.Position - enemyState.OriginCFrame.Position).Magnitude

		if distToOrigin > 2.5 then
			enemyState.State = "Idle"
			enemyState.TargetPlayer = nil
			enemyState.CurrentPlan = nil
			enemyState.PendingPlan = nil
			hum.WalkSpeed = enemyState.Config.PatrolSpeed

			-- NUEVO: Mirar alrededor para analizar si hay jugadores (Permite que el cono de visión barra la zona)
			if math.random() < 0.3 then
				local randomAngle = math.rad(math.random(-120, 120))
				root.CFrame = root.CFrame * CFrame.Angles(0, randomAngle, 0)
			end

			-- NUEVO: Retorno seguro utilizando Pathfinding para no caer al vacío
			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true,
			})

			local success, _ = pcall(function()
				path:ComputeAsync(root.Position, enemyState.OriginCFrame.Position)
			end)

			if success and path.Status == Enum.PathStatus.Success then
				local waypoints = path:GetWaypoints()
				if #waypoints > 1 then
					local nextPoint = waypoints[2]
					hum:MoveTo(nextPoint.Position)
					if nextPoint.Action == Enum.PathWaypointAction.Jump then
						hum.Jump = true
					end
				else
					hum:MoveTo(enemyState.OriginCFrame.Position)
				end
			else
				-- Fallback seguro: Si no hay camino (ej. abismo), no se lanza a lo ciego.
				if distToOrigin < 15 then
					hum:MoveTo(enemyState.OriginCFrame.Position)
				else
					hum.WalkSpeed = 0 -- Se queda quieto a la expectativa
				end
			end
		else
			if enemyState.State ~= "Idle" then
				enemyState.State = "Idle"
				enemyState.TargetPlayer = nil
				enemyState.CurrentPlan = nil
				enemyState.PendingPlan = nil
				hum:MoveTo(root.Position)
			end
		end
	end
end

---------------------------------------------------------------------------
-- REGISTRO Y BUCLE CON THROTTLING
---------------------------------------------------------------------------

function EnemyAIService:RegisterEnemy(enemyModel: Model, enemyType: string?)
	local hum = enemyModel:FindFirstChildOfClass("Humanoid")
	local root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart

	if not hum or not root then
		warn(string.format("[EnemyAIService] No se pudo registrar %s: falta Humanoid o PrimaryPart", enemyModel.Name))
		return
	end

	if root:IsA("BasePart") and not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	enemyModel:SetAttribute("MaxRadiation", 100)
	enemyModel:SetAttribute("Radiation", 100)
	enemyModel:SetAttribute("RadiationRegenRate", 3)

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
		LastDodgeTime = 0,
		OriginCFrame = root.CFrame,
		CurrentPlan = nil,
		PlanEndTime = 0,
		CircleDirection = 1,
		StrafeAngleOffset = 0,
		PendingPlan = nil,
		ReactionExecuteTime = nil,
	}

	activeEnemies[enemyModel] = state
	print(string.format("[EnemyAIService] Enemigo registrado: %s (Arquetipo: %s)", enemyModel.Name, config.Archetype))

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
	print("[EnemyAIService] Servicio de IA Táctica Avanzada iniciado.")

	task.spawn(function()
		while true do
			local now = os.clock()

			for model, enemyState in pairs(activeEnemies) do
				if model and model.Parent then
					local rawDist = GetDistanceToClosestPlayer(enemyState)
					local tickInterval = 0.5

					if rawDist < 30 then
						tickInterval = 0.1
					elseif rawDist < 100 then
						tickInterval = 0.5
					else
						tickInterval = 2.0
					end

					-- Evaluación de tick independiente por entidad (no bloquea el loop)
					if now - (enemyState.LastUpdateTick or 0) >= tickInterval then
						enemyState.LastUpdateTick = now
						task.spawn(function()
							UpdateEnemyAI(enemyState)
						end)
					end
				else
					activeEnemies[model] = nil
				end
			end
			-- Tick base de gestión (siempre rápido)
			task.wait(0.1)
		end
	end)
end

function EnemyAIService:KnitInit()
	print("[EnemyAIService] Inicializando servicio de IA Táctica...")
end

return EnemyAIService
