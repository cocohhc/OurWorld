local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

-- Referencias a carpetas del UI Framework
local FrameworkFolder = PlayerScripts:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Framework")

local ComponentsFolder = FrameworkFolder:WaitForChild("Components")

-- Importaciones de módulos
local UITheme = require(FrameworkFolder:WaitForChild("UITheme"))
local ClassViewportService = require(ComponentsFolder:WaitForChild("ClassViewportService"))

local sharedClasses = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("Systems")
	:WaitForChild("Classes")

local ClassData = require(sharedClasses:WaitForChild("ClassData"))

local ClassSelectionView = {}
ClassSelectionView.__index = ClassSelectionView

function ClassSelectionView.new()
	local self = setmetatable({}, ClassSelectionView)

	self.ScreenGui = UITheme.CreateScreenGui("ClassSelectionGui")
	
	self.OnCreateNewConfirmed = Instance.new("BindableEvent")
	self.OnSelectExistingConfirmed = Instance.new("BindableEvent")
	self.OnSkipLoading = Instance.new("BindableEvent")

	self.Mode = nil
	self.SelectedSlotId = nil
	self.SelectedClassKey = nil
	self.SelectedSubtype = nil
	
	self.ClassCards = {}
	self.SubtypeCards = {}
	self.SlotCards = {}

	self.IsDraggingViewport = false
	self.LastMousePosition = Vector2.zero

	self.AppearanceController = Knit.GetController("ClassAppearanceController")

	self:BuildSelectionUI()
	return self
end

