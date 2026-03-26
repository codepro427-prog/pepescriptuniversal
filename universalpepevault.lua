local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local originalGravity = workspace.Gravity

local settings = {
	speed = 70,
	jump = 120,
	flySpeed = 80,
	gravity = originalGravity,
}

local states = {
	speed = false,
	jump = false,
	fly = false,
	noclip = false,
	infJump = false,
	god = false,
	lowgrav = false,
	invisible = false,
	bighead = false,
	freeze = false,
}

local selectedTarget = nil
local currentCharacter = nil
local humanoid = nil
local humanoidRootPart = nil
local head = nil

local flyVelocity = nil
local flyGyro = nil
local flyControlVector = Vector3.zero

local movementKeys = {
	W = false,
	A = false,
	S = false,
	D = false,
	Space = false,
	Ctrl = false,
}

local collisionCache = {}
local transparencyCache = {}
local headSizeCache = nil

local characterConnections = {}
local runtimeConnections = {}

local theme = {
	background = Color3.fromRGB(13, 28, 14),
	panel = Color3.fromRGB(18, 42, 19),
	panelDark = Color3.fromRGB(14, 33, 15),
	panelSoft = Color3.fromRGB(23, 56, 25),
	header = Color3.fromRGB(28, 84, 34),
	headerDark = Color3.fromRGB(21, 61, 25),
	section = Color3.fromRGB(21, 51, 23),
	row = Color3.fromRGB(28, 62, 30),
	rowAlt = Color3.fromRGB(33, 74, 36),
	accent = Color3.fromRGB(100, 201, 93),
	accentSoft = Color3.fromRGB(79, 166, 73),
	on = Color3.fromRGB(68, 174, 78),
	off = Color3.fromRGB(105, 45, 45),
	text = Color3.fromRGB(231, 255, 231),
	textSoft = Color3.fromRGB(176, 220, 176),
	bar = Color3.fromRGB(40, 83, 43),
	barFill = Color3.fromRGB(117, 233, 107),
	close = Color3.fromRGB(147, 46, 46),
	closeHover = Color3.fromRGB(177, 62, 62),
	dropdown = Color3.fromRGB(24, 58, 26),
	dropdownItem = Color3.fromRGB(31, 70, 34),
	dropdownItemHover = Color3.fromRGB(52, 106, 56),
}

local function disconnectList(connectionList)
	for _, connection in ipairs(connectionList) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	table.clear(connectionList)
end

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function captureCharacterReferences()
	currentCharacter = getCharacter()
	humanoid = currentCharacter:WaitForChild("Humanoid")
	humanoidRootPart = currentCharacter:WaitForChild("HumanoidRootPart")
	head = currentCharacter:FindFirstChild("Head")

	collisionCache = {}
	transparencyCache = {}
	headSizeCache = nil

	for _, instance in ipairs(currentCharacter:GetDescendants()) do
		if instance:IsA("BasePart") then
			collisionCache[instance] = instance.CanCollide
			transparencyCache[instance] = instance.Transparency
		end
	end

	if head and head:IsA("BasePart") then
		headSizeCache = head.Size
	end
end

local function registerCharacterTracking()
	disconnectList(characterConnections)

	table.insert(characterConnections, currentCharacter.DescendantAdded:Connect(function(instance)
		if instance:IsA("BasePart") then
			if collisionCache[instance] == nil then
				collisionCache[instance] = instance.CanCollide
			end
			if transparencyCache[instance] == nil then
				transparencyCache[instance] = instance.Transparency
			end
		end

		if instance.Name == "Head" and instance:IsA("BasePart") then
			head = instance
			if not headSizeCache then
				headSizeCache = head.Size
			end
		end
	end))

	table.insert(characterConnections, currentCharacter.DescendantRemoving:Connect(function(instance)
		collisionCache[instance] = nil
		transparencyCache[instance] = nil
	end))
end

local function applyWalkSpeed()
	if not humanoid then
		return
	end

	if states.freeze then
		humanoid.WalkSpeed = 0
	elseif states.speed then
		humanoid.WalkSpeed = settings.speed
	else
		humanoid.WalkSpeed = 16
	end
end

