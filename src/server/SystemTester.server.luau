-- src/server/SystemTester.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SystemTester = {}
SystemTester.Tests = {}

function SystemTester:AddTest(name: string, testFunc: () -> ())
	table.insert(self.Tests, { Name = name, Run = testFunc })
end

function SystemTester:RunAll()
	print("\n==================================================")
	print("🧪 [SystemTester] EJECUTANDO SUITE DE PRUEBAS GLOBAL (ESTRICTO)")
	print("==================================================")
	local passed = 0
	local failed = 0

	for _, test in ipairs(self.Tests) do
		local success, err = pcall(test.Run)
		if success then
			print("✅ [PASÓ]: " .. test.Name)
			passed += 1
		else
			warn("❌ [FALLÓ]: " .. test.Name .. "\n    Detalle: " .. tostring(err))
			failed += 1
		end
	end

	print("--------------------------------------------------")
	print(string.format("📊 RESULTADOS FINALES: %d Pasados | %d Fallados", passed, failed))
	print("==================================================\n")
end

---------------------------------------------------------------------------
-- 1. SISTEMA DE PERFILES Y CLASES
---------------------------------------------------------------------------
SystemTester:AddTest("1. ClassService & API de Cliente", function()
	local ClassService = Knit.GetService("ClassService")
	assert(ClassService ~= nil, "ClassService no está cargado en Knit.")
	assert(ClassService.Client ~= nil, "ClassService no tiene expuesta una tabla '.Client' para la comunicación remota.")

	local hasClientMethods = false
	for _, value in pairs(ClassService.Client) do
		if typeof(value) == "function" or typeof(value) == "table" then
			hasClientMethods = true
			break
		end
	end
	assert(hasClientMethods, "ClassService.Client está vacío. El UI de multiranura no tiene cómo comunicarse con el servidor.")
end)

---------------------------------------------------------------------------
-- 2. SISTEMA DE INVENTARIO (Prueba de Parser del Cliente ULTRA ESTRICTA)
---------------------------------------------------------------------------
SystemTester:AddTest("2. Inventory - Mapeo Estricto de Datos (Anti-Tablas Vacías)", function()
	local InventoryService = Knit.GetService("InventoryService")
	assert(InventoryService ~= nil, "InventoryService no está cargado en Knit.")

	local mockServerPayload = {
		Mochila = {},
		Hotbar = {},
		Items = {
			["1"] = { Name = "Espada Inicial" },
			["6"] = { Name = "Báculo Arcano" },
			[8] = { Name = "Poción" }
		}
	}

	local hotbarItems = {}
	local mainInventoryItems = {}

	if type(mockServerPayload.Hotbar) == "table" and next(mockServerPayload.Hotbar) ~= nil then
		for key, itemData in pairs(mockServerPayload.Hotbar) do
			local numericSlot = tonumber(key) or key
			if numericSlot and numericSlot >= 1 and numericSlot <= 5 then
				hotbarItems[numericSlot] = itemData
			end
		end
	elseif type(mockServerPayload.Items) == "table" then
		for i = 1, 5 do
			if mockServerPayload.Items[i] then
				hotbarItems[i] = mockServerPayload.Items[i]
			elseif mockServerPayload.Items[tostring(i)] then
				hotbarItems[i] = mockServerPayload.Items[tostring(i)]
			end
		end
	end

	if type(mockServerPayload.Mochila) == "table" and next(mockServerPayload.Mochila) ~= nil then
		for key, itemData in pairs(mockServerPayload.Mochila) do
			local numericSlot = tonumber(key)
			if numericSlot then
				if numericSlot >= 6 then
					mainInventoryItems[numericSlot - 5] = itemData
				else
					mainInventoryItems[numericSlot] = itemData
				end
			end
		end
	elseif type(mockServerPayload.Items) == "table" then
		for slotIndex, itemData in pairs(mockServerPayload.Items) do
			local numericSlot = tonumber(slotIndex)
			if numericSlot and numericSlot >= 6 then
				mainInventoryItems[numericSlot - 5] = itemData
			end
		end
	end

	assert(hotbarItems[1] ~= nil and hotbarItems[1].Name == "Espada Inicial", "Fallo: Slot 1 no se mapeó a la Hotbar.")
	assert(mainInventoryItems[1] ~= nil and mainInventoryItems[1].Name == "Báculo Arcano", "Fallo: El ítem en el slot global 6 (Items) no se mapeó a mainInventoryItems[1] porque el código se atascó en una tabla Mochila vacía.")
	assert(mainInventoryItems[3] ~= nil and mainInventoryItems[3].Name == "Poción", "Fallo: El ítem numérico global 8 no se mapeó a mainInventoryItems[3].")
	assert(mainInventoryItems[6] == nil, "Fallo Crítico: El ítem se quedó guardado en el índice 6 de la UI en lugar del índice relativo 1.")
end)

