-- src/server/Systems/Combat/CombatService.luau
-- Servicio central de combate melee, a distancia (físicas/fuerza) y esquive con radiación.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local sharedInventory = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Inventory")
local ItemData = require(sharedInventory:WaitForChild("ItemData"))

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		AttackRequested = Knit.CreateSignal(),
		RangedShotRequested = Knit.CreateSignal(),
		RadiationUpdated = Knit.CreateSignal(),
	},
})

local playerCooldowns = {}
local DODGE_RADIATION_COST = 25
local DODGE_IFRAME_DURATION = 0.35

function CombatService:KnitStart()
	self.PlayerDataManager = Knit.GetService("PlayerDataManager")
	self.EnemyService = Knit.GetService("EnemyService")

	print("⚔️ [CombatService] Servicio de combate iniciado.")

	-- Escuchar petición de ataque melee tradicional
	self.Client.AttackRequested:Connect(function(player, weaponId)
		self:ExecuteAttack(player, weaponId)
	end)

	-- Escuchar petición de disparo a distancia
	self.Client.RangedShotRequested:Connect(function(player, weaponId, origin, direction, chargeRatio)
		self:ExecuteRangedShot(player, weaponId, origin, direction, chargeRatio)
	end)

	-- Bucle de regeneración pasiva de Radiación para los jugadores
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				self:RegenerateRadiation(player, 1)
			end
		end
	end)
end

-- Regeneración pasiva y actualización de radiación
function CombatService:RegenerateRadiation(player: Player, deltaTime: number)
	if not self.PlayerDataManager then return end
	local slot = self.PlayerDataManager:GetActiveSlot(player)
	if not slot then return end

	local maxRad = slot.MaxRadiation or 100
	local regenRate = slot.RadiationRegenRate or 2
	local currentRad = slot.Radiation or maxRad

	if currentRad < maxRad then
		local newRad = math.min(maxRad, currentRad + (regenRate * deltaTime))
		self.PlayerDataManager:SetRadiation(player, newRad)
		self.Client.RadiationUpdated:Fire(player, slot.Radiation, maxRad)
	end
end

-- Ejecución de Ataque Melee (Manteniendo detección por GetPartBoundsInBox y visualización)
function CombatService:ExecuteAttack(player: Player, weaponId: string)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local weaponConfig = ItemData.Items[weaponId]
	if not weaponConfig then return end

	-- Control de Cooldown
	local now = os.clock()
	local lastAttack = playerCooldowns[player] or 0
	if now - lastAttack < (weaponConfig.Cooldown or 0.5) then
		return
	end
	playerCooldowns[player] = now

	-- Registrar tiempo de ataque para la IA táctica (Plan "Punish")
	character:SetAttribute("LastAttackTime", now)

	local rootPart = character.HumanoidRootPart
	local hitboxSize = weaponConfig.HitboxSize or Vector3.new(5, 5, 5)
	local offset = weaponConfig.HitboxOffset or 4
	local attackDuration = 0.25

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.CollisionGroup = "Default"

	local hitHumanoids = {}
	local startTime = os.clock()

	-- Bucle de detección activa durante el golpe
	task.spawn(function()
		while (os.clock() - startTime) < attackDuration do
			if not character or not rootPart.Parent then break end

			local currentHitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -offset)

			-- Visualización de la hitbox
			self:VisualizeHitbox(currentHitboxCFrame, hitboxSize)

			-- Detectar impactos
			local partsInBox = workspace:GetPartBoundsInBox(currentHitboxCFrame, hitboxSize, overlapParams)

			for _, part in ipairs(partsInBox) do
				local enemyModel = part.Parent
				if enemyModel and enemyModel:IsA("Model") then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")

					if enemyHumanoid and enemyHumanoid.Health > 0 and not hitHumanoids[enemyHumanoid] then
						-- Comprobar si la víctima no está esquivando (i-frames)
						if not enemyModel:GetAttribute("IsDodging") then
							hitHumanoids[enemyHumanoid] = true

							-- Aplicar etiqueta del atacante para reconocimiento en EnemyService / QuestService
							local creatorTag = enemyHumanoid:FindFirstChild("creator")
							if not creatorTag then
								creatorTag = Instance.new("ObjectValue")
								creatorTag.Name = "creator"
								creatorTag.Parent = enemyHumanoid
							end
							creatorTag.Value = player

							local damage = weaponConfig.Damage or 10
							enemyHumanoid:TakeDamage(damage)
							print(`💥 [COMBATE] {player.Name} infligió {damage} de daño a {enemyModel.Name}!`)
						end
					end
				end
			end

			task.wait(0.05)
		end
	end)
