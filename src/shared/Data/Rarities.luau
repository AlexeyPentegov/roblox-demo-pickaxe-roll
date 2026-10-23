--!strict
export type SoundSpec = {
	Id: string,
	PlaybackSpeed: number,
	Volume: number,
}

export type Rarity = {
	Tier: number,
	Name: string,
	Color: Color3,
	Sound: SoundSpec,
}

local CHIME_2_1 = "rbxassetid://9116394545"
local CHIME_2_4 = "rbxassetid://9116394876"
local CHIME_2_9 = "rbxassetid://9116395089"
local CHIME_3_8 = "rbxassetid://9116395179"

local function sound(id: string, playbackSpeed: number, volume: number): SoundSpec
	return { Id = id, PlaybackSpeed = playbackSpeed, Volume = volume }
end

local RARITIES: { Rarity } = {
	{ Tier = 1, Name = "Common", Color = Color3.fromRGB(176, 182, 192), Sound = sound(CHIME_2_1, 1.25, 0.45) },
	{ Tier = 2, Name = "Uncommon", Color = Color3.fromRGB(76, 217, 100), Sound = sound(CHIME_2_1, 1.15, 0.5) },
	{ Tier = 3, Name = "Rare", Color = Color3.fromRGB(46, 134, 255), Sound = sound(CHIME_2_4, 1.1, 0.55) },
	{ Tier = 4, Name = "Epic", Color = Color3.fromRGB(166, 76, 255), Sound = sound(CHIME_2_4, 1, 0.6) },
	{ Tier = 5, Name = "Legendary", Color = Color3.fromRGB(255, 163, 32), Sound = sound(CHIME_2_9, 1, 0.65) },
	{ Tier = 6, Name = "Mythic", Color = Color3.fromRGB(255, 59, 107), Sound = sound(CHIME_3_8, 1, 0.7) },
}

return RARITIES
