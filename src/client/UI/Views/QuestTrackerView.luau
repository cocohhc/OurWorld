local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UITheme = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))

local QuestTrackerView = {}
QuestTrackerView.__index = QuestTrackerView

function QuestTrackerView.new()
	local self = setmetatable({}, QuestTrackerView)

	self.ScreenGui = UITheme.CreateScreenGui("QuestTrackerGui")
	self.ScreenGui.DisplayOrder = 15
	self.IsOpen = false
	self.SelectedQuestId = nil

	self:BuildUI()
	self.ScreenGui.Parent = PlayerGui

	return self
end

function QuestTrackerView:BuildUI()
	-- Ventana principal posicionada a la derecha y reducida en ancho (320px)
	self.MainFrame = UITheme.CreateContainer(UDim2.fromOffset(320, 300), UDim2.new(0.98, 0, 0.5, 0))
	self.MainFrame.AnchorPoint = Vector2.new(1, 0.5)
	self.MainFrame.Visible = false
	self.MainFrame.Parent = self.ScreenGui

	-- Header superior con borde (Altura reducida a 30px)
	self.HeaderFrame = UITheme.CreateHeader("DIARIO DE MISIONES", 30, true)
	self.HeaderFrame.Parent = self.MainFrame

	-- Botón para cerrar integrado en el Header (Reducido a 18x18)
	local closeBtn = UITheme.CreateButton("X", UDim2.fromOffset(18, 18))
	closeBtn.Position = UDim2.new(1, -22, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0.5)
	closeBtn.ZIndex = 5
	closeBtn.Parent = self.HeaderFrame
	closeBtn.MouseButton1Click:Connect(function()
		self:Toggle(false)
	end)

	-- Panel de Detalle y Objetivos (Ajustado verticalmente para el nuevo Header)
	self.DetailContainer = Instance.new("ScrollingFrame")
	self.DetailContainer.Size = UDim2.new(0.92, 0, 0.82, -10)
	self.DetailContainer.Position = UDim2.new(0.04, 0, 0, 34)
	self.DetailContainer.BackgroundTransparency = 1
	self.DetailContainer.BorderSizePixel = 0
	self.DetailContainer.ScrollBarThickness = 4
	self.DetailContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.DetailContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.DetailContainer.Parent = self.MainFrame

	local detailLayout = Instance.new("UIListLayout")
	detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailLayout.Padding = UDim.new(0, 8)
	detailLayout.Parent = self.DetailContainer

	UITheme.AddPadding(self.DetailContainer, 2, 4, 2, 4)

	self.DetailTitle = UITheme.CreateLabel("Selecciona una misión", 15, true, Enum.TextXAlignment.Left)
	self.DetailTitle.Size = UDim2.new(1, 0, 0, 22)
	self.DetailTitle.AutomaticSize = Enum.AutomaticSize.Y
	self.DetailTitle.Parent = self.DetailContainer

	self.DetailDesc = UITheme.CreateLabel("", 12, false, Enum.TextXAlignment.Left)
	self.DetailDesc.Size = UDim2.new(1, 0, 0, 0)
	self.DetailDesc.AutomaticSize = Enum.AutomaticSize.Y
	self.DetailDesc.TextWrapped = true
	self.DetailDesc.Parent = self.DetailContainer

	-- Subtítulo Objetivos
	local objHeader = UITheme.CreateLabel("OBJETIVOS", 13, true, Enum.TextXAlignment.Left)
	objHeader.Size = UDim2.new(1, 0, 0, 18)
	objHeader.Parent = self.DetailContainer

	self.ObjectivesFrame = Instance.new("Frame")
	self.ObjectivesFrame.Size = UDim2.new(1, 0, 0, 0)
	self.ObjectivesFrame.AutomaticSize = Enum.AutomaticSize.Y
	self.ObjectivesFrame.BackgroundTransparency = 1
	self.ObjectivesFrame.Parent = self.DetailContainer

	local objLayout = Instance.new("UIListLayout")
	objLayout.SortOrder = Enum.SortOrder.LayoutOrder
	objLayout.Padding = UDim.new(0, 4)
	objLayout.Parent = self.ObjectivesFrame

	-- Recompensas
	self.RewardLabel = UITheme.CreateLabel("", 12, true, Enum.TextXAlignment.Left)
	self.RewardLabel.Size = UDim2.new(1, 0, 0, 20)
	self.RewardLabel.AutomaticSize = Enum.AutomaticSize.Y
	self.RewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	self.RewardLabel.Parent = self.DetailContainer

	-- Panel de lista oculto o reutilizable
	self.ListScroll = Instance.new("ScrollingFrame")
	self.ListScroll.Visible = false
	self.ListScroll.Parent = self.MainFrame
