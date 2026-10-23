--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PickaxeCatalog = require(ReplicatedStorage.Shared.PickaxeCatalog)
local RarityCatalog = require(ReplicatedStorage.Shared.RarityCatalog)
local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)
local RollTiming = require(ReplicatedStorage.Shared.RollTiming)
local SceneConfig = require(ReplicatedStorage.Shared.Config.SceneConfig)

type Pickaxe = PickaxeCatalog.Pickaxe

local MODEL_WAIT_TIMEOUT = 10
local SCENE_POLL_INTERVAL = 0.25
local READY_WAIT_TIMEOUT = 5
local FULL_TURN = 2 * math.pi
local SECONDS_PER_MINUTE = 60
local LID_OPEN_TWEEN = TweenInfo.new(RollConfig.LidOpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LID_CLOSE_TWEEN = TweenInfo.new(RollConfig.LidOpenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Pedestal = {
	Pickaxe: Pickaxe,
	Model: Model,
	Anchor: CFrame,
	Silhouette: Highlight,
	Label: BillboardGui?,
	Prompt: ProximityPrompt,
}

type Chest = {
	Lid: Model?,
	LidClosed: CFrame?,
	LidOpenAngle: number,
	Reveal: BasePart,
	Start: CFrame,
	End: CFrame,
}

local PickaxeRoulette = {}
PickaxeRoulette.__index = PickaxeRoulette

export type PickaxeRoulette = typeof(setmetatable(
	{} :: {
		_onTake: (pickaxeId: string) -> (),
		_alive: boolean,
		_connections: { RBXScriptConnection },
		_chest: Chest?,
		_pedestals: { Pedestal },
		_seen: { [string]: boolean },
		_equipped: string?,
		_display: { [string]: Model },
		_shown: Model?,
		_highlight: Highlight,
		_tickSound: Sound?,
		_revealLight: PointLight?,
		_revealSparkles: Sparkles?,
		_lidAlpha: NumberValue,
		_lidOpen: boolean,
		_spinning: boolean,
		_rollVersion: number,
		_hoverStartedAt: number?,
	},
	PickaxeRoulette
))

local function templatesFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in SceneConfig.ModelsPath do
		current = current and current:WaitForChild(name, MODEL_WAIT_TIMEOUT)
	end
	return current
end

local function waitForScene(): Model?
	local deadline = os.clock() + MODEL_WAIT_TIMEOUT
	repeat
		local scene = CollectionService:GetTagged(SceneConfig.SceneTag)[1]
		if scene and scene:IsA("Model") then
			return scene
		end
		task.wait(SCENE_POLL_INTERVAL)
	until os.clock() >= deadline
	warn(`[PickaxeRoulette] no model tagged {SceneConfig.SceneTag}`)
	return nil
end

local function cloneTemplate(pickaxe: Pickaxe): Model?
	local folder = templatesFolder()
	local template = folder and folder:FindFirstChild(pickaxe.ModelName)
	if not template or not template:IsA("Model") then
		warn(
			`[PickaxeRoulette] no model '{pickaxe.ModelName}' in ReplicatedStorage.{table.concat(
				SceneConfig.ModelsPath,
				"."
			)}`
		)
		return nil
	end
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	return model
end

local function tagged(model: Model, tag: string): { Instance }
	local found = {}
	for _, descendant in model:GetDescendants() do
		if descendant:HasTag(tag) then
			table.insert(found, descendant)
		end
	end
	return found
end

local function playOnce(parent: Instance, id: string, volume: number, playbackSpeed: number?): ()
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.RollOffMaxDistance = RollConfig.SoundRollOffDistance
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

function PickaxeRoulette.new(onTake: (pickaxeId: string) -> ()): PickaxeRoulette
	local highlight = Instance.new("Highlight")
	highlight.FillColor = RollConfig.SilhouetteColor
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false

	local self = setmetatable({
		_onTake = onTake,
		_alive = true,
		_connections = {},
		_chest = nil,
		_pedestals = {},
		_seen = {},
		_equipped = nil,
		_display = {},
		_shown = nil,
		_highlight = highlight,
		_tickSound = nil,
		_revealLight = nil,
		_revealSparkles = nil,
		_lidAlpha = Instance.new("NumberValue"),
		_lidOpen = false,
		_spinning = false,
		_rollVersion = 0,
		_hoverStartedAt = nil,
	}, PickaxeRoulette)

	table.insert(
		self._connections,
		self._lidAlpha.Changed:Connect(function(alpha: number)
			self:_poseLid(alpha)
		end)
	)

	task.spawn(function()
		local model = waitForScene()
		if not self._alive or not model then
			return
		end
		self:_resolve(model)
		self:_buildPedestals(model)
		table.insert(
			self._connections,
			RunService.Heartbeat:Connect(function()
				self:_step()
			end)
		)
	end)
	return self
end

function PickaxeRoulette.Rolled(self: PickaxeRoulette, pickaxeId: any): ()
	local pickaxe = PickaxeCatalog.Get(pickaxeId)
	if pickaxe then
		task.spawn(self._play, self, pickaxe)
	end
end

function PickaxeRoulette.SetCollection(self: PickaxeRoulette, collection: any): ()
	if type(collection) ~= "table" or type(collection.Seen) ~= "table" then
		return
	end
	table.clear(self._seen)
	for _, id in collection.Seen do
		if PickaxeCatalog.Get(id) then
			self._seen[id] = true
		end
	end
	self._equipped = if PickaxeCatalog.Get(collection.Equipped) then collection.Equipped else nil
	self:_refreshPedestals()
end

function PickaxeRoulette.Destroy(self: PickaxeRoulette): ()
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self:_poseLid(0)
	self._lidAlpha:Destroy()
	self._highlight:Destroy()
	for _, model in self._display do
		model:Destroy()
	end
	table.clear(self._display)
	for _, pedestal in self._pedestals do
		pedestal.Model:Destroy()
		pedestal.Prompt:Destroy()
		if pedestal.Label then
			pedestal.Label:Destroy()
		end
	end
	table.clear(self._pedestals)
	if self._tickSound then
		self._tickSound:Destroy()
	end
end

function PickaxeRoulette._resolve(self: PickaxeRoulette, model: Model): ()
	local chestModel = tagged(model, SceneConfig.ChestTag)[1]
	local reveal = tagged(model, SceneConfig.RevealMarkerTag)[1]
	if not reveal or not reveal:IsA("BasePart") then
		warn(`[PickaxeRoulette] no {SceneConfig.RevealMarkerTag} marker in {model:GetFullName()}`)
		return
	end

	local lid = chestModel and chestModel:FindFirstChild(SceneConfig.LidName)
	local lidModel = if lid and lid:IsA("Model") and lid.PrimaryPart then lid else nil
	if not lidModel then
		warn(`[PickaxeRoulette] chest has no {SceneConfig.LidName} model with a PrimaryPart hinge`)
	end
	local openAngle = chestModel and chestModel:GetAttribute(SceneConfig.LidOpenAngleAttribute)

	self._chest = {
		Lid = lidModel,
		LidClosed = if lidModel then lidModel:GetPivot() else nil,
		LidOpenAngle = math.rad(if type(openAngle) == "number" then openAngle else 0),
		Reveal = reveal,
		Start = reveal.CFrame + RollConfig.RiseStartOffset,
		End = reveal.CFrame,
	}

	local tick = Instance.new("Sound")
	tick.SoundId = RollConfig.TickSound
	tick.Volume = RollConfig.TickVolume
	tick.RollOffMaxDistance = RollConfig.SoundRollOffDistance
	tick.Parent = reveal
	self._tickSound = tick
end

function PickaxeRoulette._buildPedestals(self: PickaxeRoulette, model: Model): ()
	local labelTemplate: Instance? = model
	for _, name in SceneConfig.ChanceTemplatePath do
		labelTemplate = labelTemplate and labelTemplate:FindFirstChild(name)
	end
	if not labelTemplate or not labelTemplate:IsA("BillboardGui") then
		warn(
			`[PickaxeRoulette] no BillboardGui at {table.concat(SceneConfig.ChanceTemplatePath, ".")}; pedestals show no chances`
		)
		labelTemplate = nil
	end

	for _, marker in tagged(model, SceneConfig.DisplayMarkerTag) do
		if not marker:IsA("BasePart") then
			continue
		end
		local pickaxe = PickaxeCatalog.GetByRarityName(marker:GetAttribute(SceneConfig.RarityAttribute))
		local display = pickaxe and cloneTemplate(pickaxe)
		if not pickaxe or not display then
			continue
		end
		local _, size = display:GetBoundingBox()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > RollConfig.PedestalMaxSize then
			display:ScaleTo(RollConfig.PedestalMaxSize / largest)
		end
		display:PivotTo(marker.CFrame)
		display.Parent = marker

		local rarityColor = RarityCatalog.GetColor(pickaxe.Tier)
		local silhouette = Instance.new("Highlight")
		silhouette.FillColor = RollConfig.SilhouetteColor
		silhouette.FillTransparency = 0
		silhouette.OutlineColor = rarityColor
		silhouette.OutlineTransparency = RollConfig.LockedOutlineTransparency
		silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
		silhouette.Adornee = display
		silhouette.Parent = display

		local label: BillboardGui? = nil
		if labelTemplate then
			local clone = (labelTemplate :: BillboardGui):Clone()
			clone.Adornee = marker
			clone.Enabled = true
			local chance = clone:FindFirstChild(SceneConfig.ChanceLabel, true)
			if chance and chance:IsA("TextLabel") then
				chance.Text = PickaxeCatalog.FormatChance(pickaxe)
			end
			local name = clone:FindFirstChild(SceneConfig.ChanceNameLabel, true)
			if name and name:IsA("TextLabel") then
				name.TextColor3 = rarityColor
			end
			clone.Parent = marker
			label = clone
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = RollConfig.TakePromptText
		prompt.ObjectText = pickaxe.Name
		prompt.HoldDuration = RollConfig.TakePromptHoldDuration
		prompt.MaxActivationDistance = RollConfig.TakePromptMaxDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = marker
		table.insert(
			self._connections,
			prompt.Triggered:Connect(function()
				self._onTake(pickaxe.Id)
			end)
		)

		table.insert(self._pedestals, {
			Pickaxe = pickaxe,
			Model = display,
			Anchor = marker.CFrame,
			Silhouette = silhouette,
			Label = label,
			Prompt = prompt,
		})
	end
	self:_refreshPedestals()
end

function PickaxeRoulette._refreshPedestals(self: PickaxeRoulette): ()
	for _, pedestal in self._pedestals do
		local pickaxe = pedestal.Pickaxe
		local unlocked = self._seen[pickaxe.Id] == true
		pedestal.Silhouette.Enabled = not unlocked
		pedestal.Prompt.Enabled = unlocked and self._equipped ~= pickaxe.Id
		local label = pedestal.Label
		local name = label and label:FindFirstChild(SceneConfig.ChanceNameLabel, true)
		if name and name:IsA("TextLabel") then
			name.Text = if unlocked then pickaxe.Name else RollConfig.LockedName
		end
	end
end

function PickaxeRoulette._step(self: PickaxeRoulette): ()
	local now = os.clock()
	local pedestalAngle = now * RollConfig.PedestalRpm / SECONDS_PER_MINUTE * FULL_TURN
	for _, pedestal in self._pedestals do
		pedestal.Model:PivotTo(pedestal.Anchor * CFrame.Angles(0, pedestalAngle, 0))
	end

	local hoverStartedAt = self._hoverStartedAt
	local shown = self._shown
	local chest = self._chest
	if hoverStartedAt and shown and chest then
		local angle = (now - hoverStartedAt) * RollConfig.RevealSpinRpm / SECONDS_PER_MINUTE * FULL_TURN
		shown:PivotTo(chest.End * CFrame.Angles(0, angle, 0))
	end
end

function PickaxeRoulette._poseLid(self: PickaxeRoulette, alpha: number): ()
	local chest = self._chest
	local lid = chest and chest.Lid
	if not chest or not lid or not chest.LidClosed or not lid.Parent then
		return
	end
	lid:PivotTo(chest.LidClosed * CFrame.Angles(chest.LidOpenAngle * alpha, 0, 0))
end

function PickaxeRoulette._setLidOpen(self: PickaxeRoulette, open: boolean): ()
	local chest = self._chest
	if self._lidOpen == open or not chest then
		return
	end
	self._lidOpen = open
	TweenService:Create(self._lidAlpha, if open then LID_OPEN_TWEEN else LID_CLOSE_TWEEN, {
		Value = if open then 1 else 0,
	}):Play()
	if open then
		playOnce(chest.Reveal, RollConfig.LidSound, RollConfig.LidVolume)
	end
end

function PickaxeRoulette._show(self: PickaxeRoulette, pickaxe: Pickaxe): Model?
	local model = self._display[pickaxe.Id]
	if not model then
		model = cloneTemplate(pickaxe)
		if not model then
			return nil
		end
		self._display[pickaxe.Id] = model
	end
	if self._shown and self._shown ~= model then
		self._shown.Parent = nil
	end
	self._shown = model
	model.Parent = Workspace
	self._highlight.Adornee = model
	self._highlight.Parent = model
	return model
end

function PickaxeRoulette._hide(self: PickaxeRoulette): ()
	self._hoverStartedAt = nil
	if self._shown then
		self._shown.Parent = nil
		self._shown = nil
	end
	self:_clearRevealEffects()
end

function PickaxeRoulette._clearRevealEffects(self: PickaxeRoulette): ()
	if self._revealLight then
		self._revealLight:Destroy()
		self._revealLight = nil
	end
	if self._revealSparkles then
		self._revealSparkles:Destroy()
		self._revealSparkles = nil
	end
end

local function nextDecoy(previous: Pickaxe?, rng: Random): Pickaxe
	local pool = PickaxeCatalog.All
	local pick = pool[rng:NextInteger(1, #pool)]
	if pick == previous then
		pick = pool[pick.Tier % #pool + 1]
	end
	return pick
end

function PickaxeRoulette._spin(self: PickaxeRoulette, chest: Chest, result: Pickaxe): boolean
	local rng = Random.new()
	local tilt = math.rad(RollConfig.SpinTiltDegrees)
	local cycle = RollConfig.HighlightCycle
	local ticks = RollConfig.SpinTicks
	local tickSound = self._tickSound
	local previous: Pickaxe? = nil

	self._highlight.Enabled = true
	local startedAt = os.clock()
	for index = 1, ticks do
		local dueAt = startedAt + RollTiming.GetTickTime(index)
		while os.clock() < dueAt do
			RunService.Heartbeat:Wait()
		end
		if not self._alive then
			return false
		end

		local pickaxe = if index == ticks then result else nextDecoy(previous, rng)
		previous = pickaxe
		local model = self:_show(pickaxe)
		local progress = index / ticks
		local side = if index % 2 == 0 then tilt else -tilt
		if model then
			model:PivotTo(chest.Start:Lerp(chest.End, progress) * CFrame.Angles(0, 0, side))
		end
		self._highlight.OutlineColor = cycle[(index - 1) % #cycle + 1]

		if tickSound then
			tickSound.PlaybackSpeed = RollConfig.TickPitchStart
				+ (RollConfig.TickPitchEnd - RollConfig.TickPitchStart) * progress
			tickSound:Play()
		end
	end

	local lastTilt = if ticks % 2 == 0 then tilt else -tilt
	local settleStart = os.clock()
	while self._alive do
		local alpha = math.min((os.clock() - settleStart) / RollConfig.SettleTime, 1)
		if self._shown then
			self._shown:PivotTo(chest.End * CFrame.Angles(0, 0, lastTilt * (1 - alpha)))
		end
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	return self._alive
end

function PickaxeRoulette._reveal(self: PickaxeRoulette, chest: Chest, pickaxe: Pickaxe): ()
	self._highlight.Enabled = false
	self._hoverStartedAt = os.clock()

	local rarity = RarityCatalog.Get(pickaxe.Tier)
	if not rarity then
		return
	end
	playOnce(chest.Reveal, rarity.Sound.Id, rarity.Sound.Volume, rarity.Sound.PlaybackSpeed)

	self:_clearRevealEffects()
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = RollConfig.RevealLightRange
	light.Brightness = RollConfig.RevealLightBrightness
	light.Parent = chest.Reveal
	self._revealLight = light

	if pickaxe.Tier >= RollConfig.RevealSparkleTier then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.Color
		sparkles.Parent = chest.Reveal
		self._revealSparkles = sparkles
	end
end

function PickaxeRoulette._play(self: PickaxeRoulette, pickaxe: Pickaxe): ()
	local waitedSince = os.clock()
	while self._alive and not self._chest and os.clock() - waitedSince < READY_WAIT_TIMEOUT do
		task.wait()
	end
	-- The server cooldown starts a network hop earlier, so a roll can land mid-settle: queue it.
	while self._alive and self._spinning do
		task.wait()
	end
	local chest = self._chest
	if not self._alive or not chest then
		return
	end

	self._rollVersion += 1
	local version = self._rollVersion
	self._spinning = true
	self:_hide()
	self:_setLidOpen(true)

	local finished = self:_spin(chest, pickaxe)
	if finished then
		task.wait(RollConfig.RevealDelay)
	end
	self._spinning = false
	if not finished or not self._alive then
		return
	end
	self:_reveal(chest, pickaxe)

	task.delay(RollConfig.RevealHoldTime, function()
		if not self._alive or self._rollVersion ~= version or self._spinning then
			return
		end
		self:_hide()
		self:_setLidOpen(false)
	end)
end

return PickaxeRoulette
