local TweenService = game:GetService("TweenService")

local UITheme = {}

-- 🎨 Tokens de Diseño Exagerados (Fantasía Oscura / Oro Brilante y Ébano)
UITheme.Colors = {
	BackgroundDark = Color3.fromRGB(10, 8, 6),
	Container = Color3.fromRGB(22, 17, 13),
	ContainerHeader = Color3.fromRGB(58, 42, 28), -- Color base más cálido y diferenciado

	-- 🔘 Botones Básicos (Contraste súper marcado entre estados)
	Primary = Color3.fromRGB(42, 31, 24),         -- Base
	PrimaryHover = Color3.fromRGB(110, 80, 60),   -- Hover (Súper claro e iluminado)
	PrimaryActive = Color3.fromRGB(15, 10, 8),     -- Active (Súper oscuro / presionado)

	-- ✨ Acentos Dorados Exagerados
	Accent = Color3.fromRGB(255, 185, 50),        -- Oro brillante e intenso
	AccentHover = Color3.fromRGB(255, 225, 130),  -- Oro deslumbrante
	AccentActive = Color3.fromRGB(170, 110, 20),  -- Oro bruñido profundo

	-- 🖼️ Bordes y Biseles (Resaltados al máximo)
	Border = Color3.fromRGB(120, 90, 60),
	BorderFocused = Color3.fromRGB(255, 215, 80), -- Brillo dorado intenso
	BorderInnerHighlight = Color3.fromRGB(190, 145, 75),

	-- 📝 Textos
	TextMain = Color3.fromRGB(255, 248, 235),
	TextSub = Color3.fromRGB(200, 185, 165),
	TextMuted = Color3.fromRGB(130, 115, 100),

	-- 🌅 Degradados Metálicos Exagerados
	GradientContainerTop = Color3.fromRGB(48, 36, 26),
	GradientContainerBottom = Color3.fromRGB(10, 8, 6),
	GradientHeaderTop = Color3.fromRGB(65, 46, 30),     -- Tono bronce/oro oscuro para contrastar
	GradientHeaderBottom = Color3.fromRGB(36, 25, 17),  -- Tono inferior oscuro pero delimitado
	GradientGoldTop = Color3.fromRGB(255, 225, 110),
	GradientGoldBottom = Color3.fromRGB(190, 120, 20),
}

UITheme.Fonts = {
	Title = Enum.Font.Garamond,
	Body = Enum.Font.Gotham,
	Button = Enum.Font.Garamond,
	Code = Enum.Font.Code,
}

UITheme.Tweens = {
	Fast = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- 🛠️ Utilidades de Degradados & Texturas de Borde

function UITheme.ApplyLinearGradient(parent: Instance, colorTop: Color3, colorBottom: Color3, rotation: number?): UIGradient
	local gradient = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colorTop),
		ColorSequenceKeypoint.new(1, colorBottom),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

function UITheme.ApplyOrnateBorder(parent: Frame, isAccent: boolean?): UIStroke
	-- Borde principal engrosado (Outer Stroke)
	local outerStroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	outerStroke.Color = isAccent and UITheme.Colors.Accent or UITheme.Colors.Border
	outerStroke.Thickness = 2.5
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = parent

	-- Marco interior para simular bisel dorado / textura grabada estilo WoW
	local innerFrame = parent:FindFirstChild("InnerBorderTexture")
	if not innerFrame then
		innerFrame = Instance.new("Frame")
		innerFrame.Name = "InnerBorderTexture"
		innerFrame.Size = UDim2.new(1, -4, 1, -4)
		innerFrame.Position = UDim2.fromScale(0.5, 0.5)
		innerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		innerFrame.BackgroundTransparency = 1
		innerFrame.BorderSizePixel = 0
		innerFrame.ZIndex = parent.ZIndex + 1
		innerFrame.Parent = parent

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(0, 2)
		innerCorner.Parent = innerFrame

		local innerStroke = Instance.new("UIStroke")
		innerStroke.Name = "InnerStroke"
		innerStroke.Color = isAccent and UITheme.Colors.BorderFocused or UITheme.Colors.BorderInnerHighlight
		innerStroke.Thickness = 1
		innerStroke.Transparency = 0.35
		innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		innerStroke.Parent = innerFrame
	end

	return outerStroke
end

-- 📦 Creadores de Componentes Reutilizables

function UITheme.CreateScreenGui(name: string): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	return screenGui
end

