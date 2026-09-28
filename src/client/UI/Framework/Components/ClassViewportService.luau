local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClassViewportService = {}
ClassViewportService.__index = ClassViewportService

function ClassViewportService.new(containerFrame: Frame)
	local self = setmetatable({}, ClassViewportService)

	self.Container = containerFrame
	self.RotationConnection = nil

	-- 1. Crear ViewportFrame con iluminación activa
	self.Viewport = Instance.new("ViewportFrame")
	self.Viewport.Size = UDim2.fromScale(1, 1)
	self.Viewport.BackgroundTransparency = 1
	self.Viewport.LightColor = Color3.fromRGB(255, 255, 255)
	self.Viewport.LightDirection = Vector3.new(-1, -2, -1)
	self.Viewport.Ambient = Color3.fromRGB(150, 150, 160)
	self.Viewport.Parent = self.Container

	-- 2. Cámara 3D del Viewport
	self.Camera = Instance.new("Camera")
	self.Camera.FieldOfView = 35
	self.Viewport.CurrentCamera = self.Camera
	self.Camera.Parent = self.Viewport

	-- 3. WorldModel contenedor
	self.WorldModel = Instance.new("WorldModel")
	self.WorldModel.Parent = self.Viewport

	self.CurrentDummy = nil
	self:CreateBaseDummy()

	return self
end

function ClassViewportService:CreateBaseDummy()
	if self.CurrentDummy then
		self.CurrentDummy:Destroy()
	end

	local dummy = Instance.new("Model")
	dummy.Name = "ClassPreviewDummy"

	-- Buscar un Dummy predefinido en Assets o construir uno visible por código
	local baseRig = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("BaseDummy")
	if baseRig then
		dummy = baseRig:Clone()
	else
		-- Construcción básica de un bloque R6 visible para previsualización
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2, 2, 1)
		torso.Position = Vector3.new(0, 3, 0)
		torso.Color = Color3.fromRGB(140, 150, 175)
		torso.Material = Enum.Material.SmoothPlastic
		torso.Parent = dummy

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.2, 1.2, 1.2)
		head.Position = Vector3.new(0, 4.6, 0)
		head.Color = Color3.fromRGB(230, 190, 160)
		head.Material = Enum.Material.SmoothPlastic
		head.Parent = dummy

		local leftArm = Instance.new("Part")
		leftArm.Name = "Left Arm"
		leftArm.Size = Vector3.new(1, 2, 1)
		leftArm.Position = Vector3.new(-1.5, 3, 0)
		leftArm.Color = Color3.fromRGB(140, 150, 175)
		leftArm.Parent = dummy

		local rightArm = Instance.new("Part")
		rightArm.Name = "Right Arm"
		rightArm.Size = Vector3.new(1, 2, 1)
		rightArm.Position = Vector3.new(1.5, 3, 0)
		rightArm.Color = Color3.fromRGB(140, 150, 175)
		rightArm.Parent = dummy

		local leftLeg = Instance.new("Part")
		leftLeg.Name = "Left Leg"
		leftLeg.Size = Vector3.new(1, 2, 1)
		leftLeg.Position = Vector3.new(-0.5, 1, 0)
		leftLeg.Color = Color3.fromRGB(50, 55, 70)
		leftLeg.Parent = dummy

		local rightLeg = Instance.new("Part")
		rightLeg.Name = "Right Leg"
		rightLeg.Size = Vector3.new(1, 2, 1)
		rightLeg.Position = Vector3.new(0.5, 1, 0)
		rightLeg.Color = Color3.fromRGB(50, 55, 70)
		rightLeg.Parent = dummy

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Position = Vector3.new(0, 3, 0)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.Parent = dummy

		dummy.PrimaryPart = hrp

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = dummy
	end

	dummy.Parent = self.WorldModel
	self.CurrentDummy = dummy

	-- Posicionar la Cámara mirando hacia el torso/pecho
	local targetPart = dummy:FindFirstChild("Torso") or dummy.PrimaryPart
	if targetPart then
		local focusPos = targetPart.Position + Vector3.new(0, 0.3, 0)
		self.Camera.CFrame = CFrame.new(focusPos + Vector3.new(0, 0.5, 7), focusPos)
	end

	-- Rotación continua en 3D
	if self.RotationConnection then
		self.RotationConnection:Disconnect()
	end

	local angle = 0
	self.RotationConnection = RunService.RenderStepped:Connect(function(dt)
		if self.CurrentDummy and self.CurrentDummy.PrimaryPart then
			angle = angle + (dt * 30)
			local root = self.CurrentDummy.PrimaryPart
			local currentPos = root.Position
			root.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, math.rad(angle), 0)
		end
	end)
end

function ClassViewportService:UpdateAppearance(classKey: string, subtype: string?)
	if not self.CurrentDummy then return end

	-- Cambiar colores según la clase para diferenciar visualmente
	local torso = self.CurrentDummy:FindFirstChild("Torso")
	local head = self.CurrentDummy:FindFirstChild("Head")

	if classKey == "Warrior" then
		if torso then torso.Color = Color3.fromRGB(180, 50, 50) end -- Rojo Guerrero
	elseif classKey == "Mage" then
		if torso then torso.Color = Color3.fromRGB(120, 50, 200) end -- Morado Mago
	elseif classKey == "Giant" then
		if torso then torso.Color = Color3.fromRGB(80, 100, 110) end -- Gris Piedra
	end
end

function ClassViewportService:Destroy()
	if self.RotationConnection then
		self.RotationConnection:Disconnect()
	end
	if self.Viewport then
		self.Viewport:Destroy()
	end
end

return ClassViewportService