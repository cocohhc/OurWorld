local QuestTypes = require(script.Parent.Parent.QuestTypes)

local Zone1Quests: { [string]: QuestTypes.Quest } = {
	["Q_Z1_001"] = {
		Id = "Q_Z1_001",
		Title = "El Despertar",
  		Description = "En el pueblo estan llegando unos bandidos a perturbar y a saquear el ancioano te pidio que te encargues de ellos.",
		Zone = "Zone1",
		PrerequisiteQuestId = nil,
		Objectives = {
			{
				Type = "Kill",
				TargetId = "Bandido", -- Corregido para coincidir con el Attribute NPCId del Workspace
				RequiredAmount = 5,
				Description = "Mata 5 NPCs",
			},
		},
		Rewards = {
			{ Type = "Exp", Amount = 100 },
			{ Type = "Gold", Amount = 50 },
		},
	},

	["Q_Z1_002"] = {
		Id = "Q_Z1_002",
		Title = "Limpieza de Plagas",
		Description = "Los slimes de las afueras están molestando a los aldeanos. Elimina algunos.",
		Zone = "Zone1",
		PrerequisiteQuestId = "Q_Z1_001",
		Objectives = {
			{
				Type = "Kill",
				TargetId = "Slime",
				RequiredAmount = 5,
				Description = "Derrota Slimes (0/5)",
			},
		},
		Rewards = {
			{ Type = "Exp", Amount = 250 },
			{ Type = "Gold", Amount = 120 },
			{ Type = "Item", Id = "Sword", Amount = 1 },
		},
	},
}

return Zone1Quests
