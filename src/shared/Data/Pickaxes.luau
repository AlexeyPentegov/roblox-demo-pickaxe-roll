--!strict
export type Pickaxe = {
	Id: string,
	Name: string,
	ModelName: string,
	Tier: number,
	Chance: number,
}

local PICKAXES: { Pickaxe } = {
	{ Id = "Stone", Name = "Stone Pickaxe", ModelName = "Stone Pickaxe", Tier = 1, Chance = 50 },
	{ Id = "Golden", Name = "Golden Pickaxe", ModelName = "Golden Pickaxe", Tier = 2, Chance = 28 },
	{ Id = "Frostbite", Name = "Frostbite Pickaxe", ModelName = "Frostbite Pickaxe", Tier = 3, Chance = 14 },
	{ Id = "JungleStriker", Name = "Jungle Striker", ModelName = "Jungle Striker", Tier = 4, Chance = 6 },
	{ Id = "CryoArc", Name = "Cryo Arc Pick", ModelName = "Cryo Arc Pick", Tier = 5, Chance = 1.8 },
	{ Id = "TribalNightfang", Name = "Tribal Nightfang", ModelName = "Tribal Nightfang", Tier = 6, Chance = 0.2 },
}

return PICKAXES
