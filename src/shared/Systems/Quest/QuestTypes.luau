export type ObjectiveType = "Kill" | "Interact" | "Collect" | "ReachArea"

export type Objective = {
	Type: ObjectiveType,
	TargetId: string, -- Ej: "Slime", "NPC_Elder", "Item_Herb"
	RequiredAmount: number,
	Description: string,
}

export type Reward = {
	Type: "Exp" | "Gold" | "Item",
	Id: string?, -- Necesario si Type == "Item" (ej: "Sword")
	Amount: number,
}

export type Quest = {
	Id: string,
	Title: string,
	Description: string,
	Zone: string,
	PrerequisiteQuestId: string?, -- ID de la misión previa requerida
	Objectives: { Objective },
	Rewards: { Reward },
}

return nil