function UITheme.CreateContainer(size: UDim2, position: UDim2, cornerRadius: number?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position or UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = UITheme.Colors.Container
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius or 4)
	corner.Parent = frame

	UITheme.ApplyLinearGradient(frame, UITheme.Colors.GradientContainerTop, UITheme.Colors.GradientContainerBottom)
	UITheme.ApplyOrnateBorder(frame, false)

	return frame
end

function UITheme.CreateHeader(titleText: string, height: number?, hasBorder: boolean?): Frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderContainer"
	headerFrame.Size = UDim2.new(1, 0, 0, height or 30) -- Reducido a 30px por defecto
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundColor3 = UITheme.Colors.ContainerHeader
	headerFrame.BorderSizePixel = 0
	headerFrame.ZIndex = 4

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = headerFrame

	-- Degradado exclusivo de Header con contraste diferenciado del contenedor
	UITheme.ApplyLinearGradient(headerFrame, UITheme.Colors.GradientHeaderTop, UITheme.Colors.GradientHeaderBottom, 90)

	-- Aplica el borde ornamentado solo si hasBorder es true (o no se especifica, por defecto true)
	if hasBorder == nil or hasBorder == true then
		UITheme.ApplyOrnateBorder(headerFrame, false)
	end

	if titleText and titleText ~= "" then
		local titleLabel = UITheme.CreateLabel(titleText, 15, true, Enum.TextXAlignment.Left)
		titleLabel.Size = UDim2.new(1, -20, 1, 0)
		titleLabel.Position = UDim2.new(0, 10, 0, 0)
		titleLabel.Parent = headerFrame
	end

	return headerFrame
end

function UITheme.CreateButton(text: string, size: UDim2, isAccent: boolean?): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = isAccent and UITheme.Colors.Accent or UITheme.Colors.Primary
	button.Text = text
	button.TextColor3 = isAccent and UITheme.Colors.BackgroundDark or UITheme.Colors.TextMain
	button.Font = UITheme.Fonts.Button
	button.TextSize = 18
	button.AutoButtonColor = false
	button.ZIndex = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	local buttonGradient = UITheme.ApplyLinearGradient(
		button,
		isAccent and UITheme.Colors.GradientGoldTop or UITheme.Colors.PrimaryHover,
		isAccent and UITheme.Colors.GradientGoldBottom or UITheme.Colors.Primary,
		90
	)

	local stroke = UITheme.ApplyOrnateBorder(button, isAccent)

	local baseColor = button.BackgroundColor3
	local hoverColor = isAccent and UITheme.Colors.AccentHover or UITheme.Colors.PrimaryHover
	local activeColor = isAccent and UITheme.Colors.AccentActive or UITheme.Colors.PrimaryActive

	button.MouseEnter:Connect(function()
		TweenService:Create(button, UITheme.Tweens.Fast, { BackgroundColor3 = hoverColor }):Play()
		TweenService:Create(stroke, UITheme.Tweens.Fast, { Color = UITheme.Colors.BorderFocused }):Play()
		TweenService:Create(buttonGradient, UITheme.Tweens.Fast, { Rotation = 180 }):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, UITheme.Tweens.Fast, { BackgroundColor3 = baseColor }):Play()
		TweenService:Create(stroke, UITheme.Tweens.Fast, { Color = isAccent and UITheme.Colors.Accent or UITheme.Colors.Border }):Play()
		TweenService:Create(buttonGradient, UITheme.Tweens.Fast, { Rotation = 90 }):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, UITheme.Tweens.Fast, { BackgroundColor3 = activeColor }):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, UITheme.Tweens.Fast, { BackgroundColor3 = hoverColor }):Play()
	end)

	return button
end

function UITheme.CreateLabel(text: string, fontSize: number, isTitle: boolean?, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = isTitle and UITheme.Colors.Accent or UITheme.Colors.TextMain
	label.Font = isTitle and UITheme.Fonts.Title or UITheme.Fonts.Body
	label.TextSize = fontSize
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.ZIndex = 3

	if isTitle then
		UITheme.ApplyLinearGradient(label, UITheme.Colors.GradientGoldTop, UITheme.Colors.Accent, 45)
	end

	return label
end

function UITheme.AddPadding(parent: Instance, top: number, bottom: number, left: number, right: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingRight = UDim.new(0, right)
	padding.Parent = parent
	return padding
end

function UITheme.AddListLayout(parent: Instance, padding: number, fillDirection: Enum.FillDirection?, alignment: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding)
	layout.FillDirection = fillDirection or Enum.FillDirection.Vertical
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

return UITheme
