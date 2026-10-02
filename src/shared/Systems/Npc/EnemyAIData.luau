-- src/shared/Systems/Npc/EnemyAIData.luau
-- Módulo de configuración estática para la Inteligencia Artificial Táctica de Enemigos.

export type Archetype = "Aggressive" | "Tactical" | "Evasive"

export type EnemyAIConfig = {
	FieldOfView: number,        -- Ángulo de visión frontal en grados (ej. 120°)
	VisionDistance: number,     -- Distancia máxima de visión en studs
	AlertDistance: number,      -- Distancia de detección inmediata por proximidad
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
	FleeThreshold: number,      -- Porcentaje de vida (0.0 a 1.0) para activar huida de emergencia
	FleeSpeed: number,          -- Velocidad de movimiento acelerada durante la huida evasiva

	-- Nuevos parámetros para toma de decisiones natural
	Archetype: Archetype,       -- Arquetipo de comportamiento ("Aggressive", "Tactical", "Evasive")
	ReactionTime: number,       -- Ventana de retardo de reacción humana en segundos (ej. 0.20s)
	Aggressiveness: number,     -- Ponderación de propensión al ataque (0.0 a 1.0)
	FlankPreference: number,    -- Tendencia a rodear/flanquear en vez de avanzar directo (0.0 a 1.0)
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
	FleeThreshold = 0.25,
	FleeSpeed = 18,
	Archetype = "Tactical",
	ReactionTime = 0.25,
	Aggressiveness = 0.50,
	FlankPreference = 0.40,
}

-- Perfiles de IA por tipo de enemigo, raza o clase
local CONFIGS: { [string]: EnemyAIConfig } = {
	Default = DEFAULT_CONFIG,

	-- Bandido (Táctico, ágil y opportunista)
	Bandido = {
		FieldOfView = 120,
		VisionDistance = 45,
		AlertDistance = 12,
		AttackRange = 6,
		AttackCooldown = 1.4,
		CanHeal = false,
		HealThreshold = 0.0,
		HealAmount = 0,
		HealCooldown = 0,
		ParryChance = 0.20,
		ParryCooldown = 6,
		PatrolSpeed = 8,
		ChaseSpeed = 16,
		FleeThreshold = 0.20,
		FleeSpeed = 19,
		Archetype = "Tactical",
		ReactionTime = 0.20,
		Aggressiveness = 0.60,
		FlankPreference = 0.65,
	},

	-- Mutante Rabioso (Agresivo, impulsivo y difícil de frenar)
	Mutant_Rad = {
		FieldOfView = 140,
		VisionDistance = 50,
		AlertDistance = 15,
		AttackRange = 7,
		AttackCooldown = 1.1,
		CanHeal = false,
		HealThreshold = 0.0,
		HealAmount = 0,
		HealCooldown = 0,
		ParryChance = 0.05,
		ParryCooldown = 12,
		PatrolSpeed = 10,
		ChaseSpeed = 18,
		FleeThreshold = 0.10,
		FleeSpeed = 20,
		Archetype = "Aggressive",
		ReactionTime = 0.15,
		Aggressiveness = 0.90,
		FlankPreference = 0.15,
	},

	-- Soldado de Élite (Táctico con alta capacidad defensiva)
	Elite_Soldier = {
		FieldOfView = 130,
		VisionDistance = 55,
		AlertDistance = 16,
		AttackRange = 6.5,
		AttackCooldown = 1.3,
		CanHeal = true,
		HealThreshold = 0.30,
		HealAmount = 35,
		HealCooldown = 12,
		ParryChance = 0.35,
		ParryCooldown = 5,
		PatrolSpeed = 9,
		ChaseSpeed = 17,
		FleeThreshold = 0.15,
		FleeSpeed = 19,
		Archetype = "Tactical",
		ReactionTime = 0.18,
		Aggressiveness = 0.70,
		FlankPreference = 0.80,
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