local function applyJumpPower()
	if not humanoid then
		return
	end

	if states.jump then
		humanoid.JumpPower = settings.jump
	else
		humanoid.JumpPower = 50
	end
end

local function applyGodMode()
	if not humanoid then
		return
	end

	if states.god then
		humanoid.MaxHealth = math.huge
		humanoid.Health = humanoid.MaxHealth
	else
		if humanoid.MaxHealth == math.huge or humanoid.MaxHealth > 1000000 then
			humanoid.MaxHealth = 100
		end
		if humanoid.Health > humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function applyLowGravity()
	workspace.Gravity = states.lowgrav and 50 or settings.gravity
end

local function applyInvisibility()
	if not currentCharacter then
		return
	end

	for _, instance in ipairs(currentCharacter:GetDescendants()) do
		if instance:IsA("BasePart") then
			local originalTransparency = transparencyCache[instance]
			if originalTransparency == nil then
				originalTransparency = instance.Transparency
				transparencyCache[instance] = originalTransparency
			end

			if states.invisible then
				if instance ~= humanoidRootPart then
					instance.Transparency = 1
				end
			else
				instance.Transparency = originalTransparency
			end
		end
	end
end

local function applyBigHead()
	if not head or not head:IsA("BasePart") then
		return
	end

	if not headSizeCache then
		headSizeCache = head.Size
	end

	if states.bighead then
		head.Size = Vector3.new(5, 5, 5)
	else
		head.Size = headSizeCache
	end
end

local function applyFreeze()
	if not humanoid or not humanoidRootPart then
		return
	end

	if states.freeze then
		humanoidRootPart.Anchored = true
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		humanoidRootPart.Anchored = false
		if not states.fly then
			humanoid.AutoRotate = true
		end
	end

	applyWalkSpeed()
end

local function restoreCollisionState()
	if not currentCharacter then
		return
	end

	for _, instance in ipairs(currentCharacter:GetDescendants()) do
		if instance:IsA("BasePart") then
			local originalValue = collisionCache[instance]
			if originalValue == nil then
				originalValue = instance.CanCollide
				collisionCache[instance] = originalValue
			end
			instance.CanCollide = originalValue
		end
	end
end

local function applyStats()
	applyWalkSpeed()
	applyJumpPower()
end

local function stopFly(forceStateOff)
	if forceStateOff then
		states.fly = false
	end

	flyControlVector = Vector3.zero

	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end

	if flyGyro then
		flyGyro:Destroy()
		flyGyro = nil
	end

	if humanoid then
		humanoid.PlatformStand = false
		if not states.freeze then
			humanoid.AutoRotate = true
		end
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function startFly()
	if not humanoidRootPart or not humanoid then
		return
	end

	stopFly(false)

	humanoidRootPart.Anchored = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	flyVelocity = Instance.new("BodyVelocity")
	flyVelocity.Name = "PepeVaultFlyVelocity"
	flyVelocity.MaxForce = Vector3.new(100000000, 100000000, 100000000)
	flyVelocity.P = 100000
	flyVelocity.Velocity = Vector3.zero
	flyVelocity.Parent = humanoidRootPart

	flyGyro = Instance.new("BodyGyro")
	flyGyro.Name = "PepeVaultFlyGyro"
	flyGyro.MaxTorque = Vector3.new(100000000, 100000000, 100000000)
	flyGyro.P = 100000
	flyGyro.D = 1000
	flyGyro.CFrame = workspace.CurrentCamera.CFrame
	flyGyro.Parent = humanoidRootPart
end

local function applyFly()
	if states.fly then
		startFly()
	else
		stopFly(true)
	end
end

local function reapplyAllStates()
	applyStats()
	applyGodMode()
	applyLowGravity()
	applyInvisibility()
	applyBigHead()
	applyFreeze()

	if states.fly then
		startFly()
	else
		stopFly(false)
	end

	if not states.noclip then
		restoreCollisionState()
	end
end

captureCharacterReferences()
registerCharacterTracking()

