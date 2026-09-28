local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UITheme = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))

local InventoryView = {}
InventoryView.__index = InventoryView

function InventoryView.new(maxSlots: number?)
	local self = setmetatable({}, InventoryView)

	self.MaxSlots = maxSlots or 24
	self.ScreenGui = UITheme.CreateScreenGui("InventoryGui")
	self.ScreenGui.DisplayOrder = 15
	self.IsOpen = false
	self.SelectedItem = nil
	self.SelectedSlotIndex = nil
	self.Slots = {}

	-- Estado del Arrastre (Drag & Drop)
	self.DraggingSlot = nil
	self.DragGhost = nil
	self.IsDragging = false
	self.DragStartPos = Vector2.zero

	self.OnItemAction = Instance.new("BindableEvent")
	self.OnItemDropped = Instance.new("BindableEvent")

	self:BuildUI()
	self:SetupGlobalDragListeners()
	
	self.ScreenGui.Parent = PlayerGui
	return self
end

function InventoryView:BuildUI()
	self.MainFrame = UITheme.CreateContainer(UDim2.fromOffset(660, 400), UDim2.fromScale(0.5, 0.45))
	self.MainFrame.Visible = false
	self.MainFrame.Parent = self.ScreenGui

	local title = UITheme.CreateLabel("MOCHILA", 20, true)
	title.Size = UDim2.new(0.5, 0, 0, 28)
	title.Position = UDim2.new(0.04, 0, 0.04, 0)
	title.Parent = self.MainFrame

	local closeBtn = UITheme.CreateButton("X", UDim2.fromOffset(26, 26))
	closeBtn.Position = UDim2.new(0.96, -26, 0.04, 0)
	closeBtn.Parent = self.MainFrame

	closeBtn.MouseButton1Click:Connect(function()
		self:Toggle(false)
	end)

	local gridContainer = Instance.new("ScrollingFrame")
	gridContainer.Size = UDim2.new(0.62, 0, 0.8, 0)
	gridContainer.Position = UDim2.new(0.04, 0, 0.15, 0)
	gridContainer.BackgroundTransparency = 1
	gridContainer.ScrollBarThickness = 4
	gridContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	gridContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridContainer.Parent = self.MainFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(56, 56)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridContainer

	-- Colores seguros con fallback 🎨
	local mainTextColor = (UITheme.Colors and (UITheme.Colors.TextMain or UITheme.Colors.Text or UITheme.Colors.TextPrimary)) or Color3.fromRGB(255, 255, 255)
	local subTextColor = (UITheme.Colors and (UITheme.Colors.TextSub or UITheme.Colors.SubText)) or Color3.fromRGB(180, 180, 180)

	for i = 1, self.MaxSlots do
		local slotCard = UITheme.CreateContainer(UDim2.fromOffset(56, 56))
		slotCard.Parent = gridContainer

		local itemIcon = Instance.new("ImageLabel")
		itemIcon.Name = "ItemIcon"
		itemIcon.Size = UDim2.new(0.75, 0, 0.75, 0)
		itemIcon.Position = UDim2.fromScale(0.5, 0.5)
		itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		itemIcon.BackgroundTransparency = 1
		itemIcon.Visible = false
		itemIcon.ZIndex = 2
		itemIcon.Parent = slotCard

		local countLabel = UITheme.CreateLabel("", 11, false, Enum.TextXAlignment.Right)
		countLabel.Name = "CountLabel"
		countLabel.Size = UDim2.new(1, -4, 0, 12)
		countLabel.Position = UDim2.new(0, 0, 1, -14)
		countLabel.TextColor3 = mainTextColor
		countLabel.ZIndex = 3
		countLabel.Parent = slotCard

		local clicker = Instance.new("TextButton")
		clicker.Size = UDim2.fromScale(1, 1)
		clicker.BackgroundTransparency = 1
		clicker.Text = ""
		clicker.ZIndex = 4
		clicker.Parent = slotCard

		self.Slots[i] = {
			Frame = slotCard,
			Icon = itemIcon,
			Count = countLabel,
			RealSlot = i + 5, -- Mapeo real del slot (6 a 29) 🎒
			Data = nil,
		}

		-- Conectar la presión del botón
		clicker.MouseButton1Down:Connect(function()
			if self.Slots[i].Data then
				self.DraggingSlot = i
				local mousePos = UserInputService:GetMouseLocation()
				self.DragStartPos = Vector2.new(mousePos.X, mousePos.Y)
			end
		end)
	end

	local detailsPanel = UITheme.CreateContainer(UDim2.new(0.28, 0, 0.8, 0), UDim2.new(0.68, 0, 0.15, 0))
	detailsPanel.AnchorPoint = Vector2.new(0, 0)
	detailsPanel.Parent = self.MainFrame

	UITheme.AddPadding(detailsPanel, 10, 10, 10, 10)

	self.ItemTitle = UITheme.CreateLabel("Selecciona un objeto", 15, true, Enum.TextXAlignment.Center)
	self.ItemTitle.Size = UDim2.new(1, 0, 0, 22)
	self.ItemTitle.Parent = detailsPanel

	self.ItemDesc = UITheme.CreateLabel("", 12, false, Enum.TextXAlignment.Left)
	self.ItemDesc.Size = UDim2.new(1, 0, 0.5, 0)
	self.ItemDesc.Position = UDim2.new(0, 0, 0.22, 0)
	self.ItemDesc.TextColor3 = subTextColor
	self.ItemDesc.Parent = detailsPanel

	self.ActionButton = UITheme.CreateButton("EQUIPAR", UDim2.new(1, 0, 0, 36), true)
	self.ActionButton.Position = UDim2.new(0, 0, 1, -36)
	self.ActionButton.Visible = false
	self.ActionButton.Parent = detailsPanel

	-- Al presionar el botón lateral, enviamos la orden con la casilla real ⚡
	self.ActionButton.MouseButton1Click:Connect(function()
		if self.SelectedSlotIndex then
			local realSlot = self.Slots[self.SelectedSlotIndex].RealSlot
			self.OnItemAction:Fire("Use", realSlot, self.SelectedItem)
		end
	end)