end

-- Muestra la caja de colisión temporal
function CombatService:VisualizeHitbox(cframe: CFrame, size: Vector3)
	local box = Instance.new("Part")
	box.Size = size
	box.CFrame = cframe
	box.Anchored = true
	box.CanCollide = false
	box.Color = Color3.fromRGB(255, 50, 50)
	box.Material = Enum.Material.Neon
	box.Transparency = 0.5
	box.Parent = workspace

	local tween = TweenService:Create(box, TweenInfo.new(0.3), { Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		box:Destroy()
	end)
end

-- Ejecución de Esquive / Dash (Invocado desde el cliente)
function CombatService.Client:DodgeRequested(player: Player)
	local slot = self.Server.PlayerDataManager and self.Server.PlayerDataManager:GetActiveSlot(player)
	if not slot then return false end

	local character = player.Character
	if not character or character:GetAttribute("IsDodging") then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local currentRad = slot.Radiation or 100
	if currentRad < DODGE_RADIATION_COST then
		warn(`⚠️ [CombatService] {player.Name} no tiene suficiente radiación para esquivar ({currentRad}/{DODGE_RADIATION_COST}).`)
		return false
	end

	-- Consumir Radiación actualizando el atributo de Player
	self.Server.PlayerDataManager:SetRadiation(player, currentRad - DODGE_RADIATION_COST)
	self.Server.Client.RadiationUpdated:Fire(player, slot.Radiation, slot.MaxRadiation or 100)

	-- Activar fotogramas de invulnerabilidad (i-frames)
	character:SetAttribute("IsDodging", true)
	task.delay(DODGE_IFRAME_DURATION, function()
		if character then
			character:SetAttribute("IsDodging", nil)
		end
	end)

	return true
end

-- Procesamiento de disparo a distancia (Arco / Armas de fuego)
function CombatService:ExecuteRangedShot(player: Player, weaponId: string, origin: Vector3, direction: Vector3, chargeRatio: number)
	local weaponConfig = ItemData.Items[weaponId]
	if not weaponConfig or weaponConfig.WeaponType ~= "Ranged" then
		return
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Control de Cooldown
	local now = os.clock()
	local lastAttack = playerCooldowns[player] or 0
	if now - lastAttack < (weaponConfig.Cooldown or 0.5) then
		return
	end
	playerCooldowns[player] = now

	-- Registrar tiempo de ataque para la IA táctica (Plan "Punish")
	character:SetAttribute("LastAttackTime", now)

	-- Escalado por carga de fuerza
	local actualRatio = math.clamp(chargeRatio or 1, 0.1, 1)
	local baseDamage = weaponConfig.Damage or 20
	local totalDamage = math.floor(baseDamage * (0.5 + (actualRatio * 0.5)))

	-- Raycast de verificación inmediata
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local maxDistance = (weaponConfig.Velocity or 200) * 0.1
	local rayResult = Workspace:Raycast(origin, direction.Unit * maxDistance, raycastParams)

	if rayResult and rayResult.Instance then
		local hitModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
		if hitModel then
			local targetHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and not hitModel:GetAttribute("IsDodging") then
				local creatorTag = targetHumanoid:FindFirstChild("creator")
				if not creatorTag then
					creatorTag = Instance.new("ObjectValue")
					creatorTag.Name = "creator"
					creatorTag.Parent = targetHumanoid
				end
				creatorTag.Value = player

				targetHumanoid:TakeDamage(totalDamage)
				print(`🏹 [COMBATE A DISTANCIA] {player.Name} infligió {totalDamage} de daño a {hitModel.Name}!`)
			end
		end
	end
end

return CombatService