function ClassSelectionView:BuildSelectionUI()
	-- 🌌 1. FONDO PANTALLA COMPLETA CON DEGRADADO
	self.Background = Instance.new("Frame")
	self.Background.Size = UDim2.fromScale(1, 1)
	self.Background.Position = UDim2.fromScale(0, 0)
	self.Background.BackgroundColor3 = UITheme.Colors.BackgroundDark
	self.Background.BorderSizePixel = 0
	self.Background.Parent = self.ScreenGui

	UITheme.ApplyLinearGradient(
		self.Background,
		UITheme.Colors.GradientContainerTop,
		UITheme.Colors.BackgroundDark,
		90
	)

	-- 👑 TÍTULO PRINCIPAL (Arriba Izquierda)
	local title = UITheme.CreateLabel("WHISHGO", 28, true)
	title.Size = UDim2.new(0.3, 0, 0, 40)
	title.Position = UDim2.new(0.04, 0, 0.03, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = self.Background

	-- ✍️ 2. INPUT DE NOMBRE DE PERSONAJE
	local nameInputContainer = UITheme.CreateContainer(UDim2.fromOffset(300, 42), UDim2.new(0.04, 0, 0.09, 0))
	nameInputContainer.AnchorPoint = Vector2.new(0, 0)
	nameInputContainer.Parent = self.Background
	UITheme.AddPadding(nameInputContainer, 4, 4, 12, 12)

	self.NameInput = Instance.new("TextBox")
	self.NameInput.Size = UDim2.fromScale(1, 1)
	self.NameInput.BackgroundTransparency = 1
	self.NameInput.Font = UITheme.Fonts.Body or Enum.Font.SourceSans
	self.NameInput.TextSize = 15
	self.NameInput.TextColor3 = UITheme.Colors.TextMain
	self.NameInput.PlaceholderText = "Nombre de tu personaje..."
	self.NameInput.PlaceholderColor3 = UITheme.Colors.TextMuted
	self.NameInput.ClearTextOnFocus = false
	self.NameInput.ZIndex = 3
	self.NameInput.Parent = nameInputContainer

	-- ⚔️ 3. CONTENEDOR DE TARJETAS HORIZONTALES (CLASES)
	local classCardsFrame = Instance.new("Frame")
	classCardsFrame.Size = UDim2.new(0.68, 0, 0.22, 0)
	classCardsFrame.Position = UDim2.new(0.04, 0, 0.17, 0)
	classCardsFrame.BackgroundTransparency = 1
	classCardsFrame.Parent = self.Background

	local classListLayout = UITheme.AddListLayout(classCardsFrame, 14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left)
	classListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	-- 🛡️ 4. PANEL CENTRO-IZQUIERDA: DUMMY 3D + SUBTIPOS + HISTORIA
	local centerPanel = UITheme.CreateContainer(UDim2.new(0.68, 0, 0.52, 0), UDim2.new(0.04, 0, 0.41, 0))
	centerPanel.AnchorPoint = Vector2.new(0, 0)
	centerPanel.Parent = self.Background

	-- Frame para Selección de Subtipos / Armas
	self.SubtypeFrame = Instance.new("Frame")
	self.SubtypeFrame.Size = UDim2.new(0.94, 0, 0, 38)
	self.SubtypeFrame.Position = UDim2.new(0.03, 0, 0.03, 0)
	self.SubtypeFrame.BackgroundTransparency = 1
	self.SubtypeFrame.Visible = false
	self.SubtypeFrame.Parent = centerPanel

	local subLayout = UITheme.AddListLayout(self.SubtypeFrame, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left)
	subLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Contenedor del Viewport3D
	local dummyViewportFrame = Instance.new("Frame")
	dummyViewportFrame.Size = UDim2.new(0.42, 0, 0.82, 0)
	dummyViewportFrame.Position = UDim2.new(0.03, 0, 0.14, 0)
	dummyViewportFrame.BackgroundTransparency = 1
	dummyViewportFrame.Parent = centerPanel

	self.ViewportService = ClassViewportService.new(dummyViewportFrame)

	-- 🔄 CAPA DE INTERACCIÓN Y ROTACIÓN 3D
	local dragOverlay = Instance.new("TextButton")
	dragOverlay.Size = UDim2.fromScale(1, 1)
	dragOverlay.BackgroundTransparency = 1
	dragOverlay.Text = ""
	dragOverlay.Active = true
	dragOverlay.ZIndex = 5
	dragOverlay.Parent = dummyViewportFrame

	dragOverlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.IsDraggingViewport = true
			self.LastMousePosition = UserInputService:GetMouseLocation()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if self.IsDraggingViewport and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local currentPos = UserInputService:GetMouseLocation()
			local delta = currentPos - self.LastMousePosition
			self.LastMousePosition = currentPos

			if self.ViewportService then
				if self.ViewportService.Rotate then
					self.ViewportService:Rotate(delta.X, delta.Y)
				elseif self.ViewportService.RotateDummy then
					self.ViewportService:RotateDummy(delta.X, delta.Y)
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.IsDraggingViewport = false
		end
	end)

	-- Texto de Lore / Info Detallada
	self.InfoLabel = UITheme.CreateLabel("Selecciona una clase para forjar un nuevo héroe o elige una partida guardada.", 15)
	self.InfoLabel.Size = UDim2.new(0.50, 0, 0.75, 0)
	self.InfoLabel.Position = UDim2.new(0.47, 0, 0.18, 0)
	self.InfoLabel.TextColor3 = UITheme.Colors.TextSub
	self.InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.InfoLabel.Parent = centerPanel

	-- 📜 5. COLUMNA DERECHA: PARTIDAS GUARDADAS ("TUS PERSONAJES")
	local rightContainer = UITheme.CreateContainer(UDim2.new(0.22, 0, 0.76, 0), UDim2.new(0.74, 0, 0.17, 0))
	rightContainer.AnchorPoint = Vector2.new(0, 0)
	rightContainer.Parent = self.Background

	local rightTitle = UITheme.CreateLabel("TUS PERSONAJES", 16, true, Enum.TextXAlignment.Center)
	rightTitle.Size = UDim2.new(1, 0, 0, 35)
	rightTitle.Parent = rightContainer

	self.ScrollList = Instance.new("ScrollingFrame")
	self.ScrollList.Size = UDim2.new(0.9, 0, 0.88, 0)
	self.ScrollList.Position = UDim2.new(0.05, 0, 0.1, 0)
	self.ScrollList.BackgroundTransparency = 1
	self.ScrollList.ScrollBarThickness = 4
	self.ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.ScrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ScrollList.Parent = rightContainer

	UITheme.AddListLayout(self.ScrollList, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)

	-- 🔘 6. BOTÓN DE CONFIRMACIÓN PRINCIPAL CON DEGRADADO DORADO
	self.ConfirmBtn = UITheme.CreateButton("COMENZAR", UDim2.fromOffset(220, 48), true)
	self.ConfirmBtn.Position = UDim2.new(0.96, -220, 0.96, -48)
	self.ConfirmBtn.Visible = false
	self.ConfirmBtn.Parent = self.Background

	-- 🎴 GENERAR TARJETAS HORIZONTALES DE CLASES
	for classKey, data in pairs(ClassData.Classes or {}) do
		local card = UITheme.CreateContainer(UDim2.new(0, 180, 1, 0))
		card.Parent = classCardsFrame

		-- Título de la clase (Arriba)
		local nameLabel = UITheme.CreateLabel(data.Name or classKey, 18, true, Enum.TextXAlignment.Center)
		nameLabel.Size = UDim2.new(1, -16, 0, 26)
		nameLabel.Position = UDim2.new(0, 8, 0, 10)
		nameLabel.Parent = card

		-- Descripción (Centro)
		local descLabel = UITheme.CreateLabel(data.Description or "", 12, false, Enum.TextXAlignment.Center)
		descLabel.Size = UDim2.new(1, -16, 1, -45)
		descLabel.Position = UDim2.new(0, 8, 0, 38)
		descLabel.TextColor3 = UITheme.Colors.TextSub
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Parent = card

		local clicker = Instance.new("TextButton")
		clicker.Size = UDim2.fromScale(1, 1)
		clicker.BackgroundTransparency = 1
		clicker.Text = ""
		clicker.ZIndex = 4
		clicker.Parent = card

		self.ClassCards[classKey] = card

		clicker.MouseButton1Click:Connect(function()
			self:SelectClass(classKey, data)
		end)
	end

	self.ConfirmBtn.MouseButton1Click:Connect(function()
		if self.Mode == "SelectExisting" and self.SelectedSlotId then
			self.OnSelectExistingConfirmed:Fire(self.SelectedSlotId)
		elseif self.Mode == "CreateNew" and self.SelectedClassKey then
			local charName = if self.NameInput.Text ~= "" then self.NameInput.Text else "Héroe"
			self.OnCreateNewConfirmed:Fire(self.SelectedClassKey, self.SelectedSubtype, charName)
		end
	end)
