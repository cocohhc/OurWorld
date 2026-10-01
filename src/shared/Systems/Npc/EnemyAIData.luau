-- src/shared/Systems/Npc/EnemyAIData.luau
-- Módulo de configuración estática para la Inteligencia Artificial Táctica de Enemigos.

export type EnemyAIConfig = {
	FieldOfView: number,        -- Ángulo de visión frontal en grados (ej. 120°)
	VisionDistance: number,     -- Distancia máxima de visión en studs
	AlertDistance: number,      -- Distancia de detección inmediata (oído/presencia cercana)
	AttackRange: number,        -- Distancia de alcance de ataque
	AttackCooldown: number,     -- Cooldown base entre ataques en segundos
	CanHeal: boolean,           -- Si el enemigo tiene capacidad de auto-curación
	HealThreshold: number,      -- Porcentaje de vida (0.0 a 1.0) para intentar curarse
	HealAmount: number,         -- Cantidad de vida restaurada por curación
	HealCooldown: number,       -- Cooldown entre habilidades de curación
	ParryChance: number,        -- Probabilidad (0.0 a 1.0) de ejecutar un parry al ser atacado
	ParryCooldown: number,      -- Cooldown de la habilidad de parry
	PatrolSpeed: number,        -- Velocidad al patrullar o estar inactivo
	ChaseSpeed: number,         -- Velocidad al perseguir al jugador
}

local EnemyAIData = {}

-- Configuración por defecto
local DEFAULT_CONFIG: EnemyAIConfig = {
	FieldOfView = 120,
	VisionDistance = 45,
	AlertDistance = 12,
	AttackRange = 6,
	AttackCooldown = 1.8,
	CanHeal = false,
	HealThreshold = 0.20,
	HealAmount = 25,
	HealCooldown = 15,
	ParryChance = 0.10,
	ParryCooldown = 8,
	PatrolSpeed = 8,
	ChaseSpeed = 16,
}

-- Perfiles de IA por tipo de enemigo, raza o clase
local CONFIGS: { [string]: EnemyAIConfig } = {
	Default = DEFAULT_CONFIG,

	-- Bandido (Equilibrado, ágil en persecución y combate)
	Bandido = {
		FieldOfView = 120,
		VisionDistance = 45,
		AlertDistance = 12,
		AttackRange = 6,
		AttackCooldown = 1.5,
		CanHeal = false,
		HealThreshold = 0.0,
		HealAmount = 0,
		HealCooldown = 0,
		ParryChance = 0.15,
		ParryCooldown = 8,
		PatrolSpeed = 8,
		ChaseSpeed = 12,
	},
}

function EnemyAIData.GetConfig(enemyType: string?): EnemyAIConfig
	if not enemyType then
		print("[EnemyAIData] [DEBUG] Tipo no especificado. Asignando configuración 'Default'.")
		return DEFAULT_CONFIG
	end

	local config = CONFIGS[enemyType]
	if not config then
		print(string.format("[EnemyAIData] [WARN] Configuración no encontrada para '%s'. Usando 'Default'.", tostring(enemyType)))
		return DEFAULT_CONFIG
	end

	print(string.format("[EnemyAIData] [DEBUG] Configuración de IA obtenida correctamente para '%s'.", enemyType))
	return config
end

print("[EnemyAIData] Módulo de configuración de IA cargado con éxito.")

return EnemyAIData
