-- src/client/Systems/Combat/CombatController.luau
-- Controlador cliente de combate melee, disparo cargado a distancia y esquive (Tecla F).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- RUTA NUEVA (Sistema Inventory dentro de Shared):
local sharedInventory = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("Systems")
	:WaitForChild("Inventory")

local ItemData = require(sharedInventory:WaitForChild("ItemData"))
local LocalPlayer = Players.LocalPlayer

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

function CombatController:KnitInit()
	self.IsCharging = false
	self.ChargeStartTime = 0
	self.CurrentWeaponId = nil
end

function CombatController:KnitStart()
	self.CombatService = Knit.GetService("CombatService")
	print("[CombatController] Controlador de combate cargado.")

	-- Detectar clics del mouse / toques y teclas de acción
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:OnInputStart()
		elseif input.KeyCode == Enum.KeyCode.F then
			self:TryDodge()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:OnInputEnd()
		end
	end)
end

-- Obtener la herramienta equipada actualmente en la mano e identificarla en ItemData
function CombatController:GetEquippedWeapon()
	local character = LocalPlayer.Character
	if not character then return nil, nil, nil end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if not equippedTool then return nil, nil, nil end

	for id, item in pairs(ItemData.Items) do
		if item.Name == equippedTool.Name then
			return id, item, equippedTool
		end
	end

	return nil, nil, equippedTool
end

-- Inicio de ataque melee o inicio de carga para armas a distancia
function CombatController:OnInputStart()
	local weaponId, weaponConfig = self:GetEquippedWeapon()
	if not weaponId or not weaponConfig then
		self:TryAttack()
		return
	end

	if weaponConfig.WeaponType == "Ranged" then
		self.IsCharging = true
		self.ChargeStartTime = os.clock()
		self.CurrentWeaponId = weaponId
		print("🏹 [CombatController] Cargando disparo a distancia...")
	else
		self:TryAttack()
	end
end

-- Fin de entrada (Liberación del disparo a distancia)
function CombatController:OnInputEnd()
	if not self.IsCharging then return end
	self.IsCharging = false

	local weaponId, weaponConfig, tool = self:GetEquippedWeapon()
	if not weaponId or weaponId ~= self.CurrentWeaponId or not weaponConfig then return end

	local chargeDuration = os.clock() - self.ChargeStartTime
	local maxCharge = weaponConfig.MaxChargeTime or 1.5
	local chargeRatio = math.clamp(chargeDuration / maxCharge, 0.1, 1.0)

	local camera = Workspace.CurrentCamera
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not hrp then return end

	local origin = (tool and tool:FindFirstChild("Handle") and tool.Handle.Position) or (hrp.Position + Vector3.new(0, 1.5, 0))
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local direction = unitRay.Direction

	-- Solicitar disparo a distancia al servidor
	if self.CombatService then
		self.CombatService.RangedShotRequested:Fire(weaponId, origin, direction, chargeRatio)
	end

	print(`🏹 [CombatController] Proyectil liberado con carga de {math.floor(chargeRatio * 100)}%`)
end

-- Intento de ataque Melee estándar (Lógica original intacta)
function CombatController:TryAttack()
	local weaponId = self:GetEquippedWeapon()

	if weaponId then
		if self.CombatService then
			self.CombatService.AttackRequested:Fire(weaponId)
		end
	end
end

-- Función auxiliar para generar la estela transparente (Afterimage / Ghost Trail) durante el esquive
local function CreateDodgeGhostTrail(character: Model)
	if not character then return end

	task.spawn(function()
		local duration = 0.25
		local interval = 0.05
		local startTime = os.clock()

		while (os.clock() - startTime) < duration do
			if not character or not character.Parent then break end

			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
					local ghost = part:Clone()
					for _, child in ipairs(ghost:GetChildren()) do
						if not child:IsA("SpecialMesh") and not child:IsA("BlockMesh") and not child:IsA("CylinderMesh") then
							child:Destroy()
						end
					end

					ghost.Name = "DodgeGhost"
					ghost.Anchored = true
					ghost.CanCollide = false
					ghost.CanQuery = false
					ghost.CanTouch = false
					ghost.Material = Enum.Material.ForceField
					ghost.Color = Color3.fromRGB(150, 220, 255) -- Estela neón celeste/transparente
					ghost.Transparency = 0.45
					ghost.CFrame = part.CFrame
					ghost.Parent = Workspace

					local fadeTween = TweenService:Create(ghost, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Transparency = 1,
					})
					fadeTween:Play()
					fadeTween.Completed:Connect(function()
						ghost:Destroy()
					end)
				end
			end

			task.wait(interval)
		end
	end)
end

-- Intento de Esquive / Dash (Tecla F) consumiendo radiación en el servidor
function CombatController:TryDodge()
	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp then return end

	if not self.CombatService then return end

	self.CombatService:DodgeRequested():andThen(function(success)
		if not success then return end

		-- Dirección del esquive proyectada en el plano horizontal (X/Z)
		local rawDir = humanoid.MoveDirection
		local moveDir = Vector3.new(rawDir.X, 0, rawDir.Z)

		-- Si el jugador está quieto, varía aleatoriamente entre izquierda y derecha
		if moveDir.Magnitude == 0 then
			local sideSign = if math.random() > 0.5 then 1 else -1
			local sideVector = hrp.CFrame.RightVector * sideSign
			moveDir = Vector3.new(sideVector.X, 0, sideVector.Z)
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
		end

		-- Impulso físico con menor distancia inicial
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

		-- Desaceleración suave (Ease-Out) mediante TweenService para eliminar la rigidez
		local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local speedTween = TweenService:Create(linearVelocity, tweenInfo, { VectorVelocity = Vector3.zero })
		speedTween:Play()

		-- Generar la estela transparente (Ghost Trail) durante el movimiento
		CreateDodgeGhostTrail(character)

		speedTween.Completed:Connect(function()
			linearVelocity:Destroy()
			attachment:Destroy()
		end)

		print("⚡ [CombatController] Esquive lateral/direccional fluido ejecutado.")
	end):catch(warn)
end

return CombatController