end

function ClassSelectionView:UpdateModelAppearanceAndPersonality(classKey: string, subtypeKey: string?, personalityKey: string?)
	if self.ViewportService and typeof(self.ViewportService.UpdateAppearance) == "function" then
		self.ViewportService:UpdateAppearance(classKey, subtypeKey)
	end

	-- Obtener el modelo comprobando si existe el método 'GetModel', o accediendo directamente a la propiedad 'CurrentModel' / 'Model'
	local dummyModel = nil
	if self.ViewportService then
		if typeof(self.ViewportService.GetModel) == "function" then
			dummyModel = self.ViewportService:GetModel()
		else
			dummyModel = self.ViewportService.CurrentModel or self.ViewportService.Model
		end
	end

	if dummyModel then
		local classConfig = ClassData.Classes and ClassData.Classes[classKey]
		local activePersonality = personalityKey or (classConfig and classConfig.DefaultPersonality) or classKey

		if self.AppearanceController and typeof(self.AppearanceController.PreviewPersonalityOnModel) == "function" then
			self.AppearanceController:PreviewPersonalityOnModel(dummyModel, activePersonality)
		end
	end
end

function ClassSelectionView:SelectClass(classKey: string, data: table)
	self.Mode = "CreateNew"
	self.SelectedSlotId = nil
	self.SelectedClassKey = classKey

	self.ConfirmBtn.Text = "CREAR PERSONAJE"
	self.ConfirmBtn.Visible = true

	self:HighlightClassCard(classKey)
	self:ClearSlotCardsHighlight()

	self:RenderSubtypesForClass(classKey, data)
	self:UpdateModelAppearanceAndPersonality(classKey, self.SelectedSubtype, data.Personality)

	local loreText = data.Lore or data.Description or ""
	local subtypeInfo = self.SelectedSubtype and `\nArma inicial: {self.SelectedSubtype}` or ""
	self.InfoLabel.Text = `[FORJAR NUEVO {string.upper(data.Name or classKey)}]{subtypeInfo}\n\n"{loreText}"`
end

