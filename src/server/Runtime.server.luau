local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local serverFolder = ServerScriptService:WaitForChild("Server")
local systemsFolder = serverFolder:WaitForChild("Systems")
local coreFolder = serverFolder:WaitForChild("Core")

-- Función para buscar y requerir servicios o managers dentro de una carpeta
local function loadModules(folder)
	for _, module in ipairs(folder:GetDescendants()) do
		if module:IsA("ModuleScript") and (module.Name:find("Service$") or module.Name:find("Manager$")) then
			require(module)
		end
	end
end

-- Cargamos los módulos de ambas carpetas
loadModules(systemsFolder)
loadModules(coreFolder)

Knit.Start():andThen(function()
	print("[Knit] Todos los servicios del servidor han iniciado.")
end):catch(warn)