player.CharacterAdded:Connect(function(newCharacter)
	currentCharacter = newCharacter
	captureCharacterReferences()
	registerCharacterTracking()

	task.wait(0.25)
	reapplyAllStates()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PepeVault"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(0, 376, 0, 540)
shadow.Position = UDim2.new(0.055, 10, 0.13, 10)
shadow.BackgroundColor3 = Color3.fromRGB(8, 16, 8)
shadow.BackgroundTransparency = 0.35
shadow.BorderSizePixel = 0
shadow.Parent = gui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 16)
shadowCorner.Parent = shadow

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 376, 0, 540)
main.Position = UDim2.new(0.055, 0, 0.13, 0)
main.BackgroundColor3 = theme.background
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundColor3 = theme.header
topBar.BorderSizePixel = 0
topBar.Parent = main

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 16)
topBarCorner.Parent = topBar

local topMask = Instance.new("Frame")
topMask.Size = UDim2.new(1, 0, 0, 20)
topMask.Position = UDim2.new(0, 0, 1, -20)
topMask.BackgroundColor3 = theme.header
topMask.BorderSizePixel = 0
topMask.Parent = topBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -110, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "PepeVault"
title.TextColor3 = theme.text
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -130, 0, 16)
subtitle.Position = UDim2.new(0, 16, 1, -18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "frog-grade local admin panel"
subtitle.TextColor3 = theme.textSoft
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = topBar

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -44, 0, 9)
closeButton.BackgroundColor3 = theme.close
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = theme.text
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.AutoButtonColor = false
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeButton

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 34, 0, 34)
minimizeButton.Position = UDim2.new(1, -84, 0, 9)
minimizeButton.BackgroundColor3 = theme.headerDark
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "-"
minimizeButton.TextColor3 = theme.text
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 20
minimizeButton.AutoButtonColor = false
minimizeButton.Parent = topBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 10)
minimizeCorner.Parent = minimizeButton

local contentHolder = Instance.new("Frame")
contentHolder.Name = "ContentHolder"
contentHolder.Size = UDim2.new(1, -16, 1, -66)
contentHolder.Position = UDim2.new(0, 8, 0, 58)
contentHolder.BackgroundTransparency = 1
contentHolder.Parent = main

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = theme.accent
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = contentHolder

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local dragData = {
	dragging = false,
	dragInput = nil,
	startPos = nil,
	startFramePos = nil,
}

local function tweenColor(object, color)
	TweenService:Create(object, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = color,
	}):Play()
end

topBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragData.dragging = true
		dragData.startPos = input.Position
		dragData.startFramePos = main.Position

		local connection
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragData.dragging = false
				if connection then
					connection:Disconnect()
				end
			end
		end)
	end
end)

topBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragData.dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragData.dragInput and dragData.dragging then
		local delta = input.Position - dragData.startPos
		main.Position = UDim2.new(
			dragData.startFramePos.X.Scale,
			dragData.startFramePos.X.Offset + delta.X,
			dragData.startFramePos.Y.Scale,
			dragData.startFramePos.Y.Offset + delta.Y
		)

		shadow.Position = UDim2.new(
			main.Position.X.Scale,
			main.Position.X.Offset + 10,
			main.Position.Y.Scale,
			main.Position.Y.Offset + 10
		)
	end
end)

local minimized = false
local expandedSize = main.Size
local expandedShadowSize = shadow.Size

minimizeButton.MouseEnter:Connect(function()
	tweenColor(minimizeButton, theme.rowAlt)
end)

minimizeButton.MouseLeave:Connect(function()
	tweenColor(minimizeButton, theme.headerDark)
end)

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		expandedSize = main.Size
		expandedShadowSize = shadow.Size

		TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 52),
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(shadow.Size.X.Scale, shadow.Size.X.Offset, 0, 52),
		}):Play()

		contentHolder.Visible = false
	else
		contentHolder.Visible = true

		TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = expandedSize,
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = expandedShadowSize,
		}):Play()
	end
end)

closeButton.MouseEnter:Connect(function()
	tweenColor(closeButton, theme.closeHover)
end)

closeButton.MouseLeave:Connect(function()
	tweenColor(closeButton, theme.close)
end)

closeButton.MouseButton1Click:Connect(function()
	stopFly(true)
	restoreCollisionState()
	workspace.Gravity = originalGravity
	gui:Destroy()
	disconnectList(characterConnections)
	disconnectList(runtimeConnections)
end)