---------------------------------------------------------------------------
-- 3. SISTEMA DE COMBATE
---------------------------------------------------------------------------
SystemTester:AddTest("3. CombatService - Integridad", function()
	local CombatService = Knit.GetService("CombatService")
	assert(CombatService ~= nil, "CombatService no está cargado.")
end)

---------------------------------------------------------------------------
-- 4. SISTEMA DE MISIONES
---------------------------------------------------------------------------
SystemTester:AddTest("4. QuestService & Interacción NPC", function()
	local QuestService = Knit.GetService("QuestService")
	assert(QuestService ~= nil, "QuestService no está cargado.")
	local npcsFolder = Workspace:FindFirstChild("NPCs")
	assert(npcsFolder ~= nil, "No se encontró la carpeta 'Workspace.NPCs'.")
end)

---------------------------------------------------------------------------
-- 5. SISTEMA DE ENEMIGOS
---------------------------------------------------------------------------
SystemTester:AddTest("5. EnemyService - Escaneo y Registro de Zonas", function()
	local EnemyService = Knit.GetService("EnemyService")
	assert(EnemyService ~= nil, "EnemyService no está cargado.")
	local zone1 = Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("Zone1")
	assert(zone1 ~= nil, "No se encontró 'Workspace.NPCs.Zone1' requerida por EnemyService.")
end)

---------------------------------------------------------------------------
-- 6. SISTEMA DE IA DE ENEMIGOS E INTELIGENCIA TÁCTICA
---------------------------------------------------------------------------
SystemTester:AddTest("6. EnemyAIService & Módulos de IA (EnemyAIData)", function()
	local EnemyAIService = Knit.GetService("EnemyAIService")
	assert(EnemyAIService ~= nil, "EnemyAIService no está registrado en Knit.")

	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
	assert(sharedFolder ~= nil, "No se encontró la carpeta 'ReplicatedStorage.Shared'")

	local systemsFolder = sharedFolder:FindFirstChild("Systems")
	assert(systemsFolder ~= nil, "No se encontró 'ReplicatedStorage.Shared.Systems'")

	local npcFolder = systemsFolder:FindFirstChild("Npc")
	assert(npcFolder ~= nil, "No se encontró 'ReplicatedStorage.Shared.Systems.Npc'")

	local enemyAIData = npcFolder:FindFirstChild("EnemyAIData")
	assert(enemyAIData ~= nil, "No se encontró el módulo 'EnemyAIData' en ReplicatedStorage.Shared.Systems.Npc")
end)

---------------------------------------------------------------------------
-- 7. SISTEMA DE MENÚ (ACCESO RÁPIDO Y DESCONEXIÓN)
---------------------------------------------------------------------------
SystemTester:AddTest("7. Módulos de Menú (MenuView y MenuController)", function()
	local StarterPlayer = game:GetService("StarterPlayer")
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	assert(starterScripts ~= nil, "StarterPlayerScripts no existe.")

	local clientFolder = starterScripts:FindFirstChild("Client")
	assert(clientFolder ~= nil, "Carpeta Client no encontrada en StarterPlayerScripts.")

	-- Validar MenuController
	local menuController = clientFolder:FindFirstChild("Systems")
		and clientFolder.Systems:FindFirstChild("Menu")
		and clientFolder.Systems.Menu:FindFirstChild("MenuController")
	assert(menuController ~= nil, "MenuController.luau no encontrado en Client/Systems/Menu/")

	-- Validar MenuView
	local menuView = clientFolder:FindFirstChild("UI")
		and clientFolder.UI:FindFirstChild("Views")
		and clientFolder.UI.Views:FindFirstChild("MenuView")
	assert(menuView ~= nil, "MenuView.luau no encontrado en Client/UI/Views/")
end)

---------------------------------------------------------------------------
-- 🚀 EJECUCIÓN POST-KNIT
---------------------------------------------------------------------------
Knit.OnStart():andThen(function()
	task.wait(2)
	SystemTester:RunAll()
end):catch(warn)
