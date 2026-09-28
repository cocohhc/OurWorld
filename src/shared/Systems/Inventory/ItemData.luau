local ItemData = {}

export type Item = {
	Id: string,
	Name: string,
	Type: string,
	WeaponType: string?,
	Description: string,
	Icon: string?, -- 👈 Se agrega la propiedad Icon a la definición de tipo
	Damage: number?,
	HitboxSize: Vector3?,
	HitboxOffset: number?,
	Cooldown: number?,
}

ItemData.Items = {
	Sword = {
		Id = "Sword",
		Name = "Espada de Hierro",
		Type = "Weapon",
		WeaponType = "Sword",
		Description = "Una espada básica pero afilada otorgada a los guerreros novatos.",
		Icon = "rbxassetid://10000000", -- 👈 Coloca aquí el Asset ID real de la textura/icono
		Damage = 25,
		HitboxSize = Vector3.new(5, 5, 6),
		HitboxOffset = 4,
		Cooldown = 0.6,
	} :: Item,

	Bow = {
		Id = "Bow",
		Name = "Arco de Caza",
		Type = "Weapon",
		WeaponType = "Bow",
		Description = "Un arco flexible ideal para ataques a distancia.",
		Icon = "rbxassetid://10000001", -- 👈 ID del icono del arco
		Damage = 18,
		HitboxSize = Vector3.new(4, 4, 15),
		HitboxOffset = 9,
		Cooldown = 1.0,
	} :: Item,

	Staff = {
		Id = "Staff",
		Name = "Báculo Arcano",
		Type = "Weapon",
		WeaponType = "Staff",
		Description = "Canaliza las corrientes de maná para lanzar hechizos básicos.",
		Icon = "rbxassetid://10000002", -- 👈 ID del icono del báculo
		Damage = 30,
		HitboxSize = Vector3.new(6, 6, 8),
		HitboxOffset = 5,
		Cooldown = 1.2,
	} :: Item,

	Hammer = {
		Id = "Hammer",
		Name = "Mazo Gigante",
		Type = "Weapon",
		WeaponType = "Hammer",
		Description = "Un pesado mazo de piedra que requiere gran fuerza para blandir.",
		Icon = "rbxassetid://10000003", -- 👈 ID del icono del mazo
		Damage = 45,
		HitboxSize = Vector3.new(8, 6, 8),
		HitboxOffset = 5,
		Cooldown = 1.8,
	} :: Item,
}

return ItemData