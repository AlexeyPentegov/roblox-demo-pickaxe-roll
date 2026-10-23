--!strict
local Pickaxes = require(script.Parent.Data.Pickaxes)
local RarityCatalog = require(script.Parent.RarityCatalog)

export type Pickaxe = Pickaxes.Pickaxe

local TOTAL_CHANCE = 100
local CHANCE_EPSILON = 1e-6

local byId: { [string]: Pickaxe } = {}
local totalChance = 0
for index, pickaxe in Pickaxes do
	assert(pickaxe.Tier == index, `Pickaxes: {pickaxe.Id} is listed at {index} with Tier {pickaxe.Tier}`)
	assert(RarityCatalog.Get(pickaxe.Tier), `Pickaxes: {pickaxe.Id} has no rarity tier {pickaxe.Tier}`)
	byId[pickaxe.Id] = pickaxe
	totalChance += pickaxe.Chance
end
assert(math.abs(totalChance - TOTAL_CHANCE) < CHANCE_EPSILON, `Pickaxes: chances sum to {totalChance}`)

local PickaxeCatalog = {
	All = Pickaxes,
}

function PickaxeCatalog.Get(id: any): Pickaxe?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function PickaxeCatalog.GetByTier(tier: number): Pickaxe?
	return Pickaxes[tier]
end

function PickaxeCatalog.GetByRarityName(name: any): Pickaxe?
	for _, rarity in RarityCatalog.All do
		if rarity.Name == name then
			return Pickaxes[rarity.Tier]
		end
	end
	return nil
end

function PickaxeCatalog.FormatChance(pickaxe: Pickaxe): string
	local chance = pickaxe.Chance
	if chance == math.floor(chance) then
		return `{chance}%`
	end
	return string.format("%.1f%%", chance)
end

function PickaxeCatalog.Roll(rng: Random): Pickaxe
	local roll = rng:NextNumber() * TOTAL_CHANCE
	for _, pickaxe in Pickaxes do
		roll -= pickaxe.Chance
		if roll <= 0 then
			return pickaxe
		end
	end
	return Pickaxes[1]
end

return PickaxeCatalog
