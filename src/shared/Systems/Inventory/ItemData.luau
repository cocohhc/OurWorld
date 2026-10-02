local ItemData = {}

export type ItemConfig = {
	Name: string,
	Description: string,
	WeaponType: "Sword" | "Spear" | "Orb" | "Staff" | "Hammer" | "Axe" | "Dagger" | "Bow",
	Damage: number,
	Rarity: "Common" | "Rare" | "Epic" | "Legendary",
	Icon: string?,
}

ItemData.Items = {
	-- 🗡️ Armas de Vanguardia
	SunBlade = {
		Name = "Mandoble de Helios",
		Description = "Espada pesada forjada con aleación solar de alto impacto.",
		WeaponType = "Sword",
		Damage = 35,
		Rarity = "Rare",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	AegisSpear = {
		Name = "Lanza del Baluarte",
		Description = "Lanza táctica diseñada para perforar defensas sin exponer al portador.",
		WeaponType = "Spear",
		Damage = 28,
		Rarity = "Common",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	-- 🔮 Armas de Cronomante
	ChronoOrb = {
		Name = "Orbe del Continuo",
		Description = "Reliquia flotante que canaliza pulsos de energía temporal.",
		WeaponType = "Orb",
		Damage = 22,
		Rarity = "Epic",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	VoidStaff = {
		Name = "Báculo Abisal",
		Description = "Báculo canalizador de corrientes de vacilaciones arcanas.",
		WeaponType = "Staff",
		Damage = 40,
		Rarity = "Epic",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	-- 🔨 Armas de Titán
	WarHammer = {
		Name = "Mazo Destrozador",
		Description = "Colosal martillo capaz de quebrar armaduras pesadas de un solo impacto.",
		WeaponType = "Hammer",
		Damage = 50,
		Rarity = "Rare",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	DualAxes = {
		Name = "Hachas de Plomo",
		Description = "Par de hachas equilibradas para ataques brutales a corta distancia.",
		WeaponType = "Axe",
		Damage = 30,
		Rarity = "Common",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	-- 🗡️ Armas de Sombrío
	ShadowDaggers = {
		Name = "Dagas Sombrías",
		Description = "Hojas gemelas impregnadas en neurotoxina de baja frecuencia.",
		WeaponType = "Dagger",
		Damage = 18,
		Rarity = "Rare",
		Icon = "rbxassetid://0",
	} :: ItemConfig,

	PlasmaBow = {
		Name = "Arco Furia Plasma",
		Description = "Arco de alta tecnología que proyecta flechas de energía pura.",
		WeaponType = "Bow",
		Damage = 32,
		Rarity = "Legendary",
		Icon = "rbxassetid://0",
	} :: ItemConfig,
}

return ItemData
