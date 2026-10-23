--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local PickaxeCatalog = require(ReplicatedStorage.Shared.PickaxeCatalog)

local PICKAXE_ATTRIBUTE = "Pickaxe"

export type PickaxeData = {
	Best: string?,
	Equipped: string?,
	Rolls: number,
	Seen: { [string]: boolean },
}

local PlayerDataService

local PickaxeService = Knit.CreateService({
	Name = "PickaxeService",
	Client = {},

	Ready = Signal.new(),
	BestChanged = Signal.new(),

	_data = {} :: { [Player]: PickaxeData },
})

local function fillMissingFields(data: any): PickaxeData
	data.Best = if PickaxeCatalog.Get(data.Best) then data.Best else nil
	data.Rolls = if type(data.Rolls) == "number" then math.max(math.floor(data.Rolls), 0) else 0
	data.Seen = if type(data.Seen) == "table" then data.Seen else {}
	if data.Best then
		data.Seen[data.Best] = true
	end
	data.Equipped = if PickaxeCatalog.Get(data.Equipped) and data.Seen[data.Equipped] then data.Equipped else nil
	return data
end

function PickaxeService:GetData(player: Player): PickaxeData?
	return self._data[player]
end

function PickaxeService:GetBest(player: Player): PickaxeCatalog.Pickaxe?
	local data = self:GetData(player)
	return if data then PickaxeCatalog.Get(data.Best) else nil
end

function PickaxeService:GetEquipped(player: Player): PickaxeCatalog.Pickaxe?
	local data = self:GetData(player)
	if not data then
		return nil
	end
	return PickaxeCatalog.Get(data.Equipped) or PickaxeCatalog.Get(data.Best)
end

function PickaxeService:GetSeen(player: Player): { string }
	local data = self:GetData(player)
	local seen = {}
	for _, pickaxe in PickaxeCatalog.All do
		if data and data.Seen[pickaxe.Id] then
			table.insert(seen, pickaxe.Id)
		end
	end
	return seen
end

function PickaxeService:Equip(player: Player, pickaxeId: string): boolean
	local data = self:GetData(player)
	if not data or not PickaxeCatalog.Get(pickaxeId) or not data.Seen[pickaxeId] then
		return false
	end
	data.Equipped = pickaxeId
	return true
end

function PickaxeService:RecordRoll(player: Player, pickaxe: PickaxeCatalog.Pickaxe): boolean?
	local data = self:GetData(player)
	if not data then
		return nil
	end
	data.Rolls += 1
	data.Seen[pickaxe.Id] = true

	local best = PickaxeCatalog.Get(data.Best)
	if best and best.Tier >= pickaxe.Tier then
		return false
	end
	data.Best = pickaxe.Id
	data.Equipped = nil
	player:SetAttribute(PICKAXE_ATTRIBUTE, pickaxe.Id)
	self.BestChanged:Fire(player, pickaxe.Id)
	return true
end

function PickaxeService:_track(player: Player, profileData: any): ()
	if self._data[player] or player.Parent ~= Players then
		return
	end
	local data = fillMissingFields(profileData.Pickaxe)
	self._data[player] = data
	player:SetAttribute(PICKAXE_ATTRIBUTE, data.Best)
	self.Ready:Fire(player)
end

function PickaxeService:KnitInit()
	PlayerDataService = Knit.GetService("PlayerDataService")
end

function PickaxeService:KnitStart()
	PlayerDataService.Loaded:Connect(function(player: Player, profileData: any)
		self:_track(player, profileData)
	end)
	for _, player in Players:GetPlayers() do
		local profileData = PlayerDataService:GetData(player)
		if profileData then
			self:_track(player, profileData)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		self._data[player] = nil
	end)
end

return PickaxeService
