-- src/client/UI/Framework/Components/UIDragService.luau
-- Servicio del cliente para otorgar comportamiento arrastrable (Drag & Drop) a la UI.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local UIDragService = {}

export type DragController = {
	Disconnect: (self: DragController) -> (),
}

--- Otorga comportamiento de arrastre a un Frame de la interfaz.
--- @param targetFrame Frame -- El Frame principal que se moverá en pantalla.
--- @param dragHandle GuiObject? -- La barra superior/agarradera (Header). Si es nil, se usará el targetFrame.
--- @param padding number? -- Margen mínimo de seguridad respecto a los bordes de la pantalla.
function UIDragService.MakeDraggable(targetFrame: Frame, dragHandle: GuiObject?, padding: number?): DragController
	local handle = dragHandle or targetFrame
	local pad = padding or 8

	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3 = Vector3.zero
	local startAbsPos: Vector2 = Vector2.zero

	local connections: { RBXScriptConnection } = {}

local function UpdateInput(input: InputObject)
		local camera = Workspace.CurrentCamera
		if not camera then return end

		local delta = input.Position - dragStart
		local currentAbsX = startAbsPos.X + delta.X
		local currentAbsY = startAbsPos.Y + delta.Y

		-- Cálculo de límites de pantalla completos con contención
		local viewportSize = camera.ViewportSize
		local guiInset = GuiService:GetGuiInset()

		local minX = pad
		local maxX = math.max(pad, viewportSize.X - targetFrame.AbsoluteSize.X - pad)

		-- Clampeamos X primero para evaluar si el marco invade la zona superior izquierda de Roblox (TopBar)
		local clampedAbsX = math.clamp(currentAbsX, minX, maxX)

		-- Zona reservada para botones del sistema de Roblox (Menú, Chat, Emotes en la esquina superior izquierda)
		local robloxReservedWidth = 240
		local isInRobloxReservedZone = clampedAbsX < robloxReservedWidth

		-- Si está en la zona de los botones de Roblox, respeta el Inset; si está a la derecha, permite subir hasta el borde superior
		local minY = if isInRobloxReservedZone then (guiInset.Y + pad) else pad
		local maxY = math.max(minY, viewportSize.Y - targetFrame.AbsoluteSize.Y - pad)

		local clampedAbsY = math.clamp(currentAbsY, minY, maxY)

		-- Convertir posición absoluta a UDim2 offset respetando AnchorPoint y Parent
		local parent = targetFrame.Parent
		local parentAbsPos = Vector2.zero
		if parent and parent:IsA("GuiObject") then
			parentAbsPos = parent.AbsolutePosition
		elseif parent and parent:IsA("LayerCollector") then
			local ignoreInset = parent:IsA("ScreenGui") and parent.IgnoreGuiInset
			if not ignoreInset then
				parentAbsPos = Vector2.new(0, guiInset.Y)
			end
		end

		local anchor = targetFrame.AnchorPoint
		local posX = clampedAbsX - parentAbsPos.X + (targetFrame.AbsoluteSize.X * anchor.X)
		local posY = clampedAbsY - parentAbsPos.Y + (targetFrame.AbsoluteSize.Y * anchor.Y)

		targetFrame.Position = UDim2.new(0, posX, 0, posY)
	end

	-- Inicio de interacción (Click o Touch en el Header/Frame)
	local connBegan = handle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startAbsPos = targetFrame.AbsolutePosition

			print(string.format("[UIDragService] [DEBUG] Arrastre iniciado en '%s' (Handle: '%s')", targetFrame.Name, handle.Name))

			local connEnded: RBXScriptConnection? = nil
			connEnded = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if connEnded then
						connEnded:Disconnect()
					end
					print(string.format("[UIDragService] [DEBUG] Arrastre finalizado en '%s'", targetFrame.Name))
				end
			end)
		end
	end)

	-- Registro de entrada en movimiento
	local connHandleChanged = handle.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	-- Procesamiento global de movimiento mientras se arrastra
	local connGlobalChanged = UserInputService.InputChanged:Connect(function(input: InputObject)
		if input == dragInput and dragging then
			UpdateInput(input)
		end
	end)

	table.insert(connections, connBegan)
	table.insert(connections, connHandleChanged)
	table.insert(connections, connGlobalChanged)

	print(string.format("[UIDragService] Comportamiento arrastrable activado para '%s'", targetFrame.Name))

	return {
		Disconnect = function(self: DragController)
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			table.clear(connections)
			print(string.format("[UIDragService] Arrastre desactivado para '%s'", targetFrame.Name))
		end,
	}
end

return UIDragService