local function createContainer(height)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -8, 0, height)
	container.BackgroundColor3 = theme.section
	container.BorderSizePixel = 0
	container.Parent = scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container

	return container
end

local function createCategoryHeader(text)
	local frame = createContainer(32)
	frame.BackgroundColor3 = theme.headerDark

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -18, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = theme.accent
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	return frame
end

local function createLabelValueRow(leftText, rightText)
	local frame = createContainer(34)
	frame.BackgroundColor3 = theme.panelDark

	local left = Instance.new("TextLabel")
	left.Size = UDim2.new(0.55, -12, 1, 0)
	left.Position = UDim2.new(0, 12, 0, 0)
	left.BackgroundTransparency = 1
	left.Text = leftText
	left.TextColor3 = theme.text
	left.Font = Enum.Font.Gotham
	left.TextSize = 13
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.Parent = frame

	local right = Instance.new("TextLabel")
	right.Size = UDim2.new(0.45, -12, 1, 0)
	right.Position = UDim2.new(0.55, 0, 0, 0)
	right.BackgroundTransparency = 1
	right.Text = rightText
	right.TextColor3 = theme.accent
	right.Font = Enum.Font.GothamBold
	right.TextSize = 13
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.Parent = frame

	return frame, left, right
end

local function createButton(text, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 38)
	button.BackgroundColor3 = theme.row
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = theme.text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Parent = scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	button.MouseEnter:Connect(function()
		tweenColor(button, theme.rowAlt)
	end)

	button.MouseLeave:Connect(function()
		tweenColor(button, theme.row)
	end)

	button.MouseButton1Click:Connect(function()
		callback()
	end)

	return button
end

local toggleRegistry = {}

local function createToggle(text, stateKey, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 42)
	button.BackgroundColor3 = theme.off
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -92, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = theme.text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = button

	local statePill = Instance.new("Frame")
	statePill.Size = UDim2.new(0, 72, 0, 28)
	statePill.Position = UDim2.new(1, -82, 0.5, -14)
	statePill.BackgroundColor3 = theme.panelDark
	statePill.BorderSizePixel = 0
	statePill.Parent = button

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 999)
	pillCorner.Parent = statePill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = UDim2.new(0, 2, 0.5, -12)
	knob.BackgroundColor3 = theme.text
	knob.BorderSizePixel = 0
	knob.Parent = statePill

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 999)
	knobCorner.Parent = knob

	local stateText = Instance.new("TextLabel")
	stateText.Size = UDim2.new(1, -30, 1, 0)
	stateText.Position = UDim2.new(0, 28, 0, 0)
	stateText.BackgroundTransparency = 1
	stateText.Text = "OFF"
	stateText.TextColor3 = theme.textSoft
	stateText.Font = Enum.Font.GothamBold
	stateText.TextSize = 11
	stateText.TextXAlignment = Enum.TextXAlignment.Center
	stateText.Parent = statePill

	local function refresh()
		local on = states[stateKey]

		TweenService:Create(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = on and theme.on or theme.off,
		}):Play()

		TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = on and UDim2.new(1, -26, 0.5, -12) or UDim2.new(0, 2, 0.5, -12),
		}):Play()

		stateText.Text = on and "ON" or "OFF"
		stateText.TextColor3 = on and theme.accent or theme.textSoft
	end

	button.MouseButton1Click:Connect(function()
		states[stateKey] = not states[stateKey]
		callback(states[stateKey])
		refresh()
	end)

	button.MouseEnter:Connect(function()
		if not states[stateKey] then
			tweenColor(button, Color3.fromRGB(118, 56, 56))
		else
			tweenColor(button, Color3.fromRGB(79, 194, 89))
		end
	end)

	button.MouseLeave:Connect(function()
		refresh()
	end)

	refresh()
	toggleRegistry[stateKey] = refresh

	return button
end

