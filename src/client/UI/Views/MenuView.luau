local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local UITheme = require(PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("UITheme"))
local UIDragService = require(PlayerScripts:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Framework"):WaitForChild("Components"):WaitForChild("UIDragService"))

local MenuView = {}
MenuView.__index = MenuView

function MenuView.new()
	print("🛠️ [MenuView] Instanciando vista de menú de accesos rápidos...")
	local self = setmetatable({}, MenuView)

	self.ScreenGui = UITheme.CreateScreenGui("MenuGui")
	self.ScreenGui.DisplayOrder = 12
	self.ScreenGui.Enabled = false -- Oculto inicialmente; solo se revelará al ingresar al juego con el personaje

	self.OnToggleInventory = Instance.new("BindableEvent")
	self.OnToggleQuests = Instance.new("BindableEvent")
	self.OnToggleCharacter = Instance.new("BindableEvent")
	self.OnLogout = Instance.new("BindableEvent")

	self:BuildUI()
	self.ScreenGui.Parent = PlayerGui

	print(`✅ [MenuView] Interfaz montada e inyectada en PlayerGui ({self.ScreenGui:GetFullName()})`)
	return self
end

function MenuView:BuildUI()
	-- Contenedor principal del botón Hamburguesa y Dropdown
	self.MainFrame = UITheme.CreateContainer(UDim2.fromOffset(48, 48), UDim2.new(0.98, 0, 0.05, 0))
	self.MainFrame.AnchorPoint = Vector2.new(1, 0)
	self.MainFrame.Parent = self.ScreenGui

	-- Botón Toggle (Hamburguesa) con las 3 rayitas
	local toggleMenuBtn = UITheme.CreateButton("☰", UDim2.new(1, 0, 1, 0))
	toggleMenuBtn.TextSize = 22
	toggleMenuBtn.Parent = self.MainFrame

	-- Asignar drag al botón de 3 rayitas como tirador del MainFrame
	UIDragService.MakeDraggable(self.MainFrame, toggleMenuBtn)

	-- Menú Desplegable (Dropdown) con Auto-sizing adaptado al contenido y pegado al botón
	self.DropdownFrame = UITheme.CreateContainer(UDim2.fromOffset(0, 0), UDim2.new(0, -8, 0, 0))
	self.DropdownFrame.AnchorPoint = Vector2.new(1, 0)
	self.DropdownFrame.AutomaticSize = Enum.AutomaticSize.XY
	self.DropdownFrame.Visible = false
	self.DropdownFrame.Parent = self.MainFrame

	-- Eliminar cualquier GuiObject interno generado por UITheme.CreateContainer para evitar el contenedor vacío superior
	for _, child in self.DropdownFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Disposición vertical de botones
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 6)
	layout.Parent = self.DropdownFrame

	UITheme.AddPadding(self.DropdownFrame, 8, 8, 8, 8)

	-- Botones del Dropdown
	local invBtn = UITheme.CreateButton("🎒 Mochila", UDim2.fromOffset(115, 30))
	invBtn.TextSize = 13
	invBtn.Parent = self.DropdownFrame
	invBtn.MouseButton1Click:Connect(function()
		self.OnToggleInventory:Fire()
	end)

	local questBtn = UITheme.CreateButton("📜 Misiones", UDim2.fromOffset(115, 30))
	questBtn.TextSize = 13
	questBtn.Parent = self.DropdownFrame
	questBtn.MouseButton1Click:Connect(function()
		self.OnToggleQuests:Fire()
	end)

	local logoutBtn = UITheme.CreateButton("🚪 Salir", UDim2.fromOffset(115, 30))
	logoutBtn.TextSize = 13
	logoutBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40) -- Rojo advertencia
	logoutBtn.Parent = self.DropdownFrame

	-- Lógica de Interacción
	toggleMenuBtn.MouseButton1Click:Connect(function()
		self.DropdownFrame.Visible = not self.DropdownFrame.Visible
	end)

	logoutBtn.MouseButton1Click:Connect(function()
		self:ShowLogoutModal()
		self.DropdownFrame.Visible = false
	end)

	-- Instanciar modal oculto
	self:BuildLogoutModal()
end

function MenuView:BuildLogoutModal()
	self.LogoutModal = UITheme.CreateContainer(UDim2.fromOffset(300, 150), UDim2.fromScale(0.5, 0.5))
	self.LogoutModal.AnchorPoint = Vector2.new(0.5, 0.5)
	self.LogoutModal.Visible = false
	self.LogoutModal.Parent = self.ScreenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "⚠️ ¿Desconectar y volver al menú?"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.Parent = self.LogoutModal

	self.LogoutTimerText = Instance.new("TextLabel")
	self.LogoutTimerText.Size = UDim2.new(1, 0, 0, 20)
	self.LogoutTimerText.Position = UDim2.fromOffset(0, 40)
	self.LogoutTimerText.BackgroundTransparency = 1
	self.LogoutTimerText.Text = "Autodesconexión en 20s"
	self.LogoutTimerText.TextColor3 = Color3.fromRGB(200, 200, 200)
	self.LogoutTimerText.Font = Enum.Font.Gotham
	self.LogoutTimerText.TextSize = 12
	self.LogoutTimerText.Parent = self.LogoutModal

	local confirmBtn = UITheme.CreateButton("Confirmar", UDim2.fromOffset(110, 35))
	confirmBtn.Position = UDim2.new(0.5, -120, 1, -45)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	confirmBtn.Parent = self.LogoutModal

	local cancelBtn = UITheme.CreateButton("Cancelar", UDim2.fromOffset(110, 35))
	cancelBtn.Position = UDim2.new(0.5, 10, 1, -45)
	cancelBtn.Parent = self.LogoutModal

	confirmBtn.MouseButton1Click:Connect(function()
		self:ConfirmLogout()
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		self:CancelLogout()
	end)
end

function MenuView:ShowLogoutModal()
	self.LogoutModal.Visible = true
	self.LogoutTimeLeft = 20
	self.LogoutTimerText.Text = `Autodesconexión en {self.LogoutTimeLeft}s`

	if self.LogoutTask then task.cancel(self.LogoutTask) end

	self.LogoutTask = task.spawn(function()
		while self.LogoutTimeLeft > 0 do
			task.wait(1)
			self.LogoutTimeLeft -= 1
			if self.LogoutModal.Visible then
				self.LogoutTimerText.Text = `Autodesconexión en {self.LogoutTimeLeft}s`
			end
		end
		if self.LogoutModal.Visible then
			self:ConfirmLogout()
		end
	end)
end

function MenuView:ConfirmLogout()
	self.LogoutModal.Visible = false
	if self.LogoutTask then task.cancel(self.LogoutTask) end
	self.OnLogout:Fire()
end

function MenuView:CancelLogout()
	self.LogoutModal.Visible = false
	if self.LogoutTask then task.cancel(self.LogoutTask) end
end

function MenuView:SetVisible(visible: boolean)
	print(`👀 [MenuView] Visibilidad cambiada a: {visible}`)
	if self.ScreenGui then
		self.ScreenGui.Enabled = visible
	end
end

function MenuView:Destroy()
	if self.ScreenGui then self.ScreenGui:Destroy() end
	if self.OnToggleInventory then self.OnToggleInventory:Destroy() end
	if self.OnToggleQuests then self.OnToggleQuests:Destroy() end
	if self.OnToggleCharacter then self.OnToggleCharacter:Destroy() end
	if self.OnLogout then self.OnLogout:Destroy() end
	if self.LogoutTask then task.cancel(self.LogoutTask) end
end

return MenuView