function ClassSelectionView:RenderSubtypesForClass(classKey: string, data: table)
	for _, child in ipairs(self.SubtypeFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.SubtypeCards = {}

	local subtypes = data.Subtypes
	if not subtypes or (type(subtypes) == "table" and next(subtypes) == nil) then
		self.SubtypeFrame.Visible = false
		self.SelectedSubtype = nil
		return
	end

	self.SubtypeFrame.Visible = true

	local firstKey = nil

	for subKey, subData in pairs(subtypes) do
		local subName = (type(subData) == "table" and subData.Name) or tostring(subKey)
		firstKey = firstKey or subKey

		local btn = UITheme.CreateButton(subName, UDim2.fromOffset(120, 32))
		btn.Parent = self.SubtypeFrame
		self.SubtypeCards[subKey] = btn

		btn.MouseButton1Click:Connect(function()
			self.SelectedSubtype = subKey
			self:HighlightSubtypeCard(subKey)
			self:UpdateModelAppearanceAndPersonality(classKey, subKey, data.Personality)

			local defaultWeapon = (type(subData) == "table" and subData.DefaultWeapon) or subName
			self.InfoLabel.Text = `[FORJAR NUEVO {string.upper(data.Name or classKey)}]\nEspecialización / Arma: {subName} ({defaultWeapon})\n\n"{data.Lore or ""}"`
		end)
	end

	if firstKey then
		self.SelectedSubtype = firstKey
		self:HighlightSubtypeCard(firstKey)
	end
end

function ClassSelectionView:SetCharacterSlots(slots)
	for _, child in ipairs(self.ScrollList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.SlotCards = {}

	for _, slot in ipairs(slots) do
		local card = UITheme.CreateButton(`{slot.Name}\nLvl {slot.Level} - {slot.Class}`, UDim2.new(1, 0, 0, 52))
		card.Parent = self.ScrollList
		self.SlotCards[slot.Id] = card

		card.MouseButton1Click:Connect(function()
			self.Mode = "SelectExisting"
			self.SelectedSlotId = slot.Id
			self.SelectedClassKey = nil

			self.ConfirmBtn.Text = "JUGAR PARTIDA"
			self.ConfirmBtn.Visible = true
			self.SubtypeFrame.Visible = false

			self:UpdateModelAppearanceAndPersonality(slot.Class, slot.Subtype, slot.Personality)

			self:HighlightSlotCard(slot.Id)
			self:ClearClassCardsHighlight()

			local classData = ClassData.Classes and ClassData.Classes[slot.Class]
			local loreText = classData and classData.Lore or ""
			self.InfoLabel.Text = `[PARTIDA GUARDADA]\nNombre: {slot.Name}\nClase: {slot.Class} (Nivel {slot.Level})\nOro: {slot.Gold or 0}\n\n"{loreText}"`
		end)
	end
end

function ClassSelectionView:HighlightClassCard(selectedKey)
	for key, card in pairs(self.ClassCards) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local gradient = card:FindFirstChildOfClass("UIGradient")
		
		if key == selectedKey then
			card.BackgroundColor3 = UITheme.Colors.PrimaryHover
			if stroke then stroke.Color = UITheme.Colors.BorderFocused end
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.PrimaryHover),
					ColorSequenceKeypoint.new(1, UITheme.Colors.Container),
				})
			end
		else
			card.BackgroundColor3 = UITheme.Colors.Container
			if stroke then stroke.Color = UITheme.Colors.Border end
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.GradientContainerTop),
					ColorSequenceKeypoint.new(1, UITheme.Colors.GradientContainerBottom),
				})
			end
		end
	end
end

function ClassSelectionView:ClearClassCardsHighlight()
	for _, card in pairs(self.ClassCards) do
		card.BackgroundColor3 = UITheme.Colors.Container
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local gradient = card:FindFirstChildOfClass("UIGradient")
		if stroke then stroke.Color = UITheme.Colors.Border end
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, UITheme.Colors.GradientContainerTop),
				ColorSequenceKeypoint.new(1, UITheme.Colors.GradientContainerBottom),
			})
		end
	end
end

function ClassSelectionView:HighlightSubtypeCard(selectedKey)
	for key, btn in pairs(self.SubtypeCards) do
		local gradient = btn:FindFirstChildOfClass("UIGradient")
		if key == selectedKey then
			btn.BackgroundColor3 = UITheme.Colors.Accent
			btn.TextColor3 = UITheme.Colors.BackgroundDark
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.GradientGoldTop),
					ColorSequenceKeypoint.new(1, UITheme.Colors.GradientGoldBottom),
				})
			end
		else
			btn.BackgroundColor3 = UITheme.Colors.Primary
			btn.TextColor3 = UITheme.Colors.TextMain
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.PrimaryHover),
					ColorSequenceKeypoint.new(1, UITheme.Colors.Primary),
				})
			end
		end
	end