local function createSlider(text, minValue, maxValue, settingKey, callback)
	local frame = createContainer(70)
	frame.BackgroundColor3 = theme.row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, 22)
	label.Position = UDim2.new(0, 12, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = text .. " (" .. tostring(settings[settingKey]) .. ")"
	label.TextColor3 = theme.text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -24, 0, 14)
	bar.Position = UDim2.new(0, 12, 0, 40)
	bar.BackgroundColor3 = theme.bar
	bar.BorderSizePixel = 0
	bar.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 999)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((settings[settingKey] - minValue) / (maxValue - minValue), 0, 1, 0)
	fill.BackgroundColor3 = theme.barFill
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 999)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 20)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0)
	knob.BackgroundColor3 = theme.text
	knob.BorderSizePixel = 0
	knob.Parent = bar

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 999)
	knobCorner.Parent = knob

	local dragging = false

	local function setSliderFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)

		local value = math.floor(minValue + ((maxValue - minValue) * alpha) + 0.5)
		settings[settingKey] = value
		label.Text = text .. " (" .. tostring(value) .. ")"
		callback(value)
	end

	local function refresh()
		local alpha = (settings[settingKey] - minValue) / (maxValue - minValue)
		alpha = math.clamp(alpha, 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		label.Text = text .. " (" .. tostring(settings[settingKey]) .. ")"
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local alpha = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
			setSliderFromAlpha(alpha)
		end
	end)

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local alpha = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
			setSliderFromAlpha(alpha)
			dragging = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local alpha = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
			setSliderFromAlpha(alpha)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	refresh()
	return frame
end

local dropdownRegistry = {}

local function createPlayerDropdown(titleText, onSelected)
	local holder = createContainer(54)
	holder.BackgroundColor3 = theme.dropdown

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -24, 0, 18)
	titleLabel.Position = UDim2.new(0, 12, 0, 7)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = theme.text
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = holder

	local selectedLabel = Instance.new("TextButton")
	selectedLabel.Size = UDim2.new(1, -24, 0, 22)
	selectedLabel.Position = UDim2.new(0, 12, 0, 27)
	selectedLabel.BackgroundColor3 = theme.panelDark
	selectedLabel.BorderSizePixel = 0
	selectedLabel.AutoButtonColor = false
	selectedLabel.Text = "Selected: none"
	selectedLabel.TextColor3 = theme.accent
	selectedLabel.Font = Enum.Font.Gotham
	selectedLabel.TextSize = 12
	selectedLabel.Parent = holder

	local selectedCorner = Instance.new("UICorner")
	selectedCorner.CornerRadius = UDim.new(0, 10)
	selectedCorner.Parent = selectedLabel

	local listFrame = Instance.new("Frame")
	listFrame.Visible = false
	listFrame.Size = UDim2.new(1, -8, 0, 136)
	listFrame.BackgroundColor3 = theme.panel
	listFrame.BorderSizePixel = 0
	listFrame.Parent = scroll

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 12)
	listCorner.Parent = listFrame

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(1, -12, 1, -12)
	listScroll.Position = UDim2.new(0, 6, 0, 6)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 5
	listScroll.ScrollBarImageColor3 = theme.accent
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.Parent = listFrame

	local listLayoutInner = Instance.new("UIListLayout")
	listLayoutInner.Padding = UDim.new(0, 6)
	listLayoutInner.Parent = listScroll

	local dropdownOpen = false
	local optionButtons = {}

	local function clearOptions()
		for _, button in ipairs(optionButtons) do
			button:Destroy()
		end
		table.clear(optionButtons)
	end

	local function setSelected(targetPlayer)
		selectedTarget = targetPlayer
		selectedLabel.Text = "Selected: " .. (targetPlayer and targetPlayer.Name or "none")
		onSelected(targetPlayer)
	end

	local function refreshPlayers()
		clearOptions()

		local allPlayers = Players:GetPlayers()
		table.sort(allPlayers, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)

		for _, targetPlayer in ipairs(allPlayers) do
			if targetPlayer ~= player then
				local button = Instance.new("TextButton")
				button.Size = UDim2.new(1, 0, 0, 28)
				button.BackgroundColor3 = theme.dropdownItem
				button.BorderSizePixel = 0
				button.AutoButtonColor = false
				button.Text = targetPlayer.Name
				button.TextColor3 = theme.text
				button.Font = Enum.Font.Gotham
				button.TextSize = 12
				button.Parent = listScroll

				local buttonCorner = Instance.new("UICorner")
				buttonCorner.CornerRadius = UDim.new(0, 9)
				buttonCorner.Parent = button

				button.MouseEnter:Connect(function()
					tweenColor(button, theme.dropdownItemHover)
				end)

				button.MouseLeave:Connect(function()
					tweenColor(button, theme.dropdownItem)
				end)

				button.MouseButton1Click:Connect(function()
					setSelected(targetPlayer)
					dropdownOpen = false
					listFrame.Visible = false
				end)

				table.insert(optionButtons, button)
			end
		end

		if selectedTarget and not table.find(Players:GetPlayers(), selectedTarget) then
			setSelected(nil)
		end
	end

	selectedLabel.MouseEnter:Connect(function()
		tweenColor(selectedLabel, theme.rowAlt)
	end)

	selectedLabel.MouseLeave:Connect(function()
		tweenColor(selectedLabel, theme.panelDark)
	end)

	selectedLabel.MouseButton1Click:Connect(function()
		dropdownOpen = not dropdownOpen
		listFrame.Visible = dropdownOpen
		if dropdownOpen then
			refreshPlayers()
		end
	end)

	refreshPlayers()

	dropdownRegistry.refresh = refreshPlayers
	dropdownRegistry.setSelected = setSelected
	dropdownRegistry.getLabel = function()
		return selectedLabel
	end

	return holder, listFrame
