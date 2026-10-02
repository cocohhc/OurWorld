local ClassData = {}

export type ClassSubtype = {
	Name: string,
	DefaultWeapon: string,
	DefaultItemId: string,
	Description: string,
}

export type ClassInfo = {
	Name: string,
	Description: string,
	Lore: string,
	DefaultItemId: string,
	DefaultPersonality: string,
	Subtypes: { [string]: ClassSubtype },
}

ClassData.Classes = {
	-- 🛡️ 1. VANGUARDIA (Combate Físico y Táctico)
	Vanguard = {
		Name = "Vanguardia",
		Description = "Baluarte del frente de batalla capacitado en combate cercano e interceptación pesada.",
		Lore = "Los Vanguardia forjaron su código de honor en las murallas de WhishGo. Canales de disciplina pura y temple indestructible que repelen cualquier amenaza antes de que alcance al resto del escuadrón.",
		DefaultItemId = "SunBlade",
		DefaultPersonality = "Heroic",
		Subtypes = {
			Greatsword = {
				Name = "Mandoble Solar",
				DefaultWeapon = "Mandoble de Helios",
				DefaultItemId = "SunBlade",
				Description = "Ataques de gran alcance con daño cortante masivo.",
			},
			Aegis = {
				Name = "Guardia con Escudo",
				DefaultWeapon = "Lanza y Baluarte",
				DefaultItemId = "AegisSpear",
				Description = "Enfocado en la defensa absoluta y contraataques rápidos.",
			},
		},
	} :: ClassInfo,

	-- 🔮 2. CRONOMANTE (Magia Arcana y Control Temporal)
	Chronomancer = {
		Name = "Cronomante",
		Description = "Erudito del flujo temporal y las artes arcanas, capaz de distorsionar el campo de batalla.",
		Lore = "Especialistas que aprendieron a sintonizar su maná con el pulso del cosmos. Manipulan la realidad y el tiempo para desgastar a sus oponentes desde la distancia.",
		DefaultItemId = "ChronoOrb",
		DefaultPersonality = "Elegant",
		Subtypes = {
			TimeOrb = {
				Name = "Orbe Temporal",
				DefaultWeapon = "Orbe del Continuo",
				DefaultItemId = "ChronoOrb",
				Description = "Canaliza ráfagas arcanas continuas e inflige ralentización.",
			},
			VoidStaff = {
				Name = "Báculo del Vacío",
				DefaultWeapon = "Báculo Abisal",
				DefaultItemId = "VoidStaff",
				Description = "Hechizos de área de gran impacto y daño canalizado.",
			},
		},
	} :: ClassInfo,

	-- 🔨 3. TITÁN (Fuerza Bruta y Control de Masas)
	Titan = {
		Name = "Titán de las Quebradas",
		Description = "Coloso e imponente guerrero que utiliza la fuerza bruta para aplastar a sus enemigos.",
		Lore = "Descendientes de los antiguos constructores de piedra radiactiva. Su piel ha sido endurecida por generaciones en terrenos hostiles y su impacto hace temblar la tierra.",
		DefaultItemId = "WarHammer",
		DefaultPersonality = "Berserker",
		Subtypes = {
			WarHammer = {
				Name = "Gran Mazo",
				DefaultWeapon = "Mazo Destrozador",
				DefaultItemId = "WarHammer",
				Description = "Golpes lentos pero devastadores que aturden a los rivales.",
			},
			DualAxes = {
				Name = "Hachas Dobles",
				DefaultWeapon = "Hachas de Plomo",
				DefaultItemId = "DualAxes",
				Description = "Combate vertiginoso en ráfagas de cortes continuos.",
			},
		},
	} :: ClassInfo,

	-- 🗡️ 4. SOMBRÍO (Agilidad, Veneno y Distancia)
	Shadow = {
		Name = "Sombrío",
		Description = "Asesino sigiloso y tirador de precisión especialista en ráfagas de daño crítico.",
		Lore = "Acechadores que operan en las grietas sombrías del mundo. Atacan sin dejar rastro y desaparecen antes de que la víctima note su presencia.",
		DefaultItemId = "ShadowDaggers",
		DefaultPersonality = "Stealthy",
		Subtypes = {
			Daggers = {
				Name = "Dagas Venenosas",
				DefaultWeapon = "Dagas Sombrías",
				DefaultItemId = "ShadowDaggers",
				Description = "Ataques de altísima velocidad con daño por veneno.",
			},
			PlasmaBow = {
				Name = "Arco de Plasma",
				DefaultWeapon = "Arco Furia Plasma",
				DefaultItemId = "PlasmaBow",
				Description = "Proyectiles de precisión a larga distancia.",
			},
		},
	} :: ClassInfo,
}

return ClassData
