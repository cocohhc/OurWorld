-- src/server/Systems/Progression/ProgressionService.luau
-- Servicio encargado del cálculo de Experiencia, Niveles y Puntos de Evolución.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ProgressionService = Knit.CreateService({
	Name = "ProgressionService",
	Client = {
		ProgressionUpdated = Knit.CreateSignal(),
	},
})

-- Fórmula de XP Requerida: math.floor(100 * (level ^ 1.5))
function ProgressionService:GetRequiredXP(level: number): number
	return math.floor(100 * (math.max(1, level) ^ 1.5))
end

function ProgressionService:AddXP(player: Player, amount: number)
	if not player or amount <= 0 then return end

	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	local activeSlot = PlayerDataManager:GetActiveSlot(player)
	if not activeSlot then return end

	activeSlot.XP = (activeSlot.XP or 0) + amount
	local currentLevel = activeSlot.Level or 1
	local requiredXP = self:GetRequiredXP(currentLevel)

	local leveledUp = false

	-- Procesar subida de múltiples niveles si la XP otorgada es alta
	while activeSlot.XP >= requiredXP do
		activeSlot.XP -= requiredXP
		currentLevel += 1
		activeSlot.Level = currentLevel
		activeSlot.EvolutionPoints = (activeSlot.EvolutionPoints or 0) + 1
		leveledUp = true
		requiredXP = self:GetRequiredXP(currentLevel)
	end

	activeSlot.MaxXP = requiredXP

	-- Sincronizar los atributos del personaje en la instancia de Player
	if PlayerDataManager.ApplyPlayerAttributes then
		PlayerDataManager:ApplyPlayerAttributes(player, activeSlot)
	end

	if leveledUp then
		print(`🎉 [ProgressionService] {player.Name} subió al Nivel {currentLevel}! Puntos de Evolución acumulados: {activeSlot.EvolutionPoints}`)
	end

	-- Sincronizar datos con el cliente
	self.Client.ProgressionUpdated:Fire(player, {
		Level = activeSlot.Level,
		XP = activeSlot.XP,
		MaxXP = requiredXP,
		EvolutionPoints = activeSlot.EvolutionPoints,
		LeveledUp = leveledUp,
	})
end

function ProgressionService.Client:GetProgressionData(player: Player)
	local PlayerDataManager = Knit.GetService("PlayerDataManager")
	local activeSlot = PlayerDataManager:GetActiveSlot(player)
	if not activeSlot then return nil end

	local level = activeSlot.Level or 1
	return {
		Level = level,
		XP = activeSlot.XP or 0,
		MaxXP = self.Server:GetRequiredXP(level),
		EvolutionPoints = activeSlot.EvolutionPoints or 0,
	}
end

function ProgressionService:KnitStart()
	print("⭐ [ProgressionService] Servicio de progresión y experiencia cargado.")
end

return ProgressionService