end

createCategoryHeader("Movement")
createSlider("WalkSpeed", 16, 150, "speed", function()
	applyWalkSpeed()
end)
createSlider("JumpPower", 50, 200, "jump", function()
	applyJumpPower()
end)
createToggle("WalkSpeed Toggle", "speed", function()
	applyWalkSpeed()
end)
createToggle("JumpPower Toggle", "jump", function()
	applyJumpPower()
end)

createCategoryHeader("Fly")
createSlider("Fly Speed", 20, 150, "flySpeed", function()
end)
createToggle("Fly Toggle", "fly", function()
	applyFly()
end)

createCategoryHeader("Physics")
createToggle("Noclip", "noclip", function(on)
	if not on then
		restoreCollisionState()
	end
end)
createToggle("Infinite Jump", "infJump", function()
end)
createToggle("Low Gravity", "lowgrav", function()
	applyLowGravity()
end)
createToggle("Freeze", "freeze", function()
	applyFreeze()
end)

createCategoryHeader("Teleport")
createPlayerDropdown("Target Player", function(targetPlayer)
	selectedTarget = targetPlayer
end)

local _, _, selectedTargetValue = createLabelValueRow("Current Target", "none")

local function refreshTargetDisplay()
	selectedTargetValue.Text = selectedTarget and selectedTarget.Name or "none"
	if dropdownRegistry.getLabel then
		dropdownRegistry.getLabel().Text = "Selected: " .. (selectedTarget and selectedTarget.Name or "none")
	end
end

createButton("Teleport To Selected Player", function()
	if not selectedTarget then
		return
	end

	local targetCharacter = selectedTarget.Character
	local targetHRP = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if targetHRP and humanoidRootPart then
		humanoidRootPart.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
	end
end)

createButton("Teleport Forward", function()
	if humanoidRootPart then
		humanoidRootPart.CFrame = humanoidRootPart.CFrame + workspace.CurrentCamera.CFrame.LookVector * 10
	end
end)

createButton("Teleport To Spawn", function()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation and humanoidRootPart then
		humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 4, 0)
	end
end)

createCategoryHeader("Player")
createToggle("God Mode", "god", function()
	applyGodMode()
end)
createToggle("Invisible", "invisible", function()
	applyInvisibility()
end)
createToggle("Big Head", "bighead", function()
	applyBigHead()
end)

createButton("Heal", function()
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end)

createButton("Sit", function()
	if humanoid then
		humanoid.Sit = true
	end
end)

createButton("Reset Character", function()
	if humanoid then
		humanoid.Health = 0
	end
end)

createCategoryHeader("Troll")
createButton("Spin", function()
	if humanoidRootPart then
		humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(360), 0)
	end
end)

createButton("Hop Burst", function()
	if humanoidRootPart then
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
	end
end)

createButton("Frog Leap", function()
	if humanoidRootPart then
		local look = workspace.CurrentCamera.CFrame.LookVector
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(look.X * 60, 75, look.Z * 60)
	end
end)

