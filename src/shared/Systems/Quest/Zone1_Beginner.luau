local QuestTypes = require(script.Parent.Parent.QuestTypes)

local Zone1Quests: { [string]: QuestTypes.Quest } = {
	["Q_Z1_001"] = {
		Id = "Q_Z1_001",
		Title = "El Despertar",
		Description = "Habla con el anciano del pueblo para recibir tus primeras instrucciones.",
		Zone = "Zone1",
		PrerequisiteQuestId = nil,
		Objectives = {
			{
				Type = "Interact",
				TargetId = "NPC_Anciano",
				RequiredAmount = 1,
				Description = "Habla con el Anciano",
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