end

-- 🚀 Sistema Global de Arrastrar y Soltar (Sin bloqueos de eventos)
function InventoryView:SetupGlobalDragListeners()
	UserInputService.InputChanged:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and self.DraggingSlot then
			local currentPos = Vector2.new(input.Position.X, input.Position.Y)
			local distance = (currentPos - self.DragStartPos).Magnitude

			-- Activar el icono fantasma si se mueve más de 5 píxeles manteniendo clic
			if not self.IsDragging and distance > 5 then
				self.IsDragging = true

				local slotData = self.Slots[self.DraggingSlot].Data
				if slotData then
					self.DragGhost = Instance.new("ImageLabel")
					self.DragGhost.Size = UDim2.fromOffset(48, 48)
					self.DragGhost.Position = UDim2.fromOffset(input.Position.X - 24, input.Position.Y - 24)
					self.DragGhost.BackgroundTransparency = 1
					self.DragGhost.Image = slotData.Icon or ""
					self.DragGhost.Active = false
					self.DragGhost.ZIndex = 100
					self.DragGhost.Parent = self.ScreenGui

					TweenService:Create(self.DragGhost, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.fromOffset(52, 52)
					}):Play()
				end
			end

			if self.IsDragging and self.DragGhost then
				self.DragGhost.Position = UDim2.fromOffset(input.Position.X - 26, input.Position.Y - 26)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self.DraggingSlot then
				if self.IsDragging then
					-- Finalizar Arrastre
					local mousePos = Vector2.new(input.Position.X, input.Position.Y)
					local targetSlotIndex = self:GetSlotAtPosition(mousePos)

					if targetSlotIndex and targetSlotIndex ~= self.DraggingSlot then
						local realFrom = self.Slots[self.DraggingSlot].RealSlot
						local realTo = self.Slots[targetSlotIndex].RealSlot
						self.OnItemDropped:Fire(realFrom, realTo)
					end
				else
					-- Fue un clic rápido sin arrastre
					self:SelectItem(self.DraggingSlot)
				end
			end

			-- Limpiar estado
			if self.DragGhost then
				self.DragGhost:Destroy()
				self.DragGhost = nil
			end
			self.DraggingSlot = nil
			self.IsDragging = false
		end
	end)