table.insert(runtimeConnections, Players.PlayerAdded:Connect(function()
	if dropdownRegistry.refresh then
		dropdownRegistry.refresh()
	end
end))

table.insert(runtimeConnections, Players.PlayerRemoving:Connect(function(leavingPlayer)
	if selectedTarget == leavingPlayer then
		selectedTarget = nil
		refreshTargetDisplay()
	end

	if dropdownRegistry.refresh then
		dropdownRegistry.refresh()
	end
end))

table.insert(runtimeConnections, RunService.Stepped:Connect(function()
	if states.noclip and currentCharacter then
		for _, instance in ipairs(currentCharacter:GetDescendants()) do
			if instance:IsA("BasePart") then
				if collisionCache[instance] == nil then
					collisionCache[instance] = instance.CanCollide
				end
				instance.CanCollide = false
			end
		end
	end
end))

table.insert(runtimeConnections, UserInputService.JumpRequest:Connect(function()
	if states.infJump and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

table.insert(runtimeConnections, UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.W then
		movementKeys.W = true
	elseif input.KeyCode == Enum.KeyCode.A then
		movementKeys.A = true
	elseif input.KeyCode == Enum.KeyCode.S then
		movementKeys.S = true
	elseif input.KeyCode == Enum.KeyCode.D then
		movementKeys.D = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		movementKeys.Space = true
	elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		movementKeys.Ctrl = true
	end
end))

table.insert(runtimeConnections, UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		movementKeys.W = false
	elseif input.KeyCode == Enum.KeyCode.A then
		movementKeys.A = false
	elseif input.KeyCode == Enum.KeyCode.S then
		movementKeys.S = false
	elseif input.KeyCode == Enum.KeyCode.D then
		movementKeys.D = false
	elseif input.KeyCode == Enum.KeyCode.Space then
		movementKeys.Space = false
	elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		movementKeys.Ctrl = false
	end
end))

table.insert(runtimeConnections, RunService.RenderStepped:Connect(function()
	refreshTargetDisplay()

	if states.fly and flyVelocity and flyGyro and humanoidRootPart and humanoid then
		local camera = workspace.CurrentCamera
		local cameraLook = camera.CFrame.LookVector
		local cameraRight = camera.CFrame.RightVector

		local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
		local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)

		if flatLook.Magnitude <= 0 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end

		if flatRight.Magnitude <= 0 then
			flatRight = Vector3.new(1, 0, 0)
		else
			flatRight = flatRight.Unit
		end

		local moveVector = Vector3.zero

		if movementKeys.W then
			moveVector += flatLook
		end
		if movementKeys.S then
			moveVector -= flatLook
		end
		if movementKeys.A then
			moveVector -= flatRight
		end
		if movementKeys.D then
			moveVector += flatRight
		end
		if movementKeys.Space then
			moveVector += Vector3.new(0, 1, 0)
		end
		if movementKeys.Ctrl then
			moveVector -= Vector3.new(0, 1, 0)
		end

		if moveVector.Magnitude > 0 then
			flyControlVector = moveVector.Unit * settings.flySpeed
		else
			flyControlVector = Vector3.zero
		end

		if states.freeze then
			flyVelocity.Velocity = Vector3.zero
		else
			flyVelocity.Velocity = flyControlVector
		end

		flyGyro.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + camera.CFrame.LookVector)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
end))

reapplyAllStates()
refreshTargetDisplay()

if toggleRegistry.speed then
	toggleRegistry.speed()
end
if toggleRegistry.jump then
	toggleRegistry.jump()
end
if toggleRegistry.fly then
	toggleRegistry.fly()
end
if toggleRegistry.noclip then
	toggleRegistry.noclip()
end
if toggleRegistry.infJump then
	toggleRegistry.infJump()
end
if toggleRegistry.god then
	toggleRegistry.god()
end
if toggleRegistry.lowgrav then
	toggleRegistry.lowgrav()
end
if toggleRegistry.invisible then
	toggleRegistry.invisible()
end
if toggleRegistry.bighead then
	toggleRegistry.bighead()
end
if toggleRegistry.freeze then
	toggleRegistry.freeze()
end
if toggleRegistry.bighead then
toggleRegistry.bighead()
end
if toggleRegistry.freeze then
toggleRegistry.freeze()
end
