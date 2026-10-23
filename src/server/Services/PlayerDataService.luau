--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local STORE_NAME = "PlayerData_v1"
local KICK_MESSAGE = "Your data could not be loaded. Please rejoin."

export type Data = {
	Pickaxe: { [string]: any },
}

local TEMPLATE: Data = {
	Pickaxe = {},
}

local store = ProfileStore.New(STORE_NAME, TEMPLATE)

local PlayerDataService = Knit.CreateService({
	Name = "PlayerDataService",
	Client = {},

	Loaded = Signal.new(),

	_profiles = {} :: { [Player]: any },
})

function PlayerDataService:GetData(player: Player): Data?
	local profile = self._profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService:_load(player: Player): ()
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		player:Kick(KICK_MESSAGE)
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	self._profiles[player] = profile
	self.Loaded:Fire(player, profile.Data)
end

function PlayerDataService:_unload(player: Player): ()
	local profile = self._profiles[player]
	if profile then
		profile:EndSession()
	end
end

function PlayerDataService:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(self._load, self, player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		self:_load(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_unload(player)
	end)
end

return PlayerDataService