end

function ClassSelectionView:HighlightSlotCard(selectedId)
	for id, card in pairs(self.SlotCards) do
		local gradient = card:FindFirstChildOfClass("UIGradient")
		if id == selectedId then
			card.BackgroundColor3 = UITheme.Colors.Accent
			card.TextColor3 = UITheme.Colors.BackgroundDark
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.GradientGoldTop),
					ColorSequenceKeypoint.new(1, UITheme.Colors.GradientGoldBottom),
				})
			end
		else
			card.BackgroundColor3 = UITheme.Colors.Primary
			card.TextColor3 = UITheme.Colors.TextMain
			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, UITheme.Colors.PrimaryHover),
					ColorSequenceKeypoint.new(1, UITheme.Colors.Primary),
				})
			end
		end
	end
end

function ClassSelectionView:ClearSlotCardsHighlight()
	for _, card in pairs(self.SlotCards) do
		card.BackgroundColor3 = UITheme.Colors.Primary
		card.TextColor3 = UITheme.Colors.TextMain
		local gradient = card:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, UITheme.Colors.PrimaryHover),
				ColorSequenceKeypoint.new(1, UITheme.Colors.Primary),
			})
		end
	end
end

function ClassSelectionView:ShowLoadingUI()
	for _, child in ipairs(self.Background:GetChildren()) do
		child:Destroy()
	end

	local loadingContainer = UITheme.CreateContainer(UDim2.fromOffset(550, 200), UDim2.fromScale(0.5, 0.5))
	loadingContainer.Parent = self.Background

	self.StatusLabel = UITheme.CreateLabel("CARGANDO DATOS Y MUNDO... 0%", 18, true, Enum.TextXAlignment.Center)
	self.StatusLabel.Size = UDim2.new(0.9, 0, 0, 40)
	self.StatusLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
	self.StatusLabel.Parent = loadingContainer

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.85, 0, 0, 16)
	barBg.Position = UDim2.new(0.075, 0, 0.48, 0)
	barBg.BackgroundColor3 = UITheme.Colors.Primary
	barBg.BorderSizePixel = 0
	barBg.Parent = loadingContainer

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBg

	self.ProgressBar = Instance.new("Frame")
	self.ProgressBar.Size = UDim2.new(0, 0, 1, 0)
	self.ProgressBar.BackgroundColor3 = UITheme.Colors.Accent
	self.ProgressBar.BorderSizePixel = 0
	self.ProgressBar.Parent = barBg

	UITheme.ApplyLinearGradient(self.ProgressBar, UITheme.Colors.GradientGoldTop, UITheme.Colors.GradientGoldBottom, 0)

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = self.ProgressBar

	local skipBtn = UITheme.CreateButton("SALTAR CARGA", UDim2.fromOffset(140, 36))
	skipBtn.Position = UDim2.new(0.5, 0, 0.74, 0)
	skipBtn.AnchorPoint = Vector2.new(0.5, 0)
	skipBtn.Parent = loadingContainer

	skipBtn.MouseButton1Click:Connect(function()
		self.OnSkipLoading:Fire()
	end)
end

function ClassSelectionView:UpdateProgress(percent: number)
	if self.StatusLabel and self.ProgressBar then
		self.StatusLabel.Text = string.format("CARGANDO EL MUNDO... %d%%", math.floor(percent * 100))
		TweenService:Create(self.ProgressBar, TweenInfo.new(0.05), {
			Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
		}):Play()
	end
end

function ClassSelectionView:Mount(playerGui)
	self.ScreenGui.Parent = playerGui
end

function ClassSelectionView:Destroy()
	if self.ViewportService then
		self.ViewportService:Destroy()
	end
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
	if self.OnCreateNewConfirmed then self.OnCreateNewConfirmed:Destroy() end
	if self.OnSelectExistingConfirmed then self.OnSelectExistingConfirmed:Destroy() end
	if self.OnSkipLoading then self.OnSkipLoading:Destroy() end
end

return ClassSelectionView