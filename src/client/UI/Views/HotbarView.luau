local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local UITheme = require(PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))
local UIDragService = require(PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("Components"):WaitForChild("UIDragService"))

local HotbarView = {}
HotbarView.__index = HotbarView

function HotbarView.new(maxSlots: number?)
	local self = setmetatable({}, HotbarView)

	self.MaxSlots = maxSlots or 5
	self.ScreenGui = UITheme.CreateScreenGui("HotbarGui")
	self.ScreenGui.DisplayOrder = 10

	self.ScreenGui.Enabled = false

	self.Slots = {}
	self.ActiveMenu = nil

	self.OnSlotSelected = Instance.new("BindableEvent")
	self.OnStoreRequested = Instance.new("BindableEvent")
	self.OnItemDropped = Instance.new("BindableEvent")
	self.OnHotbarUpdated = Instance.new("BindableEvent")

	self:BuildUI()
	self:SetupGlobalClickListener()

	self.ScreenGui.Parent = PlayerGui
	return self
end

function HotbarView:BuildUI()
	local container = Instance.new("Frame")
	container.Name = "HotbarContainer"
	container.Size = UDim2.fromOffset((self.MaxSlots * 60) + ((self.MaxSlots - 1) * 6), 60)
	container.Position = UDim2.new(0.5, 0, 0.92, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = self.ScreenGui

	-- Habilitar el arrastre del contenedor de la Hotbar
	UIDragService.MakeDraggable(container)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local textColor = (UITheme.Colors and (UITheme.Colors.Text or UITheme.Colors.TextPrimary)) or Color3.fromRGB(255, 255, 255)
	local subTextColor = (UITheme.Colors and UITheme.Colors.TextSub) or Color3.fromRGB(200, 200, 200)

	for i = 1, self.MaxSlots do
		local slotCard = UITheme.CreateContainer(UDim2.fromOffset(60, 60))
		slotCard.LayoutOrder = i
		slotCard.Parent = container

		-- Número del Atajo (1, 2, 3...)
		local keyLabel = UITheme.CreateLabel(tostring(i), 11, true, Enum.TextXAlignment.Left)
		keyLabel.Size = UDim2.new(0, 16, 0, 16)
		keyLabel.Position = UDim2.new(0, 4, 0, 2)
		keyLabel.TextColor3 = subTextColor
		keyLabel.ZIndex = 5
		keyLabel.Parent = slotCard

		-- Icono del Objeto
		local itemIcon = Instance.new("ImageLabel")
		itemIcon.Name = "ItemIcon"
		itemIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
		itemIcon.Position = UDim2.new(0.5, 0, 0.4, 0)
		itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		itemIcon.BackgroundTransparency = 1
		itemIcon.Visible = false
		itemIcon.ZIndex = 3
		itemIcon.Parent = slotCard

		-- Etiqueta del Nombre del Objeto (Ubicada en la parte inferior para visibilidad clara)
		local nameLabel = UITheme.CreateLabel("", 9, true, Enum.TextXAlignment.Center)
		nameLabel.Name = "ItemNameLabel"
		nameLabel.Size = UDim2.new(1, -4, 0, 14)
		nameLabel.Position = UDim2.new(0, 2, 1, -16)
		nameLabel.TextColor3 = textColor
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Visible = false
		nameLabel.ZIndex = 5
		nameLabel.Parent = slotCard

		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 6
		button.Parent = slotCard

		self.Slots[i] = {
			Frame = slotCard,
			Icon = itemIcon,
			NameLabel = nameLabel,
			RealSlot = i,
			Data = nil,
			Clicker = button,
		}

		button.MouseButton1Click:Connect(function()
			self.OnSlotSelected:Fire(i)
		end)

		button.MouseButton2Click:Connect(function()
			if self.Slots[i].Data then
				self:OpenContextMenu(i, slotCard)
			end
		end)
	end
end

function HotbarView:SetVisible(visible: boolean)
	if self.ScreenGui then
		self.ScreenGui.Enabled = visible
	end
end

function HotbarView:HighlightSlot(selectedIndex: number)
	for index, slot in ipairs(self.Slots) do
		local stroke = slot.Frame:FindFirstChildOfClass("UIStroke")
		local gradient = slot.Frame:FindFirstChildOfClass("UIGradient")

		if index == selectedIndex then
			slot.Frame.BackgroundColor3 = UITheme.Colors.PrimaryHover or Color3.fromRGB(60, 60, 60)
			if stroke then stroke.Color = UITheme.Colors.BorderFocused or Color3.fromRGB(255, 215, 0) end
			if gradient and UITheme.ApplyLinearGradient then
				UITheme.ApplyLinearGradient(slot.Frame, UITheme.Colors.GradientGoldTop, UITheme.Colors.GradientGoldBottom, 90)
			end
		else
			slot.Frame.BackgroundColor3 = UITheme.Colors.Container or Color3.fromRGB(30, 30, 30)
			if stroke then stroke.Color = UITheme.Colors.Border or Color3.fromRGB(80, 80, 80) end
			if gradient and UITheme.ApplyLinearGradient then
				UITheme.ApplyLinearGradient(slot.Frame, UITheme.Colors.GradientContainerTop, UITheme.Colors.GradientContainerBottom, 90)
			end
		end
	end
end

function HotbarView:UpdateSlot(slotIndex: number, itemData: table?)
	local slot = self.Slots[slotIndex]
	if not slot then return end

	slot.Data = itemData
	if itemData then
		local hasIcon = itemData.Icon and itemData.Icon ~= ""
		if hasIcon then
			slot.Icon.Image = itemData.Icon
			slot.Icon.Visible = true
		else
			slot.Icon.Visible = false
			slot.Icon.Image = ""
		end

		-- Mostrar el nombre siempre que exista el dato del ítem
		slot.NameLabel.Text = itemData.Name or "Objeto"
		slot.NameLabel.Visible = true
	else
		slot.Icon.Visible = false
		slot.Icon.Image = ""
		slot.NameLabel.Text = ""
		slot.NameLabel.Visible = false
	end
end

function HotbarView:OpenContextMenu(slotIndex: number, parentSlotFrame: Frame)
	self:CloseContextMenu()

	local menu = UITheme.CreateContainer(UDim2.fromOffset(90, 32))
	menu.Name = "HotbarContextMenu"
	menu.AnchorPoint = Vector2.new(0.5, 1)
	menu.Position = UDim2.new(0.5, 0, -0.1, 0)
	menu.ZIndex = 20
	menu.Parent = parentSlotFrame

	local storeBtn = UITheme.CreateButton("Guardar", UDim2.new(1, -6, 1, -6), true)
	storeBtn.Position = UDim2.fromScale(0.5, 0.5)
	storeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	storeBtn.TextSize = 11
	storeBtn.ZIndex = 21
	storeBtn.Parent = menu

	storeBtn.MouseButton1Click:Connect(function()
		self:CloseContextMenu()
		self.OnStoreRequested:Fire(slotIndex)
	end)

	self.ActiveMenu = menu
end

function HotbarView:CloseContextMenu()
	if self.ActiveMenu then
		self.ActiveMenu:Destroy()
		self.ActiveMenu = nil
	end
end

function HotbarView:SetupGlobalClickListener()
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Cierra el menú contextual si se requiere
		end
	end)
end

function HotbarView:SetHotbarData(hotbarItems: table)
	self:CloseContextMenu()

	if type(hotbarItems) ~= "table" then
		hotbarItems = {}
	end

	for i = 1, self.MaxSlots do
		-- Sombra/Fallback para acceder tanto por entero (1) como por cadena ("1")
		local itemData = hotbarItems[i] or hotbarItems[tostring(i)]
		self:UpdateSlot(i, itemData)
	end

	self.OnHotbarUpdated:Fire()
end

function HotbarView:Destroy()
	self:CloseContextMenu()
	if self.ScreenGui then self.ScreenGui:Destroy() end
	if self.OnSlotSelected then self.OnSlotSelected:Destroy() end
	if self.OnStoreRequested then self.OnStoreRequested:Destroy() end
	if self.OnItemDropped then self.OnItemDropped:Destroy() end
end

return HotbarView
