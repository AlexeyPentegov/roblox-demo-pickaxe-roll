--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local DevScene = require(script.Parent.DevScene)

DevScene.Ensure()

Knit.AddServices(script.Parent.Services)
Knit.Start():catch(warn)
