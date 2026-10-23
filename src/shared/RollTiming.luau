--!strict
local RollConfig = require(script.Parent.Config.RollConfig)

local RollTiming = {}

function RollTiming.GetRollDuration(): number
	return RollConfig.SpinDuration + RollConfig.SettleTime + RollConfig.RevealDelay
end

function RollTiming.GetTickTime(index: number): number
	local ticks = RollConfig.SpinTicks
	local ratio = RollConfig.TickSlowdownRatio ^ (1 / (ticks - 1))
	return RollConfig.SpinDuration * (ratio ^ index - 1) / (ratio ^ ticks - 1)
end

return RollTiming
