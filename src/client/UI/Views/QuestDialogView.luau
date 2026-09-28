local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UITheme = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))

local QuestDialogView = {}
QuestDialogView.__index = QuestDialogView

function QuestDialogView.new()
	local self = setmetatable({}, QuestDialogView)

	self.ScreenGui = UITheme.CreateScreenGui("QuestDialogGui")
	self.ScreenGui.DisplayOrder = 20
	self.IsOpen = false
	self.CurrentNPCId = nil
	self.CurrentQuestId = nil

	self.OnQuestAccepted = Instance.new("BindableEvent")

	self:BuildUI()
	self.ScreenGui.Parent = PlayerGui

	return self
end

function QuestDialogView:BuildUI()
	-- Ventana principal de diálogo
	self.MainFrame = UITheme.CreateContainer(UDim2.fromOffset(500, 320), UDim2.fromScale(0.5, 0.5))
	self.MainFrame.Visible = false
	self.MainFrame.Parent = self.ScreenGui

	-- Título del NPC
	self.NPCTitle = UITheme.CreateLabel("NPC", 18, true, Enum.TextXAlignment.Left)
	self.NPCTitle.Size = UDim2.new(0.8, 0, 0, 24)
	self.NPCTitle.Position = UDim2.new(0.05, 0, 0.05, 0)
	self.NPCTitle.Parent = self.MainFrame

	-- Botón de cerrar
	local closeBtn = UITheme.CreateButton("X", UDim2.fromOffset(26, 26))
	closeBtn.Position = UDim2.new(0.95, -26, 0.05, 0)
	closeBtn.Parent = self.MainFrame
	closeBtn.MouseButton1Click:Connect(function()
		self:Toggle(false)
	end)

	-- Texto de diálogo del NPC
	self.DialogText = UITheme.CreateLabel("...", 14, false, Enum.TextXAlignment.Left)
	self.DialogText.Size = UDim2.new(0.9, 0, 0.25, 0)
	self.DialogText.Position = UDim2.new(0.05, 0, 0.16, 0)
	self.DialogText.TextWrapped = true
	self.DialogText.Parent = self.MainFrame

	-- Contenedor de la misión seleccionada
	local questContainer = UITheme.CreateContainer(UDim2.new(0.9, 0, 0.4, 0), UDim2.new(0.05, 0, 0.44, 0))
	questContainer.Parent = self.MainFrame

	UITheme.AddPadding(questContainer, 8, 8, 8, 8)

	self.QuestTitle = UITheme.CreateLabel("Misión disponible", 15, true, Enum.TextXAlignment.Left)
	self.QuestTitle.Size = UDim2.new(1, 0, 0, 20)
	self.QuestTitle.Parent = questContainer

	self.QuestDesc = UITheme.CreateLabel("", 12, false, Enum.TextXAlignment.Left)
	self.QuestDesc.Size = UDim2.new(1, 0, 0.6, 0)
	self.QuestDesc.Position = UDim2.new(0, 0, 0.35, 0)
	self.QuestDesc.TextWrapped = true
	self.QuestDesc.Parent = questContainer

	-- Botón Aceptar Misión
	self.AcceptButton = UITheme.CreateButton("ACEPTAR MISIÓN", UDim2.new(0.9, 0, 0, 36), true)
	self.AcceptButton.Position = UDim2.new(0.05, 0, 0.86, 0)
	self.AcceptButton.Visible = false
	self.AcceptButton.Parent = self.MainFrame

	self.AcceptButton.MouseButton1Click:Connect(function()
		if self.CurrentQuestId then
			self.OnQuestAccepted:Fire(self.CurrentQuestId)
			self:Toggle(false)
		end
	end)
end

function QuestDialogView:ShowNPC(npcId: string, npcName: string, dialogText: string, questConfig: table?)
	self.CurrentNPCId = npcId
	self.NPCTitle.Text = string.upper(npcName or npcId)
	self.DialogText.Text = dialogText or "Hola, viajero."

	if questConfig then
		self.CurrentQuestId = questConfig.Id
		self.QuestTitle.Text = questConfig.Title or "Misión"
		self.QuestDesc.Text = questConfig.Description or ""
		self.AcceptButton.Visible = true
	else
		self.CurrentQuestId = nil
		self.QuestTitle.Text = "Sin misiones nuevas"
		self.QuestDesc.Text = "Vuelve más tarde para ver si tengo más encargos."
		self.AcceptButton.Visible = false
	end

	self:Toggle(true)
end

function QuestDialogView:Toggle(visible: boolean?)
	self.IsOpen = if visible ~= nil then visible else not self.IsOpen
	self.MainFrame.Visible = self.IsOpen
end

return QuestDialogView