local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UITheme = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))
local UIDragService = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("Components"):WaitForChild("UIDragService"))

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
	self.OnQuestClaimed = Instance.new("BindableEvent")

	self:BuildUI()
	self.ScreenGui.Parent = PlayerGui

	return self
end

function QuestDialogView:BuildUI()
	-- Ventana principal de diálogo centrada en pantalla
	self.MainFrame = UITheme.CreateContainer(UDim2.fromOffset(500, 320), UDim2.fromScale(0.5, 0.5))
	self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.MainFrame.Visible = false
	self.MainFrame.Parent = self.ScreenGui

	-- Header superior con borde (Altura reducida a 30px)
	self.HeaderFrame = UITheme.CreateHeader("NPC", 30, true)
	self.HeaderFrame.Parent = self.MainFrame

	-- Habilitar arrastre dinámico utilizando el Header como tirador
	UIDragService.MakeDraggable(self.MainFrame, self.HeaderFrame)

	-- Referencia al TextLabel del Header para actualizaciones dinámicas de texto
	self.NPCTitle = self.HeaderFrame:FindFirstChildOfClass("TextLabel")

	-- Botón de cerrar dentro del Header (Reducido a 18x18)
	local closeBtn = UITheme.CreateButton("X", UDim2.fromOffset(18, 18))
	closeBtn.Position = UDim2.new(1, -22, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0.5)
	closeBtn.ZIndex = 5
	closeBtn.Parent = self.HeaderFrame
	closeBtn.MouseButton1Click:Connect(function()
		self:Toggle(false)
	end)

	-- Texto de diálogo del NPC (Ajustado respecto al header más compacto)
	self.DialogText = UITheme.CreateLabel("...", 14, false, Enum.TextXAlignment.Center)
	self.DialogText.Size = UDim2.new(0.9, 0, 0.2, 0)
	self.DialogText.Position = UDim2.new(0.05, 0, 0.13, 0)
	self.DialogText.TextWrapped = true
	self.DialogText.Parent = self.MainFrame

	-- Contenedor de la misión seleccionada
	local questContainer = Instance.new("Frame")
	questContainer.Size = UDim2.new(0.9, 0, 0.45, 0)
	questContainer.Position = UDim2.new(0.5, 0, 0.38, 0)
	questContainer.AnchorPoint = Vector2.new(0.5, 0)
	questContainer.BackgroundTransparency = 1
	questContainer.BorderSizePixel = 0
	questContainer.Parent = self.MainFrame

	-- Título de la misión
	self.QuestTitle = UITheme.CreateLabel("Misión disponible", 32, true, Enum.TextXAlignment.Center)
	self.QuestTitle.Size = UDim2.new(1, 0, 0, 42)
	self.QuestTitle.Position = UDim2.new(0, 0, 0, 0)
	self.QuestTitle.Rotation = -2.5
	self.QuestTitle.Parent = questContainer

	-- Descripción de la misión
	self.QuestDesc = UITheme.CreateLabel("", 12, false, Enum.TextXAlignment.Center)
	self.QuestDesc.Size = UDim2.new(1, 0, 0.6, 0)
	self.QuestDesc.Position = UDim2.new(0, 0, 0, 44)
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

	-- Botón Reclamar Recompensa
	self.ClaimButton = UITheme.CreateButton("RECLAMAR RECOMPENSA", UDim2.new(0.9, 0, 0, 36), true)
	self.ClaimButton.Position = UDim2.new(0.05, 0, 0.86, 0)
	self.ClaimButton.Visible = false
	self.ClaimButton.Parent = self.MainFrame

	self.ClaimButton.MouseButton1Click:Connect(function()
		if self.CurrentQuestId then
			self.OnQuestClaimed:Fire(self.CurrentQuestId)
		end
	end)
end

function QuestDialogView:ShowNPC(npcId: string, npcName: string, dialogText: string, questConfig: table?)
	print(`[QuestDialogView] ShowNPC invocado | NPC: {npcName} ({npcId}) | Misión disponible: {questConfig and questConfig.Id or "Ninguna"}`)
	self.CurrentNPCId = npcId
	self.NPCTitle.Text = string.upper(npcName or npcId)
	self.DialogText.Text = dialogText or "Hola, viajero."

	self.ClaimButton.Visible = false

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

function QuestDialogView:ShowClaimDialog(npcId: string, npcName: string, dialogText: string, questConfig: table)
	print(`[QuestDialogView] ShowClaimDialog invocado | NPC: {npcName} ({npcId}) | Reclamando: {questConfig.Id}`)
	self.CurrentNPCId = npcId
	self.CurrentQuestId = questConfig.Id
	self.NPCTitle.Text = string.upper(npcName or npcId)
	self.DialogText.Text = dialogText or "¡Excelente trabajo!"

	self.QuestTitle.Text = questConfig.Title or "Misión Completada"
	self.QuestDesc.Text = questConfig.Description or ""

	self.AcceptButton.Visible = false
	self.ClaimButton.Visible = true

	self:Toggle(true)
end

function QuestDialogView:Toggle(visible: boolean?)
	self.IsOpen = if visible ~= nil then visible else not self.IsOpen
	self.MainFrame.Visible = self.IsOpen
	self.ScreenGui.Enabled = self.IsOpen
	print(`[QuestDialogView] Estado del menú de diálogo cambiado -> Visible: {self.IsOpen}`)
end

return QuestDialogView
