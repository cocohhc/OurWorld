local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local sharedInventory = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Inventory")
local ItemData = require(sharedInventory:WaitForChild("ItemData"))

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		-- Definir evento de RemoteSignal para que el cliente solicite el ataque
		AttackRequested = Knit.CreateSignal(),
	},
})

-- Cooldowns para prevenir spam/exploits
local playerCooldowns = {}

function CombatService:KnitStart()
	print("[CombatService] Servicio de combate iniciado.")

	self.Client.AttackRequested:Connect(function(player, weaponId)
		self:ExecuteAttack(player, weaponId)
	end)
end

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

	local rootPart = character.HumanoidRootPart
	local hitboxSize = weaponConfig.HitboxSize or Vector3.new(5, 5, 5)
	local offset = weaponConfig.HitboxOffset or 4
	local attackDuration = 0.25 -- Ventana de tiempo en la que el golpe está activo

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.CollisionGroup = "Default"

	local hitHumanoids = {}
	local startTime = os.clock()

	-- Bucle de detección activa (Sigue al jugador mientras ataca)
	task.spawn(function()
		while (os.clock() - startTime) < attackDuration do
			if not character or not rootPart.Parent then break end

			-- La CFrame se recalcula en CADA iteración basada en la posición actual
			local currentHitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -offset)

			-- Visualización rápida
			self:VisualizeHitbox(currentHitboxCFrame, hitboxSize)

			-- Detectar impactos
			local partsInBox = workspace:GetPartBoundsInBox(currentHitboxCFrame, hitboxSize, overlapParams)

			for _, part in ipairs(partsInBox) do
				local enemyModel = part.Parent
				if enemyModel and enemyModel:IsA("Model") then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")

					if enemyHumanoid and enemyHumanoid.Health > 0 and not hitHumanoids[enemyHumanoid] then
						hitHumanoids[enemyHumanoid] = true
						enemyHumanoid:TakeDamage(weaponConfig.Damage or 10)
						print(`💥 [COMBATE] {player.Name} infligió {weaponConfig.Damage} de daño a {enemyModel.Name}!`)
					end
				end
			end

			task.wait(0.05) -- Comprobación cada 50ms durante el ataque
		end
	end)
end

-- Muestra una caja roja en el mapa que se desvanece rápido
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

return CombatService
