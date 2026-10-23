--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PickaxeCatalog = require(ReplicatedStorage.Shared.PickaxeCatalog)
local RarityCatalog = require(ReplicatedStorage.Shared.RarityCatalog)
local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)
local RollTiming = require(ReplicatedStorage.Shared.RollTiming)
local SceneConfig = require(ReplicatedStorage.Shared.Config.SceneConfig)

export type Rolled = {
	Id: string,
	IsBest: boolean,
}

export type Collection = {
	Seen: { string },
	Equipped: string?,
}

local PickaxeService

local PickaxeRollService = Knit.CreateService({
	Name = "PickaxeRollService",
	Client = {
		Rolled = Knit.CreateSignal(),
		Collection = Knit.CreateSignal(),
		Announced = Knit.CreateSignal(),
		TakeRequested = Knit.CreateSignal(),
	},

	_rng = Random.new(),
	_nextRollAt = {} :: { [Player]: number },
	_pedestals = {} :: { [string]: BasePart },
})

local function tagged(model: Model, tag: string): { BasePart }
	local found = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(tag) then
			table.insert(found, descendant)
		end
	end
	return found
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function PickaxeRollService:_getCollection(player: Player): Collection?
	if not PickaxeService:GetData(player) then
		return nil
	end
	local equipped = PickaxeService:GetEquipped(player)
	return {
		Seen = PickaxeService:GetSeen(player),
		Equipped = if equipped then equipped.Id else nil,
	}
end

function PickaxeRollService:_sendCollection(player: Player): ()
	local collection = self:_getCollection(player)
	if collection then
		self.Client.Collection:Fire(player, collection)
	end
end

function PickaxeRollService.Client:GetCollection(player: Player): Collection?
	return self.Server:_getCollection(player)
end

function PickaxeRollService:_take(player: Player, pickaxeId: any): ()
	local pickaxe = PickaxeCatalog.Get(pickaxeId)
	local pedestal = pickaxe and self._pedestals[pickaxe.Id]
	local root = rootOf(player)
	if not pickaxe or not pedestal or not root then
		return
	end
	local reach = RollConfig.TakePromptMaxDistance + RollConfig.TakeLatencyTolerance
	if (root.Position - pedestal.Position).Magnitude > reach then
		return
	end
	-- Mid-spin the roll is recorded but not revealed; a take now would give it away.
	if os.clock() < (self._nextRollAt[player] or 0) then
		return
	end
	if not PickaxeService:Equip(player, pickaxe.Id) then
		return
	end
	self:_sendCollection(player)
end

function PickaxeRollService:_wirePrompt(marker: BasePart): ()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = RollConfig.PromptText
	prompt.ObjectText = RollConfig.PromptObjectText
	prompt.HoldDuration = RollConfig.PromptHoldDuration
	prompt.MaxActivationDistance = RollConfig.PromptMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker
	prompt.Triggered:Connect(function(player: Player)
		self:_roll(player)
	end)
end

function PickaxeRollService:_roll(player: Player): ()
	local now = os.clock()
	if now < (self._nextRollAt[player] or 0) then
		return
	end

	local pickaxe = PickaxeCatalog.Roll(self._rng)
	local isBest = PickaxeService:RecordRoll(player, pickaxe)
	if isBest == nil then
		return
	end
	self._nextRollAt[player] = now + RollTiming.GetRollDuration()

	local rolled: Rolled = { Id = pickaxe.Id, IsBest = isBest }
	self.Client.Rolled:Fire(player, rolled)
	AnalyticsService:LogCustomEvent(player, RollConfig.AnalyticsEvent, pickaxe.Tier, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = pickaxe.Id,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(isBest),
	})

	task.delay(RollTiming.GetRollDuration(), function()
		if player.Parent ~= Players then
			return
		end
		self:_announce(player, pickaxe, isBest)
		self:_sendCollection(player)
	end)
end

function PickaxeRollService:_announce(player: Player, pickaxe: PickaxeCatalog.Pickaxe, isBest: boolean): ()
	local rarity = RarityCatalog.GetName(pickaxe.Tier)
	if isBest then
		self.Client.Announced:Fire(player, `New best: {pickaxe.Name} ({rarity})!`)
	else
		local equipped = PickaxeService:GetEquipped(player)
		local keep = if equipped then `, you keep your {equipped.Name}` else ""
		self.Client.Announced:Fire(player, `{pickaxe.Name} ({rarity}){keep}`)
	end

	if pickaxe.Tier >= RollConfig.AnnounceTier then
		self.Client.Announced:FireAll(`{player.DisplayName} rolled a {rarity} {pickaxe.Name}!`)
	end
end

function PickaxeRollService:KnitInit()
	PickaxeService = Knit.GetService("PickaxeService")
end

function PickaxeRollService:KnitStart()
	local scene = CollectionService:GetTagged(SceneConfig.SceneTag)[1]
	if not scene or not scene:IsA("Model") then
		warn(`[PickaxeRollService] no model tagged {SceneConfig.SceneTag}; the chest is disabled`)
		return
	end

	local marker = tagged(scene, SceneConfig.PromptMarkerTag)[1]
	if marker then
		self:_wirePrompt(marker)
	else
		warn(`[PickaxeRollService] no {SceneConfig.PromptMarkerTag} marker in {scene:GetFullName()}`)
	end
	for _, pedestal in tagged(scene, SceneConfig.DisplayMarkerTag) do
		local pickaxe = PickaxeCatalog.GetByRarityName(pedestal:GetAttribute(SceneConfig.RarityAttribute))
		if pickaxe then
			self._pedestals[pickaxe.Id] = pedestal
		end
	end

	self.Client.TakeRequested:Connect(function(player: Player, pickaxeId: any)
		self:_take(player, pickaxeId)
	end)
	PickaxeService.Ready:Connect(function(player: Player)
		self:_sendCollection(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self._nextRollAt[player] = nil
	end)
end

return PickaxeRollService
