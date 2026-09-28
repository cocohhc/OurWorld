local ClassData = {}

export type ClassInfo = {
	Name: string,
	Description: string,
	Lore: string,
	AvailableWeapons: { string },
	DefaultItemId: string,
	Subtypes: { [string]: { DefaultWeapon: string, DefaultItemId: string } }?,
}

ClassData.Classes = {
	Warrior = {
		Name = "Guerrero",
		Description = "Luchador versátil entrenado en el arte del combate cuerpo a cuerpo y a distancia.",
		Lore = "Nacido en las tierras fronterizas de WhishGo, los Guerreros forjan su destino con acero y temple.",
		AvailableWeapons = { "Espada", "Arco" },
		DefaultItemId = "Sword",
		Subtypes = {
			Sword = { DefaultWeapon = "Espada", DefaultItemId = "Sword" },
			Bow = { DefaultWeapon = "Arco", DefaultItemId = "Bow" },
		},
	} :: ClassInfo,

	Mage = {
		Name = "Mago",
		Description = "Dominante de la energía arcana capaz de canalizar hechizos devastadores.",
		Lore = "Estudiosos de las corrientes de maná que fluyen en las profundidades del mundo.",
		AvailableWeapons = { "Báculo Arcano" },
		DefaultItemId = "Staff",
	} :: ClassInfo,

	Giant = {
		Name = "Gigante",
		Description = "Coloso imparable con una resistencia física formidable.",
		Lore = "Descendientes de los antiguos titanes de piedra, protegen las montañas con su inmensa fuerza.",
		AvailableWeapons = { "Mazo Gigante" },
		DefaultItemId = "Hammer",
	} :: ClassInfo,
}

return ClassData