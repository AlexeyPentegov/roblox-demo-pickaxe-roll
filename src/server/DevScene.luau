--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PickaxeCatalog = require(ReplicatedStorage.Shared.PickaxeCatalog)
local RarityCatalog = require(ReplicatedStorage.Shared.RarityCatalog)
local SceneConfig = require(ReplicatedStorage.Shared.Config.SceneConfig)

local ORIGIN = CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0)

local CHEST_SIZE = Vector3.new(6, 3, 4)
local LID_THICKNESS = 0.8
local LID_OPEN_ANGLE = 105
local CHEST_COLOR = Color3.fromRGB(120, 78, 44)
local TRIM_COLOR = Color3.fromRGB(214, 170, 72)
local REVEAL_HEIGHT = 7.5

local PEDESTAL_SIZE = Vector3.new(2.6, 2.4, 2.6)
local PEDESTAL_COLOR = Color3.fromRGB(70, 74, 86)
local PEDESTAL_RADIUS = 11
local PEDESTAL_ARC_DEGREES = 125
local DISPLAY_LIFT = 2.8

local HANDLE_SIZE = Vector3.new(0.35, 4, 0.35)
local HANDLE_COLOR = Color3.fromRGB(92, 64, 40)
local HEAD_BASE_WIDTH = 2.4
local HEAD_WIDTH_PER_TIER = 0.25
local HEAD_THICKNESS = 0.7
local NEON_TIER = 5

local LABEL_SIZE = UDim2.fromScale(5, 1.6)
local LABEL_OFFSET = Vector3.new(0, 3.2, 0)
local LABEL_MAX_DISTANCE = 60

local DevScene = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Size = size
	newPart.Color = color
	newPart.Material = material or Enum.Material.SmoothPlastic
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	return newPart
end

local function marker(name: string, cframe: CFrame, tag: string): Part
	local newMarker = part(name, Vector3.one, Color3.new(1, 1, 1))
	newMarker.CFrame = cframe
	newMarker.Transparency = 1
	newMarker.CanCollide = false
	newMarker.CanTouch = false
	newMarker.CanQuery = false
	newMarker:AddTag(tag)
	return newMarker
end

local function ensureFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function buildPickaxe(pickaxe: PickaxeCatalog.Pickaxe): Model
	local model = Instance.new("Model")
	model.Name = pickaxe.ModelName

	local handle = part("Handle", HANDLE_SIZE, HANDLE_COLOR, Enum.Material.Wood)
	handle.CFrame = CFrame.new()
	handle.Parent = model

	local headWidth = HEAD_BASE_WIDTH + pickaxe.Tier * HEAD_WIDTH_PER_TIER
	local material = if pickaxe.Tier >= NEON_TIER then Enum.Material.Neon else Enum.Material.Metal
	local head = part(
		"Head",
		Vector3.new(headWidth, HEAD_THICKNESS, HEAD_THICKNESS),
		RarityCatalog.GetColor(pickaxe.Tier),
		material
	)
	head.CFrame = CFrame.new(0, (HANDLE_SIZE.Y - HEAD_THICKNESS) / 2, 0)
	head.Parent = model

	model.PrimaryPart = handle
	model.WorldPivot = model:GetBoundingBox()
	return model
end

local function ensurePickaxeModels(): ()
	local folder: Instance = ReplicatedStorage
	for _, name in SceneConfig.ModelsPath do
		folder = ensureFolder(folder, name)
	end
	for _, pickaxe in PickaxeCatalog.All do
		if not folder:FindFirstChild(pickaxe.ModelName) then
			buildPickaxe(pickaxe).Parent = folder
		end
	end
end

