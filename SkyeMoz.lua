-- Infinite Terrain Generator v3 ðŸ”¥ (with Flat World perks)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
repeat task.wait() until player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")

-- CONFIG
local BLOCK_SIZE = Vector3.new(4,4,4)
local FREQUENCY_SCALE = 120
local AMPLITUDE = 8
local BASE_HEIGHT = 6
local generating = false
local placedBlocks = {}
local generatedPositions = {}
local SEED = math.random()

-- TEXTURES
local TEXTURE_TOP_STONE = "rbxassetid://135181604249180"
local TEXTURE_SIDES_STONE = "rbxassetid://135181604249180"
local TEXTURE_BOTTOM_STONE = "rbxassetid://135181604249180"

local TEXTURE_TOP_GRASS = "rbxassetid://9267183930"
local TEXTURE_SIDES_GRASS = "rbxassetid://9267155972"
local TEXTURE_BOTTOM_GRASS = "rbxassetid://7901287342"

local TEXTURE_DEEPSLATE = "rbxassetid://6928057336"
local TEXTURE_BEDROCK = "rbxassetid://12252439624"
local TEXTURE_COAL = "rbxassetid://6916051034"
local TEXTURE_COPPER = "rbxassetid://6915769492"

-- SOUNDS
local placeSounds = {
    "rbxassetid://6496157434",
    "rbxassetid://139955989389582",
    "rbxassetid://127813310184586"
}
local lastSoundTime = 0
local function playPlaceSound(rate)
    local now = tick()
    local interval = math.clamp(0.12 / math.max(rate, 1), 0.01, 0.12)
    if now - lastSoundTime >= interval then
        lastSoundTime = now
        local s = Instance.new("Sound")
        s.SoundId = placeSounds[math.random(#placeSounds)]
        s.Volume = 1
        s.Parent = workspace
        s:Play()
        s.Ended:Once(function() s:Destroy() end)
    end
end

-- HELPERS
local function addTextures(part, top, sides, bottom)
	local faces = {Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}
	for _, face in ipairs(faces) do
		local tex = Instance.new("Texture")
		tex.Texture = sides
		tex.Face = face
		tex.StudsPerTileU = 4
		tex.StudsPerTileV = 4
		tex.Parent = part
	end
	local topTex = Instance.new("Texture")
	topTex.Texture = top
	topTex.Face = Enum.NormalId.Top
	topTex.StudsPerTileU = 4
	topTex.StudsPerTileV = 4
	topTex.Parent = part

	local bottomTex = Instance.new("Texture")
	bottomTex.Texture = bottom
	bottomTex.Face = Enum.NormalId.Bottom
	bottomTex.StudsPerTileU = 4
	bottomTex.StudsPerTileV = 4
	bottomTex.Parent = part
end

local function snapToGrid(pos)
	local function s(v) return math.floor(v / BLOCK_SIZE.X + 0.5) * BLOCK_SIZE.X end
	return Vector3.new(s(pos.X), s(pos.Y), s(pos.Z))
end

local function posKey(pos)
	return string.format("%d_%d", math.floor(pos.X), math.floor(pos.Z))
end

local function clearBlocks()
	for _, block in ipairs(placedBlocks) do
		if block and block.Parent then block:Destroy() end
	end
	placedBlocks = {}
	generatedPositions = {}
end

-- ORE GENERATION
local function oreCheck(y, layerType)
	if layerType == "stone" then
		if y <= 40 and math.random() < 0.02 then return TEXTURE_COAL end
		if math.random() < 0.015 then return TEXTURE_COPPER end
	end
	return nil
end

-- SINGLE BLOCK GENERATION
local function generateBlock(pos, dirtDepth, stoneDepth, deepslateDepth, blocksPerBatch)
	local key = posKey(pos)
	if generatedPositions[key] then return end
	generatedPositions[key] = true

	local topHeight = BASE_HEIGHT + math.noise(pos.X/FREQUENCY_SCALE, SEED, pos.Z/FREQUENCY_SCALE)*AMPLITUDE
	local topBlock = math.max(1, math.floor(topHeight))
	local totalHeight = topBlock + dirtDepth + stoneDepth + deepslateDepth + 1

	for y = totalHeight, 1, -1 do
		local part = Instance.new("Part")
		part.Size = BLOCK_SIZE
		part.Anchored = true
		part.CanCollide = true
		part.CFrame = CFrame.new(pos.X + BLOCK_SIZE.X/2, (y-1)*BLOCK_SIZE.Y + BLOCK_SIZE.Y/2, pos.Z + BLOCK_SIZE.Z/2)
		part.Parent = workspace
		part.Name = "Block"
		table.insert(placedBlocks, part)

		if y == 1 then
			addTextures(part, TEXTURE_BEDROCK, TEXTURE_BEDROCK, TEXTURE_BEDROCK)
		elseif y <= deepslateDepth + 1 then
			addTextures(part, TEXTURE_DEEPSLATE, TEXTURE_DEEPSLATE, TEXTURE_DEEPSLATE)
		elseif y <= stoneDepth + deepslateDepth + 1 then
			local ore = oreCheck(y, "stone")
			if ore then
				addTextures(part, ore, ore, ore)
			else
				addTextures(part, TEXTURE_TOP_STONE, TEXTURE_SIDES_STONE, TEXTURE_BOTTOM_STONE)
			end
		elseif y <= dirtDepth + stoneDepth + deepslateDepth + 1 then
			addTextures(part, TEXTURE_TOP_GRASS, TEXTURE_SIDES_GRASS, TEXTURE_BOTTOM_GRASS)
		else
			addTextures(part, TEXTURE_TOP_GRASS, TEXTURE_SIDES_GRASS, TEXTURE_BOTTOM_GRASS)
		end
	end

	playPlaceSound(blocksPerBatch)
end

-- GHOST BLOCK
local ghostBlock = Instance.new("Part")
ghostBlock.Size = BLOCK_SIZE
ghostBlock.Anchored = true
ghostBlock.CanCollide = false
ghostBlock.Transparency = 1
ghostBlock.BrickColor = BrickColor.new("Bright orange")
ghostBlock.Material = Enum.Material.Neon
ghostBlock.Parent = workspace

-- TELEPORT PLAYER ABOVE START
local function teleportAboveStart()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local root = player.Character.HumanoidRootPart
		root.CFrame = CFrame.new(root.Position.X, BASE_HEIGHT + 50, root.Position.Z)
	end
end

-- INFINITE GENERATION LOOP
local function infiniteGenerate(dirtDepth, stoneDepth, deepslateDepth, blocksPerBatch, secondsPerBatch, radius)
	teleportAboveStart()
	ghostBlock.Transparency = 0.5
	while generating do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPos = snapToGrid(player.Character.HumanoidRootPart.Position)
			local positions = {}

			for x = -radius, radius do
				for z = -radius, radius do
					table.insert(positions, Vector3.new(playerPos.X + x*BLOCK_SIZE.X, 0, playerPos.Z + z*BLOCK_SIZE.Z))
				end
			end

			local index = 1
			while index <= #positions and generating do
				local batchCount = 0
				while batchCount < blocksPerBatch and index <= #positions and generating do
					local pos = positions[index]
					ghostBlock.CFrame = CFrame.new(pos.X + BLOCK_SIZE.X/2, BASE_HEIGHT + 1, pos.Z + BLOCK_SIZE.Z/2)
					generateBlock(pos, dirtDepth, stoneDepth, deepslateDepth, blocksPerBatch)
					index += 1
					batchCount += 1
				end
				task.wait(secondsPerBatch)
			end
		end
		task.wait(0.05)
	end
	ghostBlock.Transparency = 1
end

-- GUI (merged particle + buttons like Flat World GUI)
local function createGUI()
	if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("TerrainGenGUI") then
		player.PlayerGui.TerrainGenGUI:Destroy()
		task.wait(0.05)
	end

	local screenGui = Instance.new("ScreenGui", player.PlayerGui)
	screenGui.Name = "TerrainGenGUI"

	local frame = Instance.new("Frame", screenGui)
	frame.Size = UDim2.new(0,300,0,360)
	frame.Position = UDim2.new(0.5,-150,0.4,-180)
	frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
	frame.Active = true
	frame.Draggable = true
	local uic = Instance.new("UICorner", frame)
	uic.CornerRadius = UDim.new(0,12)

	-- PARTICLES
	local particleFrame = Instance.new("Frame", frame)
	particleFrame.Size = UDim2.new(1,0,1,0)
	particleFrame.BackgroundTransparency = 1
	particleFrame.ZIndex = 0
	for i = 1,30 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0,3,0,3)
		dot.Position = UDim2.new(math.random(),0,math.random(),0)
		dot.BackgroundColor3 = Color3.fromRGB(200,200,200)
		dot.BackgroundTransparency = 0.7
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5,0.5)
		dot.Parent = particleFrame
		spawn(function()
			while dot.Parent do
				local x = math.random()
				local y = math.random()
				dot:TweenPosition(UDim2.new(x,0,y,0), "InOut", "Sine", math.random(6,12), true)
				task.wait(math.random(2,4))
			end
		end)
	end

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1,0,0,30)
	title.Position = UDim2.new(0,0,0,0)
	title.BackgroundTransparency = 1
	title.Text = "Infinite Terrain Generator"
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.TextColor3 = Color3.fromRGB(255,255,255)

	-- INPUT BOXES
	local function makeBox(y, placeholder)
		local box = Instance.new("TextBox", frame)
		box.Size = UDim2.new(0,120,0,25)
		box.Position = UDim2.new(0,20,0,y)
		box.PlaceholderText = placeholder
		box.Text = ""
		box.TextScaled = true
		box.BackgroundColor3 = Color3.fromRGB(50,50,50)
		box.TextColor3 = Color3.fromRGB(255,255,255)
		box.Font = Enum.Font.SourceSansBold
		local c = Instance.new("UICorner", box)
		c.CornerRadius = UDim.new(0,6)
		return box
	end

	local dirtBox = makeBox(40,"Dirt Depth")
	local stoneBox = makeBox(80,"Stone Depth")
	local deepslateBox = makeBox(120,"Deepslate Depth")
	local batchBox = makeBox(160,"Blocks per Batch")
	local secondsBox = makeBox(200,"Seconds per Batch")
	local seedBox = makeBox(240,"Seed Number")

	-- BUTTONS
	local function makeButton(y,text,color)
		local btn = Instance.new("TextButton", frame)
		btn.Size = UDim2.new(0,120,0,30)
		btn.Position = UDim2.new(0,20,0,y)
		btn.Text = text
		btn.BackgroundColor3 = color
		btn.TextScaled = true
		btn.Font = Enum.Font.SourceSansBold
		local c = Instance.new("UICorner", btn)
		c.CornerRadius = UDim.new(0,8)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = color:lerp(Color3.fromRGB(255,255,255),0.2) end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = color end)
		return btn
	end

	local generateButton = makeButton(280,"Generate",Color3.fromRGB(0,200,0))
	local clearButton = makeButton(320,"Clear",Color3.fromRGB(200,0,0))

	generateButton.MouseButton1Click:Connect(function()
		local dirt = tonumber(dirtBox.Text) or 3
		local stone = tonumber(stoneBox.Text) or 2
		local deepslate = tonumber(deepslateBox.Text) or 2
		local batch = tonumber(batchBox.Text) or 5
		local seconds = tonumber(secondsBox.Text) or 0.05
		local radius = 15
		local seedInput = tonumber(seedBox.Text)
		if seedInput then SEED = seedInput else SEED = math.random() end

		generating = not generating
		if generating then
			generateButton.BackgroundColor3 = Color3.fromRGB(255,255,0)
			generateButton.Text = "Stop"
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				spawn(function()
					infiniteGenerate(dirt, stone, deepslate, batch, seconds, radius)
				end)
			end
		else
			generateButton.BackgroundColor3 = Color3.fromRGB(0,200,0)
			generateButton.Text = "Generate"
		end
	end)

	clearButton.MouseButton1Click:Connect(function()
		generating = false
		clearBlocks()
		ghostBlock.Transparency = 1
		generateButton.BackgroundColor3 = Color3.fromRGB(0,200,0)
		generateButton.Text = "Generate"
	end)
end

createGUI()