end

function InventoryView:GetSlotAtPosition(screenPos: Vector2): number?
	for index, slot in ipairs(self.Slots) do
		local absPos = slot.Frame.AbsolutePosition
		local absSize = slot.Frame.AbsoluteSize

		if screenPos.X >= absPos.X and screenPos.X <= (absPos.X + absSize.X) and
		   screenPos.Y >= absPos.Y and screenPos.Y <= (absPos.Y + absSize.Y) then
			return index
		end
	end
	return nil
end

function InventoryView:SelectItem(slotIndex: number)
	local slot = self.Slots[slotIndex]
	if not slot or not slot.Data then
		self.SelectedItem = nil
		self.SelectedSlotIndex = nil
		self.ItemTitle.Text = "Selecciona un objeto"
		self.ItemDesc.Text = ""
		self.ActionButton.Visible = false
		self:ClearHighlights()
		return
	end

	self.SelectedItem = slot.Data
	self.SelectedSlotIndex = slotIndex
	self.ItemTitle.Text = string.upper(slot.Data.Name or "Objeto")
	self.ItemDesc.Text = slot.Data.Description or "Sin descripción."
	self.ActionButton.Text = slot.Data.ActionName or "USAR"
	self.ActionButton.Visible = true

	self:HighlightSlot(slotIndex)
end

function InventoryView:HighlightSlot(selectedIndex: number)
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

function InventoryView:ClearHighlights()
	for _, slot in ipairs(self.Slots) do
		slot.Frame.BackgroundColor3 = UITheme.Colors.Container or Color3.fromRGB(30, 30, 30)
		local stroke = slot.Frame:FindFirstChildOfClass("UIStroke")
		local gradient = slot.Frame:FindFirstChildOfClass("UIGradient")
		if stroke then stroke.Color = UITheme.Colors.Border or Color3.fromRGB(80, 80, 80) end
		if gradient and UITheme.ApplyLinearGradient then
			UITheme.ApplyLinearGradient(slot.Frame, UITheme.Colors.GradientContainerTop, UITheme.Colors.GradientContainerBottom, 90)
		end
	end
end

function InventoryView:SetItems(itemList: table)
	for i = 1, self.MaxSlots do
		-- 🔍 Leemos directamente 'i' porque el servidor ya envía la lista del 1 al 24
		local itemData = itemList[i] 
		local slot = self.Slots[i]

		slot.Data = itemData
		if itemData then
			slot.Icon.Image = itemData.Icon or ""
			slot.Icon.Visible = true
			slot.Count.Text = if itemData.Amount and itemData.Amount > 1 then tostring(itemData.Amount) else ""
		else
			slot.Icon.Visible = false
			slot.Icon.Image = ""
			slot.Count.Text = ""
		end
	end
end

function InventoryView:Toggle(visible: boolean?)
	self.IsOpen = if visible ~= nil then visible else not self.IsOpen
	self.MainFrame.Visible = self.IsOpen
end

function InventoryView:Destroy()
	if self.ScreenGui then self.ScreenGui:Destroy() end
	if self.OnItemAction then self.OnItemAction:Destroy() end
	if self.OnItemDropped then self.OnItemDropped:Destroy() end
end

return InventoryView