local function buildChest(scene: Model): ()
	local chest = Instance.new("Model")
	chest.Name = "PickaxeChest"
	chest:SetAttribute(SceneConfig.LidOpenAngleAttribute, LID_OPEN_ANGLE)
	chest:AddTag(SceneConfig.ChestTag)

	local base = part("Base", CHEST_SIZE, CHEST_COLOR, Enum.Material.WoodPlanks)
	base.CFrame = ORIGIN * CFrame.new(0, CHEST_SIZE.Y / 2, 0)
	base.Parent = chest

	local lid = Instance.new("Model")
	lid.Name = SceneConfig.LidName
	local hinge = part("Hinge", Vector3.new(CHEST_SIZE.X, 0.2, 0.2), TRIM_COLOR, Enum.Material.Metal)
	hinge.CFrame = ORIGIN * CFrame.new(0, CHEST_SIZE.Y, CHEST_SIZE.Z / 2)
	hinge.CanCollide = false
	hinge.Parent = lid
	local top =
		part("Top", Vector3.new(CHEST_SIZE.X, LID_THICKNESS, CHEST_SIZE.Z), CHEST_COLOR, Enum.Material.WoodPlanks)
	top.CFrame = ORIGIN * CFrame.new(0, CHEST_SIZE.Y + LID_THICKNESS / 2, 0)
	top.CanCollide = false
	top.Parent = lid
	lid.PrimaryPart = hinge
	lid.Parent = chest

	chest.Parent = scene

	marker(
		"PromptMarker",
		ORIGIN * CFrame.new(0, CHEST_SIZE.Y / 2, -CHEST_SIZE.Z / 2 - 0.5),
		SceneConfig.PromptMarkerTag
	).Parent =
		scene
	marker("RevealMarker", ORIGIN * CFrame.new(0, REVEAL_HEIGHT, 0), SceneConfig.RevealMarkerTag).Parent = scene
end

local function buildPedestals(scene: Model): ()
	local count = #PickaxeCatalog.All
	local step = if count > 1 then PEDESTAL_ARC_DEGREES / (count - 1) else 0
	for index, pickaxe in PickaxeCatalog.All do
		local angle = math.rad(-PEDESTAL_ARC_DEGREES / 2 + (index - 1) * step)
		local spot = ORIGIN * CFrame.new(math.sin(angle) * PEDESTAL_RADIUS, 0, math.cos(angle) * PEDESTAL_RADIUS)

		local pedestal = part(`Pedestal{index}`, PEDESTAL_SIZE, PEDESTAL_COLOR, Enum.Material.Slate)
		pedestal.CFrame = spot * CFrame.new(0, PEDESTAL_SIZE.Y / 2, 0)
		pedestal.Parent = scene

		local display = marker(
			`Display{index}`,
			spot * CFrame.new(0, PEDESTAL_SIZE.Y + DISPLAY_LIFT, 0),
			SceneConfig.DisplayMarkerTag
		)
		display:SetAttribute(SceneConfig.RarityAttribute, RarityCatalog.GetName(pickaxe.Tier))
		display.Parent = scene
	end
end

local function label(name: string, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = UDim2.fromScale(1, 0.5)
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	return text
end

local function buildChanceTemplate(scene: Model): ()
	local folder: Instance = scene
	local path = SceneConfig.ChanceTemplatePath
	for index = 1, #path - 1 do
		folder = ensureFolder(folder, path[index])
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = path[#path]
	billboard.Enabled = false
	billboard.Size = LABEL_SIZE
	billboard.StudsOffset = LABEL_OFFSET
	billboard.MaxDistance = LABEL_MAX_DISTANCE
	label(SceneConfig.ChanceNameLabel, UDim2.fromScale(0, 0)).Parent = billboard
	label(SceneConfig.ChanceLabel, UDim2.fromScale(0, 0.5)).Parent = billboard
	billboard.Parent = folder
end

function DevScene.Ensure(): ()
	ensurePickaxeModels()

	if #CollectionService:GetTagged(SceneConfig.SceneTag) > 0 then
		return
	end

	local scene = Instance.new("Model")
	scene.Name = "PickaxeRollScene"
	scene.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	scene:AddTag(SceneConfig.SceneTag)
	buildChest(scene)
	buildPedestals(scene)
	buildChanceTemplate(scene)
	scene.Parent = Workspace
end

return DevScene
