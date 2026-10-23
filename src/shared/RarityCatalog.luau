--!strict
local Rarities = require(script.Parent.Data.Rarities)

export type Rarity = Rarities.Rarity

local FALLBACK_COLOR = Color3.new(1, 1, 1)

for index, rarity in Rarities do
	assert(rarity.Tier == index, `Rarities: {rarity.Name} is listed at {index} with Tier {rarity.Tier}`)
end

local RarityCatalog = {
	All = Rarities,
}

function RarityCatalog.Get(tier: number?): Rarity?
	if type(tier) ~= "number" then
		return nil
	end
	return Rarities[tier]
end

function RarityCatalog.GetName(tier: number?): string
	local rarity = RarityCatalog.Get(tier)
	return if rarity then rarity.Name else "Unknown"
end

function RarityCatalog.GetColor(tier: number?): Color3
	local rarity = RarityCatalog.Get(tier)
	return if rarity then rarity.Color else FALLBACK_COLOR
end

return RarityCatalog