end

function QuestTrackerView:UpdateList(activeQuests: table, questsConfig: table)
	-- Limpiar lista anterior
	for _, child in ipairs(self.ListScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local firstQuestId = nil

	for questId, progressData in pairs(activeQuests) do
		local config = questsConfig[questId]
		if not config then continue end

		if not firstQuestId then firstQuestId = questId end

		local btn = UITheme.CreateButton(config.Title or questId, UDim2.new(1, -6, 0, 36))
		btn.Parent = self.ListScroll
		btn.MouseButton1Click:Connect(function()
			self:SelectQuest(questId, progressData, config)
		end)
	end

	-- Ajustar scroll canvas
	local layout = self.ListScroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		self.ListScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end

	-- Seleccionar la primera misión por defecto o limpiar panel
	if firstQuestId and questsConfig[firstQuestId] then
		self:SelectQuest(firstQuestId, activeQuests[firstQuestId], questsConfig[firstQuestId])
	else
		self:ClearDetails()
	end
end

function QuestTrackerView:SelectQuest(questId: string, progressData: table, config: table)
	self.SelectedQuestId = questId
	self.DetailTitle.Text = config.Title or questId
	self.DetailDesc.Text = config.Description or "Sin descripción disponible."

	-- Limpiar objetivos anteriores
	for _, child in ipairs(self.ObjectivesFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	-- Mostrar objetivos y su progreso actual
	if config.Objectives then
		for index, obj in ipairs(config.Objectives) do
			local currentProgress = 0
			if progressData and progressData.Objectives and progressData.Objectives[index] then
				currentProgress = progressData.Objectives[index].Progress or 0
			end

			-- Fix: Usar RequiredAmount en lugar de Amount
			local targetAmount = obj.RequiredAmount or 1
			local isCompleted = currentProgress >= targetAmount
			local statusSymbol = isCompleted and "✓" or "○"

			local objText = `{statusSymbol} {obj.Description or "Objetivo"} ({currentProgress}/{targetAmount})`
			local label = UITheme.CreateLabel(objText, 12, false, Enum.TextXAlignment.Left)
			label.Size = UDim2.new(1, 0, 0, 18)
			if isCompleted then
				label.TextColor3 = Color3.fromRGB(100, 220, 100)
			end
			label.Parent = self.ObjectivesFrame
		end
	end

	-- Formatear recompensas
	local rewards = config.Rewards
	if rewards then
		local rewardStr = "Recompensas: "
		if rewards.Exp then rewardStr ..= `+{rewards.Exp} EXP  ` end
		if rewards.Gold then rewardStr ..= `+{rewards.Gold} Oro` end
		self.RewardLabel.Text = rewardStr
	else
		self.RewardLabel.Text = ""
	end
end

function QuestTrackerView:ClearDetails()
	self.SelectedQuestId = nil
	self.DetailTitle.Text = "No tienes misiones activas"
	self.DetailDesc.Text = "Habla con los NPCs en el mundo para recibir encargos."
	self.RewardLabel.Text = ""
	for _, child in ipairs(self.ObjectivesFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

function QuestTrackerView:Toggle(visible: boolean?)
	self.IsOpen = if visible ~= nil then visible else not self.IsOpen
	self.MainFrame.Visible = self.IsOpen
end

return QuestTrackerView
