--!strict
return {
	PromptText = "Roll",
	PromptObjectText = "Pickaxe Chest",
	PromptHoldDuration = 0,
	PromptMaxDistance = 12,

	TakePromptText = "Take",
	TakePromptHoldDuration = 0,
	TakePromptMaxDistance = 7,
	TakeLatencyTolerance = 4,

	SpinDuration = 3,
	SpinTicks = 20,
	SpinTiltDegrees = 10,
	TickSlowdownRatio = 8,
	SettleTime = 0.18,
	RevealDelay = 0.7,
	RiseStartOffset = Vector3.new(0, -3, 0),
	RevealSpinRpm = 20,
	RevealHoldTime = 5,
	LidOpenTime = 0.45,

	PedestalRpm = 12,
	PedestalMaxSize = 4.5,
	LockedName = "???",
	LockedOutlineTransparency = 0.6,
	SilhouetteColor = Color3.new(0, 0, 0),
	HighlightCycle = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 214, 64),
		Color3.fromRGB(94, 214, 255),
		Color3.fromRGB(255, 108, 168),
		Color3.fromRGB(150, 255, 128),
		Color3.fromRGB(186, 126, 255),
	},

	RevealLightRange = 14,
	RevealLightBrightness = 3,
	RevealSparkleTier = 4,

	TickSound = "rbxassetid://9120658649",
	TickVolume = 0.35,
	TickPitchStart = 1.05,
	TickPitchEnd = 0.85,
	LidSound = "rbxassetid://130029763520057",
	LidVolume = 0.5,
	SoundRollOffDistance = 60,

	AnnounceTier = 5,
	AnnounceTitle = "Pickaxe Chest",
	AnalyticsEvent = "PickaxeRolled",
}
