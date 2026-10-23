--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)
local PickaxeRoulette = require(script.Parent.Parent.PickaxeRoll.PickaxeRoulette)

local ANNOUNCE_DURATION = 4

local PickaxeRollController = Knit.CreateController({
	Name = "PickaxeRollController",
})

local function announce(text: any): ()
	if type(text) ~= "string" then
		return
	end
	-- SetCore throws until the core scripts are ready; a missed line is fine.
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = RollConfig.AnnounceTitle,
		Text = text,
		Duration = ANNOUNCE_DURATION,
	})
end

function PickaxeRollController:KnitStart()
	local rollService = Knit.GetService("PickaxeRollService")

	local roulette = PickaxeRoulette.new(function(pickaxeId: string)
		rollService.TakeRequested:Fire(pickaxeId)
	end)

	rollService.Rolled:Connect(function(payload: any)
		if type(payload) == "table" then
			roulette:Rolled(payload.Id)
		end
	end)
	rollService.Collection:Connect(function(collection: any)
		roulette:SetCollection(collection)
	end)
	rollService.Announced:Connect(announce)

	-- Subscribed before asking, so a collection pushed in between is not missed.
	local collection = rollService:GetCollection()
	if collection then
		roulette:SetCollection(collection)
	end
end

return PickaxeRollController
