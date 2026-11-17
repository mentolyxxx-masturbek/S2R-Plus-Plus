local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

for _, guiName in ipairs({ "RStudio2RGE", "S2R_Remake", "S2R++", "S2R_SafeModeBlocker" }) do
	local existing = PlayerGui:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end
end

local Assets = {
	inter = "rbxassetid://12187365364",
	toggleBackground = "rbxassetid://18772190202",
	toggleHead = "rbxassetid://18772309008",
	globe = "rbxassetid://108952102602834",
	resize = "rbxassetid://112118428328655",
	arrow = "rbxassetid://10709791437",
	userInfoBlurred = "rbxassetid://18824089198",
	transferTab = "rbxassetid://112728855826191",
	helpTab = "rbxassetid://10734950309",
}

local hotkeyBind = {
	modifiers = { Enum.KeyCode.LeftAlt },
	key = Enum.KeyCode.Equals,
}
local awaitingBind = false
local destroyed = false
local expanded = false
local hotkeyConnection
local inputChangedConnection
local inputEndedConnection
local cameraConnection
local expandConnection
local consoleWatchdogConnection
local leaveExpanded

local bindModifierNames = {
	[Enum.KeyCode.LeftAlt] = "LeftAlt",
	[Enum.KeyCode.RightAlt] = "RightAlt",
	[Enum.KeyCode.LeftControl] = "LeftCtrl",
	[Enum.KeyCode.RightControl] = "RightCtrl",
	[Enum.KeyCode.LeftShift] = "LeftShift",
	[Enum.KeyCode.RightShift] = "RightShift",
}

local bindKeyNames = {
	[Enum.KeyCode.Equals] = "=",
	[Enum.KeyCode.Minus] = "-",
	[Enum.KeyCode.KeypadEquals] = "Num =",
	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Backspace] = "Backspace",
	[Enum.KeyCode.Tab] = "Tab",
	[Enum.KeyCode.Escape] = "Esc",
}

local function isBindModifier(keyCode)
	return bindModifierNames[keyCode] ~= nil
end

local function bindKeyName(keyCode)
	return bindKeyNames[keyCode] or keyCode.Name
end

local function formatBind()
	local parts = {}
	for _, modifier in ipairs(hotkeyBind.modifiers) do
		table.insert(parts, bindModifierNames[modifier] or modifier.Name)
	end
	table.insert(parts, bindKeyName(hotkeyBind.key))
	return table.concat(parts, " + ")
end

local Colors = {
	window = Color3.fromRGB(15, 15, 15),
	card = Color3.fromRGB(255, 255, 255),
	input = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(175, 175, 175),
	danger = Color3.fromRGB(250, 93, 86),
	warning = Color3.fromRGB(252, 190, 57),
	success = Color3.fromRGB(119, 174, 94),
	primaryText = Color3.fromRGB(15, 15, 15),
	editor = Color3.fromRGB(8, 8, 8),
}

local DEFAULT_SIZE = Vector2.new(868, 650)
local MIN_SIZE = Vector2.new(700, 500)
local SIDEBAR_DEFAULT = 0.325
local SIDEBAR_MIN = 0.24
local SIDEBAR_MAX = 0.46
local MIN_CONTENT_WIDTH = 470

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties or {}) do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function addCorner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function addStroke(parent, transparency, thickness)
	return make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = transparency,
		Thickness = thickness or 1,
	}, parent)
end

local function addPadding(parent, left, right, top, bottom)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
	}, parent)
end

local function addList(parent, padding, direction)
	return make("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

local function interFont(weight)
	return Font.new(Assets.inter, weight or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end

local function newLabel(parent, text, textSize, transparency, weight)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text or "",
		TextColor3 = Colors.text,
		TextSize = textSize or 13,
		TextTransparency = transparency or 0,
		FontFace = interFont(weight),
		RichText = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function tween(instance, duration, properties, style)
	local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	return TweenService:Create(instance, info, properties)
end

local function autoOrder(instance)
	local parent = instance.Parent
	if not parent then
		return
	end
	local highest = -1
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") and child ~= instance and child.LayoutOrder > highest then
			highest = child.LayoutOrder
		end
	end
	instance.LayoutOrder = highest + 1
end

local function viewportSize()
	return Camera and Camera.ViewportSize or Vector2.new(1280, 720)
end

local function maxWindowSize()
	local viewport = viewportSize()
	return Vector2.new(
		math.max(MIN_SIZE.X, viewport.X - 24),
		math.max(MIN_SIZE.Y, viewport.Y - 24)
	)
end

local function isGuiChainVisible(instance)
	local node = instance
	while node and node ~= PlayerGui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return true
end

local function isTextBoxFocused(box)
	local ok, focused = pcall(function()
		return box:IsFocused()
	end)
	return ok and focused == true
end

local function getExecutorFunction(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and type(value) == "function" then
		return value
	end
	local okGenv, genv = pcall(function()
		return getgenv()
	end)
	if okGenv and type(genv) == "table" and type(genv[name]) == "function" then
		return genv[name]
	end
	local okEnv, env = pcall(getfenv, 0)
	if okEnv and type(env) == "table" and type(env[name]) == "function" then
		return env[name]
	end
	return nil
end

local function instancePath(instance)
	local ok, path = pcall(function()
		return instance:GetFullName()
	end)
	if ok and type(path) == "string" then
		return path
	end
	return instance.Name or "?"
end

local function getRgeCommandLine()
	local interface = PlayerGui:FindFirstChild("RGEInterface", true)
	if not interface then
		return nil
	end

	local focused = UserInputService:GetFocusedTextBox()
	if focused and focused:IsA("TextBox") and focused:IsDescendantOf(interface) then
		local focusedName = string.lower(focused.Name)
		local focusedParent = focused.Parent and string.lower(focused.Parent.Name) or ""
		if focusedName == "line"
			or focusedName:find("command", 1, true)
			or focusedName:find("console", 1, true)
			or focusedParent:find("command", 1, true)
			or focusedParent:find("console", 1, true)
		then
			return focused
		end
	end

	local best = nil
	local bestScore = -1
	local candidates = {}
	for _, node in ipairs(interface:GetDescendants()) do
		if node:IsA("TextBox") then
			local parentName = node.Parent and node.Parent.Name or ""
			local score = 0
			if node.Name == "Line" then
				score += 20
			elseif node.Name == "Command" then
				score += 10
			end
			if parentName == "Command" then
				score += 20
			end
			if isGuiChainVisible(node) then
				score += 40
			end
			if node.TextEditable then
				score += 10
			end
			if node.AbsoluteSize.X > 0 and node.AbsoluteSize.Y > 0 then
				score += 10
			end
			table.insert(candidates, { node = node, score = score })
			if score > bestScore then
				best = node
				bestScore = score
			end
		end
	end
	if best then
		table.sort(candidates, function(a, b)
			return a.score > b.score
		end)
		for index = 1, math.min(#candidates, 4) do
			local candidate = candidates[index].node
			warn(string.format(
				"S2R command bar candidate: %s score=%d visible=%s editable=%s size=%s",
				instancePath(candidate),
				candidates[index].score,
				tostring(isGuiChainVisible(candidate)),
				tostring(candidate.TextEditable),
				tostring(candidate.AbsoluteSize)
			))
		end
		return best
	end

	local command = interface:FindFirstChild("Command", true)
	local line = command and command:FindFirstChild("Line")
	if line and line:IsA("TextBox") then
		return line
	end
	return nil
end

local function findRgeFrame()
	local interface = PlayerGui:FindFirstChild("RGEInterface", true)
	if not interface then
		return nil
	end
	local reference = Color3.fromRGB(163, 162, 165)
	for _, node in ipairs(interface:GetDescendants()) do
		if node.Name == "Frame" and node:IsA("Frame") then
			local color = node.BackgroundColor3
			local matches = math.abs(color.R - reference.R) <= 0.002
				and math.abs(color.G - reference.G) <= 0.002
				and math.abs(color.B - reference.B) <= 0.002
			if matches then
				return node
			end
		end
	end
	return nil
end

local setStatus
local colorEnabled = false
local materialEnabled = true
local saveFileEnabled = true
local groupEnabled = false

local UI = (function()
	local initialViewport = viewportSize()
	local initialSize = Vector2.new(
		math.min(DEFAULT_SIZE.X, math.max(MIN_SIZE.X, initialViewport.X - 40)),
		math.min(DEFAULT_SIZE.Y, math.max(MIN_SIZE.Y, initialViewport.Y - 40))
	)

	local gui = make("ScreenGui", {
		Name = "S2R++",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.None,
	}, PlayerGui)

	local base = make("Frame", {
		Name = "Base",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(initialSize.X, initialSize.Y),
		BackgroundColor3 = Colors.window,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	local baseCorner = addCorner(base, 10)
	local baseStroke = addStroke(base, 0.9)

	local sidebar = make("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(SIDEBAR_DEFAULT, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, base)

	local divider = make("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, sidebar)

	local dividerInteract = make("TextButton", {
		Name = "DividerInteract",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 7, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 0,
		AutoButtonColor = false,
		ZIndex = 10,
	}, divider)

	local windowControls = make("Frame", {
		Name = "WindowControls",
		Size = UDim2.new(1, 0, 0, 31),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sidebar)

	local controls = make("Frame", {
		Name = "Controls",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, windowControls)
	addList(controls, 5, Enum.FillDirection.Horizontal)
	controls.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	addPadding(controls, 11, 0, 0, 0)

	local exitButton = make("TextButton", {
		Name = "Exit",
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Colors.danger,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 1,
	}, controls)
	addCorner(exitButton, 99)

	local minimizeButton = make("TextButton", {
		Name = "Minimize",
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Colors.warning,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 2,
	}, controls)
	addCorner(minimizeButton, 99)

	local maximizeButton = make("TextButton", {
		Name = "Maximize",
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Colors.success,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 3,
	}, controls)
	addCorner(maximizeButton, 99)

	make("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, windowControls)

	local information = make("Frame", {
		Name = "Information",
		Position = UDim2.fromOffset(0, 31),
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sidebar)

	local informationHolder = make("Frame", {
		Name = "InformationHolder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, information)

	local titleLabel = newLabel(informationHolder, "S2R++", 18, 0.1, Enum.FontWeight.SemiBold)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(23, 10)
	titleLabel.Size = UDim2.new(1, -85, 0, 22)
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local subtitleLabel = newLabel(informationHolder, "RGE Object Transfer", 12, 0.7, Enum.FontWeight.Medium)
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Position = UDim2.fromOffset(23, 34)
	subtitleLabel.Size = UDim2.new(1, -85, 0, 18)
	subtitleLabel.TextYAlignment = Enum.TextYAlignment.Top
	subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local globeButton = make("ImageButton", {
		Name = "GlobalSettingsButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Assets.globe,
		ImageTransparency = 0.5,
	}, informationHolder)

	make("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, information)

	local sidebarGroup = make("Frame", {
		Name = "SidebarGroup",
		Position = UDim2.fromOffset(0, 91),
		Size = UDim2.new(1, 0, 1, -91),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sidebar)

	local tabsFrame = make("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(10, 31),
		Size = UDim2.new(1, -20, 1, -138),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sidebarGroup)
	addList(tabsFrame, 8)

	local userInfo = make("Frame", {
		Name = "UserInfo",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 107),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sidebarGroup)

	local _userInfoDivider = make("Frame", {
		Name = "Divider",
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 0, 1),
	}, userInfo)

	local userGroup = make("Frame", {
		Name = "UserGroup",
		Position = UDim2.fromOffset(35, 0),
		Size = UDim2.new(1, -45, 1, -17),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, userInfo)

	local avatar = make("ImageLabel", {
		Name = "Headshot",
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Assets.userInfoBlurred,
	}, userGroup)
	addCorner(avatar, 99)
	addStroke(avatar, 0.9)

	task.spawn(function()
		local success, image, ready = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size48x48)
		end)
		if success and ready and image then
			avatar.Image = image
		end
	end)

	local userText = make("Frame", {
		Name = "UserText",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -42, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, userGroup)
	addList(userText, 1)
	userText.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local displayName = newLabel(userText, LocalPlayer.DisplayName, 13, 0.1, Enum.FontWeight.SemiBold)
	displayName.Name = "DisplayName"
	displayName.Size = UDim2.new(1, 0, 0, 15)
	displayName.LayoutOrder = 1
	displayName.TextTruncate = Enum.TextTruncate.AtEnd

	local username = newLabel(userText, "@" .. LocalPlayer.Name, 12, 0.7, Enum.FontWeight.Medium)
	username.Name = "Username"
	username.Size = UDim2.new(1, 0, 0, 15)
	username.LayoutOrder = 2
	username.TextTruncate = Enum.TextTruncate.AtEnd

	local content = make("Frame", {
		Name = "Content",
		Position = UDim2.fromScale(SIDEBAR_DEFAULT, 0),
		Size = UDim2.new(1 - SIDEBAR_DEFAULT, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, base)

	local function setSidebarRatio(ratio, width)
		width = width or base.AbsoluteSize.X
		local maximum = math.max(SIDEBAR_MIN, math.min(SIDEBAR_MAX, 1 - MIN_CONTENT_WIDTH / width))
		local clamped = math.clamp(ratio, SIDEBAR_MIN, maximum)
		sidebar.Size = UDim2.fromScale(clamped, 1)
		content.Position = UDim2.fromScale(clamped, 0)
		content.Size = UDim2.new(1 - clamped, 0, 1, 0)
		return clamped
	end

	setSidebarRatio(SIDEBAR_DEFAULT, initialSize.X)

	local topbar = make("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 63),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
	}, content)

	local dragArea = make("TextButton", {
		Name = "DragArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
	}, topbar)

	local currentTabLabel = newLabel(topbar, "Перенос", 15, 0.5, Enum.FontWeight.Regular)
	currentTabLabel.Name = "CurrentTab"
	currentTabLabel.Position = UDim2.fromOffset(20, 0)
	currentTabLabel.Size = UDim2.new(1, -60, 1, 0)
	currentTabLabel.ZIndex = 2
	currentTabLabel.TextYAlignment = Enum.TextYAlignment.Center

	make("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, topbar)

	local resizeHandle = make("ImageButton", {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Assets.resize,
		ImageTransparency = 0.65,
		ZIndex = 12,
	}, base)

	local tabRecords = {}
	local pageRecords = {}
	local selectTab

	local function createTab(key, title, image, order)
		local button = make("TextButton", {
			Name = key,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Colors.card,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
		}, tabsFrame)
		addCorner(button, 6)
		local tabStroke = addStroke(button, 1)

		local icon = make("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 20, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = image,
			ImageTransparency = 0.5,
		}, button)

		local label = newLabel(button, title, 16, 0.5, Enum.FontWeight.Medium)
		label.Name = "TabSwitcherName"
		label.Position = UDim2.fromOffset(46, 0)
		label.Size = UDim2.new(1, -66, 1, 0)

		make("Frame", {
			Name = "SelectedAccent",
			Position = UDim2.new(0, 8, 0.5, -7),
			Size = UDim2.fromOffset(2, 14),
			BackgroundColor3 = Colors.text,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, button)

		local record = {
			key = key,
			button = button,
			stroke = tabStroke,
			icon = icon,
			label = label,
			selected = false,
		}
		tabRecords[key] = record

		button.MouseEnter:Connect(function()
			if record.selected then
				return
			end
			tween(button, 0.18, { BackgroundTransparency = 0.99 }):Play()
			tween(label, 0.18, { TextTransparency = 0.3 }):Play()
			tween(icon, 0.18, { ImageTransparency = 0.3 }):Play()
		end)

		button.MouseLeave:Connect(function()
			if record.selected then
				return
			end
			tween(button, 0.18, { BackgroundTransparency = 1 }):Play()
			tween(label, 0.18, { TextTransparency = 0.5 }):Play()
			tween(icon, 0.18, { ImageTransparency = 0.5 }):Play()
		end)

		button.MouseButton1Click:Connect(function()
			if selectTab then
				selectTab(key)
			end
		end)

		return record
	end

	local _transferTab = createTab("transfer", "Перенос", Assets.transferTab, 1)
	local _helpTab = createTab("help", "Помощь", Assets.helpTab, 2)

	local function createPage(key)
		local page = make("Frame", {
			Name = key,
			Position = UDim2.fromOffset(0, 63),
			Size = UDim2.new(1, 0, 1, -63),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
		}, content)
		pageRecords[key] = page
		return page
	end

	local transferPage = createPage("transfer")
	local helpPage = createPage("help")

	local function createScroller(parent, name)
		local scroller = make("ScrollingFrame", {
			Name = name or "Scrolling",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageTransparency = 0.8,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ClipsDescendants = true,
		}, parent)
		addPadding(scroller, 0, 0, 18, 18)
		return scroller
	end

	local function createScrollerBody(parent)
		local body = make("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -40, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		addList(body, 15)
		return body
	end

	local function createSection(parent, size, layoutOrder)
		local section = make("Frame", {
			Name = "Section",
			Size = size,
			LayoutOrder = layoutOrder or 0,
			BackgroundColor3 = Colors.card,
			BackgroundTransparency = 0.98,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, parent)
		addCorner(section, 10)
		addStroke(section, 0.95)
		return section
	end

	local function setupSectionLayout(section, gap)
		local inner = make("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(20, 22),
			Size = UDim2.new(1, -38, 1, -42),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, section)
		addList(inner, gap or 10)
		return inner
	end

	local function addHeader(parent, text)
		local header = newLabel(parent, text, 16, 0.3, Enum.FontWeight.Medium)
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 19)
		header.TextYAlignment = Enum.TextYAlignment.Top
		header.TextWrapped = true
		autoOrder(header)
		return header
	end

	local function addInputRow(parent, labelText, placeholder, defaultValue, boxWidth, numeric)
		local row = make("Frame", {
			Name = "InputRow",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		autoOrder(row)

		local label = newLabel(row, labelText, 13, 0.5)
		label.Name = "Label"
		label.Size = UDim2.new(1, -(boxWidth + 10), 1, 0)

		local box = make("TextBox", {
			Name = labelText,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(boxWidth, 26),
			BackgroundColor3 = Colors.input,
			BackgroundTransparency = 0.95,
			BorderSizePixel = 0,
			Text = defaultValue or "",
			PlaceholderText = placeholder or "",
			PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
			TextColor3 = Colors.text,
			TextSize = 12,
			TextTransparency = 0.1,
			TextXAlignment = numeric and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ClearTextOnFocus = false,
			MultiLine = false,
			TextWrapped = false,
		}, row)
		box.FontFace = interFont(Enum.FontWeight.Regular)
		addCorner(box, 5)
		addStroke(box, 0.9)
		addPadding(box, 8, 8, 0, 0)

		if numeric then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				local cleaned = box.Text:gsub("%D", "")
				cleaned = cleaned:sub(1, 3)
				if cleaned ~= box.Text then
					box.Text = cleaned
				end
			end)
		end

		return box
	end

	local function addFloatInputRow(parent, labelText, placeholder, boxWidth)
		local box = addInputRow(parent, labelText, placeholder, "", boxWidth, false)
		box.TextXAlignment = Enum.TextXAlignment.Center
		local lastValid = ""
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local text = box.Text
			if text == "" or text == "-" or text:match("^%-?%d*%.?%d*$") then
				lastValid = text
			else
				box.Text = lastValid
			end
		end)
		return box
	end

	local function addToggleRow(parent, labelText, defaultValue, callback)
		local row = make("Frame", {
			Name = "ToggleRow",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		autoOrder(row)

		local label = newLabel(row, labelText, 13, 0.5)
		label.Size = UDim2.new(1, -58, 1, 0)

		local track = make("ImageButton", {
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(41, 21),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = Assets.toggleBackground,
			ImageColor3 = Color3.fromRGB(87, 86, 86),
			ImageTransparency = 0.5,
			AutoButtonColor = false,
			Active = true,
		}, row)
		addPadding(track, -2, 3, 1, 1)

		local head = make("ImageLabel", {
			Name = "TogglerHead",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(15, 15),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = Assets.toggleHead,
			ImageColor3 = Colors.text,
			ImageTransparency = 0.85,
			ZIndex = 2,
		}, track)

		local state = defaultValue == true
		local enabled = true

		local function applyState(newState, fireCallback)
			if not enabled then
				newState = false
			end
			state = newState
			local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(track, info, {
				ImageTransparency = enabled and (state and 0 or 0.5) or 0.85,
			}):Play()
			TweenService:Create(head, info, {
				ImageTransparency = enabled and (state and 0 or 0.85) or 0.95,
				Position = state and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0.5, 0.5),
			}):Play()
			if fireCallback and callback then
				task.spawn(callback, state)
			end
		end

		applyState(state, false)

		track.MouseButton1Click:Connect(function()
			if not enabled then
				return
			end
			applyState(not state, true)
		end)

		local function setEnabled(value)
			enabled = value == true
			track.Active = enabled
			track.ImageColor3 = enabled and Color3.fromRGB(87, 86, 86) or Color3.fromRGB(65, 65, 65)
			label.TextTransparency = enabled and 0.5 or 0.78
			if not enabled and state then
				applyState(false, true)
			else
				applyState(state, false)
			end
		end

		return function(newState)
			applyState(newState, false)
		end, {
			setEnabled = setEnabled,
			setState = function(newState)
				applyState(newState, false)
			end,
			getState = function()
				return state
			end,
		}
	end

	local transferScroller = createScroller(transferPage)
	local transferBody = createScrollerBody(transferScroller)

	local topRow = make("Frame", {
		Name = "TopRow",
		Size = UDim2.new(1, 0, 0, 382),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, transferBody)

	local settingsSection = createSection(topRow, UDim2.new(0.5, -8, 1, 0), 1)
	settingsSection.Name = "SettingsSection"

	local settingsContent = make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -38, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, settingsSection)

	local settingsHeader = addHeader(settingsContent, "Параметры")
	settingsHeader.Position = UDim2.fromOffset(0, 0)

	local settingsScroll = make("ScrollingFrame", {
		Name = "SettingsScroll",
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, -6, 1, -25),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
	}, settingsContent)
	addPadding(settingsScroll, 0, 6, 0, 4)

	local settingsFields = make("Frame", {
		Name = "Fields",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, settingsScroll)
	addList(settingsFields, 10)

	local nameBox
	local groupFields

	local function setFileNameEnabled(state)
		if not nameBox then
			return
		end
		local row = nameBox.Parent
		local label = row and row:FindFirstChild("Label")
		nameBox.TextEditable = state
		nameBox.Active = state
		nameBox.TextTransparency = state and 0.1 or 0.5
		nameBox.PlaceholderColor3 = state and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(75, 75, 75)
		nameBox.BackgroundTransparency = state and 0.95 or 1
		if label then
			label.TextTransparency = state and 0.5 or 0.75
		end
	end

	addToggleRow(settingsFields, "Сохранить в файл", saveFileEnabled, function(state)
		saveFileEnabled = state
		setFileNameEnabled(state)
	end)

	nameBox = addInputRow(settingsFields, "Имя файла", "Example1", "", 120, false)
	nameBox.Name = "nameBox"
	setFileNameEnabled(saveFileEnabled)

	local worldBox = addInputRow(settingsFields, "World", "1", "1", 62, true)
	worldBox.Name = "worldBox"

	local previewSection = make("Frame", {
		Name = "PreviewSection",
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundColor3 = Colors.editor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, settingsFields)
	autoOrder(previewSection)
	addCorner(previewSection, 7)
	addStroke(previewSection, 0.9)

	local previewViewport = make("ViewportFrame", {
		Name = "PreviewViewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ImageTransparency = 0,
	}, previewSection)
	addCorner(previewViewport, 7)

	local previewCamera = make("Camera", {
		Name = "PreviewCamera",
		FieldOfView = 30,
	}, previewViewport)
	previewViewport.CurrentCamera = previewCamera

	local previewTitle = newLabel(previewSection, "Предпросмотр", 11, 0.3, Enum.FontWeight.Medium)
	previewTitle.Name = "PreviewTitle"
	previewTitle.Position = UDim2.fromOffset(8, 6)
	previewTitle.Size = UDim2.new(0.55, 0, 0, 14)
	previewTitle.ZIndex = 3

	local previewRefresh = make("TextButton", {
		Name = "PreviewRefresh",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(62, 18),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Text = "Обновить",
		TextColor3 = Colors.text,
		TextTransparency = 0.3,
		TextSize = 10,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
		ZIndex = 3,
	}, previewSection)
	addCorner(previewRefresh, 4)
	addStroke(previewRefresh, 0.92)

	local previewStatus = newLabel(previewSection, "Нет данных", 10, 0.55)
	previewStatus.Name = "PreviewStatus"
	previewStatus.AnchorPoint = Vector2.new(0, 1)
	previewStatus.Position = UDim2.new(0, 8, 1, -6)
	previewStatus.Size = UDim2.new(1, -16, 0, 14)
	previewStatus.TextTruncate = Enum.TextTruncate.AtEnd
	previewStatus.ZIndex = 3

	previewRefresh.MouseEnter:Connect(function()
		tween(previewRefresh, 0.15, { BackgroundTransparency = 0.85, TextTransparency = 0.1 }):Play()
	end)
	previewRefresh.MouseLeave:Connect(function()
		tween(previewRefresh, 0.15, { BackgroundTransparency = 0.94, TextTransparency = 0.3 }):Play()
	end)

	addToggleRow(settingsFields, "Импорт цвета", colorEnabled, function(state)
		colorEnabled = state
	end)

	addToggleRow(settingsFields, "Импорт материала", materialEnabled, function(state)
		materialEnabled = state
	end)

	local _, groupToggle = addToggleRow(settingsFields, "Сгруппировать", groupEnabled, function(state)
		groupEnabled = state
		if groupFields then
			groupFields.Visible = state
		end
	end)

	groupFields = make("Frame", {
		Name = "GroupFields",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, settingsFields)
	autoOrder(groupFields)
	addList(groupFields, 10)

	local groupNameBox = addInputRow(groupFields, "Имя модели", "MyModel", "", 120, false)
	groupNameBox.Name = "groupNameBox"
	local groupXBox = addFloatInputRow(groupFields, "pX", "0", 120)
	local groupYBox = addFloatInputRow(groupFields, "pY", "0", 120)
	local groupZBox = addFloatInputRow(groupFields, "pZ", "0", 120)

	local statsSection = createSection(topRow, UDim2.new(0.5, -8, 1, 0), 2)
	statsSection.Name = "StatsSection"
	statsSection.Position = UDim2.new(0.5, 8, 0, 0)
	local statsContent = setupSectionLayout(statsSection, 8)
	addHeader(statsContent, "Состояние")

	local statusLabel = newLabel(statsContent, "Ожидание данных", 11, 0.45)
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 32)
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	autoOrder(statusLabel)

	local progressTrack = make("Frame", {
		Name = "ProgressTrack",
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, statsContent)
	addCorner(progressTrack, 3)
	autoOrder(progressTrack)

	local progressFill = make("Frame", {
		Name = "ProgressFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, progressTrack)
	addCorner(progressFill, 3)

	local progressMeta = make("Frame", {
		Name = "ProgressMeta",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, statsContent)
	autoOrder(progressMeta)

	local progressPercent = newLabel(progressMeta, "0%", 11, 0.55)
	progressPercent.Name = "ProgressPercent"
	progressPercent.Size = UDim2.new(0.5, 0, 1, 0)

	local progressNumbers = newLabel(progressMeta, "0 / 0", 11, 0.55)
	progressNumbers.Name = "ProgressNumbers"
	progressNumbers.Position = UDim2.new(0.5, 0, 0, 0)
	progressNumbers.Size = UDim2.new(0.5, 0, 1, 0)
	progressNumbers.TextXAlignment = Enum.TextXAlignment.Right

	local perenesenoLabel = newLabel(statsContent, "Перенесено объектов: 0/0", 11, 0.5)
	perenesenoLabel.Name = "Pereneseno"
	perenesenoLabel.Size = UDim2.new(1, 0, 0, 26)
	perenesenoLabel.TextYAlignment = Enum.TextYAlignment.Top
	perenesenoLabel.TextWrapped = true
	autoOrder(perenesenoLabel)

	local etaLabel = newLabel(statsContent, "Примерное время ожидания: 0 сек.", 11, 0.65)
	etaLabel.Name = "OstalosTime"
	etaLabel.Size = UDim2.new(1, 0, 0, 30)
	etaLabel.TextYAlignment = Enum.TextYAlignment.Top
	etaLabel.TextWrapped = true
	autoOrder(etaLabel)

	local worldStatus = newLabel(statsContent, "World: 1", 11, 0.72)
	worldStatus.Name = "WorldStatus"
	worldStatus.Size = UDim2.new(1, 0, 0, 16)
	autoOrder(worldStatus)

	local dataSection = createSection(transferBody, UDim2.new(1, 0, 0, 282), 2)
	dataSection.Name = "DataSection"

	local dataContent = make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.new(1, -38, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, dataSection)

	local dataHeader = newLabel(dataContent, "Данные таблицы", 16, 0.3, Enum.FontWeight.Medium)
	dataHeader.Name = "Header"
	dataHeader.Size = UDim2.new(1, 0, 0, 19)
	dataHeader.TextYAlignment = Enum.TextYAlignment.Top

	local dataHint = newLabel(dataContent, "Вставьте Lua-таблицу объектов.", 12, 0.65)
	dataHint.Name = "Hint"
	dataHint.Position = UDim2.fromOffset(0, 23)
	dataHint.Size = UDim2.new(1, 0, 0, 16)
	dataHint.TextTruncate = Enum.TextTruncate.AtEnd

	local importButton = make("TextButton", {
		Name = "ImportButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(106, 20),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Text = "Импорт файла",
		TextColor3 = Colors.text,
		TextTransparency = 0.3,
		TextSize = 11,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
	}, dataContent)
	addCorner(importButton, 5)
	addStroke(importButton, 0.9)

	importButton.MouseEnter:Connect(function()
		tween(importButton, 0.15, { BackgroundTransparency = 0.86, TextTransparency = 0.1 }):Play()
	end)
	importButton.MouseLeave:Connect(function()
		tween(importButton, 0.15, { BackgroundTransparency = 0.94, TextTransparency = 0.3 }):Play()
	end)

	local removePrefabsButton = make("TextButton", {
		Name = "RemovePrefabsButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -112, 0, 0),
		Size = UDim2.fromOffset(118, 20),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Text = "Убрать prefab'ы",
		TextColor3 = Colors.warning,
		TextTransparency = 0.1,
		TextSize = 11,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
		Active = true,
		Visible = false,
	}, dataContent)
	addCorner(removePrefabsButton, 5)
	addStroke(removePrefabsButton, 0.9)

	removePrefabsButton.MouseEnter:Connect(function()
		if removePrefabsButton.Active then
			tween(removePrefabsButton, 0.15, { BackgroundTransparency = 0.86, TextTransparency = 0 }):Play()
		end
	end)
	removePrefabsButton.MouseLeave:Connect(function()
		tween(removePrefabsButton, 0.15, { BackgroundTransparency = 0.94, TextTransparency = 0.1 }):Play()
	end)

	local editorFrame = make("Frame", {
		Name = "Editor",
		Position = UDim2.fromOffset(0, 45),
		Size = UDim2.new(1, 0, 0, 154),
		BackgroundColor3 = Colors.editor,
		BorderSizePixel = 0,
	}, dataContent)
	addCorner(editorFrame, 7)
	addStroke(editorFrame, 0.92)

	local editorScroll = make("ScrollingFrame", {
		Name = "EditorScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.75,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
	}, editorFrame)
	addPadding(editorScroll, 0, 0, 10, 10)

	local dataBox = make("TextBox", {
		Name = "dataBox",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "{\n\t{ \"wedge\", Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), Vector3.new(4, 4, 4), Color3.fromRGB(255, 255, 255), \"SmoothPlastic\" }\n}",
		PlaceholderColor3 = Color3.fromRGB(95, 95, 95),
		TextColor3 = Colors.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MultiLine = true,
		ClearTextOnFocus = false,
		Font = Enum.Font.RobotoMono,
	}, editorScroll)
	addPadding(dataBox, 0, 4, 0, 0)
	make("UISizeConstraint", {
		MinSize = Vector2.new(0, 130),
	}, dataBox)

	local actionRow = make("Frame", {
		Name = "Actions",
		Position = UDim2.fromOffset(0, 209),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, dataContent)

	local startButton = make("TextButton", {
		Name = "startBtn",
		Size = UDim2.new(0.55, -5, 1, 0),
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Text = "Начать перенос",
		TextColor3 = Colors.primaryText,
		TextSize = 14,
		FontFace = interFont(Enum.FontWeight.SemiBold),
		AutoButtonColor = false,
	}, actionRow)
	addCorner(startButton, 6)

	local clearButton = make("TextButton", {
		Name = "ClearTableBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		Text = "Очистить",
		TextColor3 = Colors.text,
		TextTransparency = 0.35,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
	}, actionRow)
	addCorner(clearButton, 6)
	addStroke(clearButton, 0.9)

	startButton.MouseEnter:Connect(function()
		if startButton.Active then
			tween(startButton, 0.18, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end
	end)
	startButton.MouseLeave:Connect(function()
		tween(startButton, 0.18, { BackgroundColor3 = startButton.Active and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(165, 165, 165) }):Play()
	end)
	clearButton.MouseEnter:Connect(function()
		tween(clearButton, 0.18, { BackgroundTransparency = 0.92, TextTransparency = 0.15 }):Play()
	end)
	clearButton.MouseLeave:Connect(function()
		tween(clearButton, 0.18, { BackgroundTransparency = 0.95, TextTransparency = 0.35 }):Play()
	end)

	local function addParagraph(parent, textValue, height)
		local paragraph = newLabel(parent, textValue, 13, 0.55)
		paragraph.Name = "Paragraph"
		paragraph.Size = UDim2.new(1, 0, 0, height or 48)
		paragraph.TextYAlignment = Enum.TextYAlignment.Top
		paragraph.TextWrapped = true
		autoOrder(paragraph)
		return paragraph
	end

	local function addInfoRow(parent, labelText, valueText, valueColor)
		local row = make("Frame", {
			Name = "InfoRow",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		autoOrder(row)
		local left = newLabel(row, labelText, 12, 0.55)
		left.Size = UDim2.new(0.52, 0, 1, 0)
		local right = newLabel(row, valueText, 12, 0.78)
		right.Position = UDim2.new(0.52, 0, 0, 0)
		right.Size = UDim2.new(0.48, 0, 1, 0)
		right.TextXAlignment = Enum.TextXAlignment.Right
		if valueColor then
			make("UIStroke", {
				Color = valueColor,
				Transparency = 0.1,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}, right)
		end
		return row
	end

	local function addIconInfoRow(parent, labelText, iconType, iconColor)
		local row = make("Frame", {
			Name = "InfoRow",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		autoOrder(row)
		local left = newLabel(row, labelText, 12, 0.55)
		left.Size = UDim2.new(0.6, 0, 1, 0)
		if iconType == "globe" then
			make("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -1, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = Assets.globe,
				ImageTransparency = 0.35,
			}, row)
		else
			local dot = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = iconColor,
				BorderSizePixel = 0,
			}, row)
			addCorner(dot, 99)
		end
		return row
	end

	local function addBindRow(parent)
		local row = make("Frame", {
			Name = "BindRow",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, parent)
		autoOrder(row)
		local label = newLabel(row, "Открыть окно", 12, 0.55)
		label.Size = UDim2.new(0.52, 0, 1, 0)
		local button = make("TextButton", {
			Name = "BindButton",
			Position = UDim2.new(0.52, 0, 0, 0),
			Size = UDim2.new(0.48, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = formatBind(),
			TextColor3 = Colors.text,
			TextTransparency = 0.3,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = interFont(Enum.FontWeight.Medium),
			AutoButtonColor = false,
		}, row)
		button.MouseEnter:Connect(function()
			if not awaitingBind then
				tween(button, 0.15, { TextTransparency = 0.1 }):Play()
			end
		end)
		button.MouseLeave:Connect(function()
			if not awaitingBind then
				tween(button, 0.15, { TextTransparency = 0.3 }):Play()
			end
		end)
		button.MouseButton1Click:Connect(function()
			if destroyed then
				return
			end
			awaitingBind = true
			button.Text = "Нажмите клавиши..."
			button.TextTransparency = 0.5
		end)
		return button
	end

	local helpScroller = createScroller(helpPage)
	local helpBody = createScrollerBody(helpScroller)

	local guideSection = createSection(helpBody, UDim2.new(1, 0, 0, 224), 1)
	local guideContent = setupSectionLayout(guideSection, 10)
	addHeader(guideContent, "Как пользоваться")
	addParagraph(guideContent, "1. Вставьте таблицу или выберите .txt / .luau из папки S2R: предпросмотр появится в «Параметрах».\n2. Укажите имя файла, World и при необходимости включите группировку.\n3. Нажмите «Начать перенос»: команды введутся в RGE автоматически.\n4. Скрипт телепортирует вас к постройке и включит DefaultView.\n5. При включённом сохранении файл запишется автоматически.\n6. Префабы из строк «prefab» или «prop» переносятся командой spawn; размер из шестого поля — командой size.\n7. В консоли RGE закреплена строка [made by mstbek] S2R++ Initialized.", 150)

	local controlsSection = createSection(helpBody, UDim2.new(1, 0, 0, 222), 2)
	local controlsContent = setupSectionLayout(controlsSection, 10)
	addHeader(controlsContent, "Управление")
	local bindButton = addBindRow(controlsContent)
	addIconInfoRow(controlsContent, "Развернуть", "dot", Colors.success)
	addIconInfoRow(controlsContent, "Уничтожить", "dot", Colors.danger)
	addIconInfoRow(controlsContent, "Свернуть", "dot", Colors.warning)
	addIconInfoRow(controlsContent, "Справка", "globe")

	local creditsSection = createSection(helpBody, UDim2.new(1, 0, 0, 158), 3)
	local creditsContent = setupSectionLayout(creditsSection, 10)
	addHeader(creditsContent, "Авторы")
	addParagraph(creditsContent, "Script made by: mstbek", 16)
	addParagraph(creditsContent, "Remake by: SuriyaMuri ( @shika_grr )", 16)
	addParagraph(creditsContent, "S2R++ — панель переноса объектов для RGE.", 30)

	selectTab = function(key)
		local selectedPage = pageRecords[key]
		if not selectedPage then
			return
		end

		for recordKey, record in pairs(tabRecords) do
			local isSelected = recordKey == key
			record.selected = isSelected
			local accent = record.button:FindFirstChild("SelectedAccent")
			tween(record.button, 0.15, {
				BackgroundTransparency = isSelected and 0.98 or 1,
			}):Play()
			tween(record.stroke, 0.15, {
				Transparency = isSelected and 0.95 or 1,
			}):Play()
			tween(record.icon, 0.15, {
				ImageTransparency = isSelected and 0.1 or 0.5,
			}):Play()
			tween(record.label, 0.15, {
				TextTransparency = isSelected and 0.1 or 0.5,
			}):Play()
			if accent then
				tween(accent, 0.15, {
					BackgroundTransparency = isSelected and 0.2 or 1,
				}):Play()
			end
		end

		for pageKey, page in pairs(pageRecords) do
			page.Visible = pageKey == key
		end

		currentTabLabel.Text = key == "transfer" and "Перенос" or "Помощь"
	end

	selectTab("transfer")

	globeButton.MouseEnter:Connect(function()
		tween(globeButton, 0.2, { ImageTransparency = 0.3 }):Play()
	end)
	globeButton.MouseLeave:Connect(function()
		tween(globeButton, 0.2, { ImageTransparency = 0.5 }):Play()
	end)
	globeButton.MouseButton1Click:Connect(function()
		selectTab("help")
	end)

	local function shutdown()
		if destroyed then
			return
		end
		destroyed = true
		if hotkeyConnection then
			hotkeyConnection:Disconnect()
		end
		if inputChangedConnection then
			inputChangedConnection:Disconnect()
		end
		if inputEndedConnection then
			inputEndedConnection:Disconnect()
		end
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		if expandConnection then
			expandConnection:Disconnect()
		end
		if consoleWatchdogConnection then
			consoleWatchdogConnection:Disconnect()
			consoleWatchdogConnection = nil
		end
		gui:Destroy()
	end

	exitButton.MouseButton1Click:Connect(shutdown)
	minimizeButton.MouseButton1Click:Connect(function()
		base.Visible = false
	end)

	local importOverlay = make("Frame", {
		Name = "ImportOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 50,
		Active = true,
		Visible = false,
	}, base)
	addCorner(importOverlay, 10)

	local importCard = make("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 222),
		BackgroundColor3 = Color3.fromRGB(17, 17, 17),
		BorderSizePixel = 0,
		ZIndex = 51,
	}, importOverlay)
	addCorner(importCard, 10)
	addStroke(importCard, 0.9)

	local importTitle = newLabel(importCard, "Импорт Lua-таблицы", 18, 0.08, Enum.FontWeight.SemiBold)
	importTitle.Name = "Title"
	importTitle.Position = UDim2.fromOffset(24, 22)
	importTitle.Size = UDim2.new(1, -48, 0, 24)
	importTitle.TextYAlignment = Enum.TextYAlignment.Top
	importTitle.ZIndex = 52

	local importHint = newLabel(importCard, "Файлы .txt / .lua / .luau из папки S2R в workspace executor.", 12, 0.6)
	importHint.Name = "Hint"
	importHint.Position = UDim2.fromOffset(24, 50)
	importHint.Size = UDim2.new(1, -48, 0, 18)
	importHint.TextYAlignment = Enum.TextYAlignment.Top
	importHint.ZIndex = 52

	local importFileDropdown = make("TextButton", {
		Name = "FileDropdown",
		Position = UDim2.fromOffset(24, 78),
		Size = UDim2.new(1, -48, 0, 38),
		BackgroundColor3 = Colors.input,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		Text = "Выберите .txt / .luau файл",
		TextColor3 = Colors.text,
		TextTransparency = 0.2,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = false,
		ZIndex = 52,
	}, importCard)
	addCorner(importFileDropdown, 5)
	addStroke(importFileDropdown, 0.9)
	addPadding(importFileDropdown, 12, 12, 0, 0)

	local importFileList = make("ScrollingFrame", {
		Name = "FileDropdownList",
		Position = UDim2.fromOffset(24, 120),
		Size = UDim2.new(1, -48, 0, 96),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.7,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 53,
	}, importCard)
	addCorner(importFileList, 6)
	addStroke(importFileList, 0.85)
	addPadding(importFileList, 4, 4, 4, 4)
	addList(importFileList, 2)

	local importStatus = newLabel(importCard, "", 11, 0.4, Enum.FontWeight.Medium)
	importStatus.Name = "ImportStatus"
	importStatus.Position = UDim2.fromOffset(24, 120)
	importStatus.Size = UDim2.new(1, -48, 0, 28)
	importStatus.TextYAlignment = Enum.TextYAlignment.Top
	importStatus.TextWrapped = true
	importStatus.ZIndex = 52

	local importLoadButton = make("TextButton", {
		Name = "Load",
		Position = UDim2.fromOffset(24, 151),
		Size = UDim2.new(0.5, -30, 0, 38),
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Text = "Загрузить",
		TextColor3 = Colors.primaryText,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.SemiBold),
		AutoButtonColor = false,
		ZIndex = 52,
	}, importCard)
	addCorner(importLoadButton, 6)

	local importCancelButton = make("TextButton", {
		Name = "Cancel",
		Position = UDim2.new(0.5, 6, 0, 151),
		Size = UDim2.new(0.5, -30, 0, 38),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Text = "Отмена",
		TextColor3 = Colors.text,
		TextTransparency = 0.3,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
		ZIndex = 52,
	}, importCard)
	addCorner(importCancelButton, 6)
	addStroke(importCancelButton, 0.9)

	importLoadButton.MouseEnter:Connect(function()
		tween(importLoadButton, 0.18, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end)
	importLoadButton.MouseLeave:Connect(function()
		tween(importLoadButton, 0.18, { BackgroundColor3 = Color3.fromRGB(245, 245, 245) }):Play()
	end)
	importCancelButton.MouseEnter:Connect(function()
		tween(importCancelButton, 0.18, { BackgroundTransparency = 0.86, TextTransparency = 0.1 }):Play()
	end)
	importCancelButton.MouseLeave:Connect(function()
		tween(importCancelButton, 0.18, { BackgroundTransparency = 0.94, TextTransparency = 0.3 }):Play()
	end)
	importFileDropdown.MouseEnter:Connect(function()
		tween(importFileDropdown, 0.15, { BackgroundTransparency = 0.88, TextTransparency = 0.05 }):Play()
	end)
	importFileDropdown.MouseLeave:Connect(function()
		tween(importFileDropdown, 0.15, { BackgroundTransparency = 0.95, TextTransparency = 0.2 }):Play()
	end)
	local dragging = false
	local dragStart
	local dragStartPosition

	local function startDragging(input)
		if destroyed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragStart = input.Position
		dragStartPosition = base.Position
	end

	dragArea.InputBegan:Connect(startDragging)

	local resizing = false
	local resizeStart
	local resizeStartSize
	local resizeStartPosition

	resizeHandle.MouseEnter:Connect(function()
		tween(resizeHandle, 0.18, { ImageTransparency = 0.3 }):Play()
	end)
	resizeHandle.MouseLeave:Connect(function()
		tween(resizeHandle, 0.18, { ImageTransparency = 0.65 }):Play()
	end)
	resizeHandle.InputBegan:Connect(function(input)
		if destroyed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		resizing = true
		resizeStart = UserInputService:GetMouseLocation()
		resizeStartSize = Vector2.new(base.AbsoluteSize.X, base.AbsoluteSize.Y)
		resizeStartPosition = base.Position
	end)

	local resizingSidebar = false
	local sidebarStartMouse
	local sidebarStartRatio = SIDEBAR_DEFAULT

	dividerInteract.MouseEnter:Connect(function()
		tween(divider, 0.18, { BackgroundTransparency = 0.78 }):Play()
	end)
	dividerInteract.MouseLeave:Connect(function()
		tween(divider, 0.18, { BackgroundTransparency = 0.9 }):Play()
	end)
	dividerInteract.MouseButton1Down:Connect(function()
		resizingSidebar = true
		sidebarStartMouse = UserInputService:GetMouseLocation().X
		sidebarStartRatio = sidebar.Size.X.Scale
	end)

	inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if destroyed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if dragging then
			if expanded and leaveExpanded then
				leaveExpanded(false)
			end
			local delta = input.Position - dragStart
			base.Position = UDim2.new(
				dragStartPosition.X.Scale,
				dragStartPosition.X.Offset + delta.X,
				dragStartPosition.Y.Scale,
				dragStartPosition.Y.Offset + delta.Y
			)
		end

		if resizing then
			if expanded and leaveExpanded then
				leaveExpanded(false)
			end
			local mouse = UserInputService:GetMouseLocation()
			local delta = mouse - resizeStart
			local maximum = maxWindowSize()
			local targetSize = Vector2.new(
				math.clamp(resizeStartSize.X + delta.X, MIN_SIZE.X, maximum.X),
				math.clamp(resizeStartSize.Y + delta.Y, MIN_SIZE.Y, maximum.Y)
			)
			local applied = targetSize - resizeStartSize
			base.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
			base.Position = UDim2.new(
				resizeStartPosition.X.Scale,
				resizeStartPosition.X.Offset + applied.X / 2,
				resizeStartPosition.Y.Scale,
				resizeStartPosition.Y.Offset + applied.Y / 2
			)
			setSidebarRatio(sidebar.Size.X.Scale, targetSize.X)
		end

		if resizingSidebar then
			local currentMouse = UserInputService:GetMouseLocation().X
			local deltaX = currentMouse - sidebarStartMouse
			setSidebarRatio(sidebarStartRatio + deltaX / base.AbsoluteSize.X, base.AbsoluteSize.X)
		end
	end)

	inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if destroyed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			resizing = false
			resizingSidebar = false
		end
	end)

	hotkeyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if destroyed then
			return
		end
		if awaitingBind then
			if input.KeyCode == Enum.KeyCode.Escape then
				awaitingBind = false
				if bindButton then
					bindButton.Text = formatBind()
					bindButton.TextTransparency = 0.3
				end
				return
			end
			if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
				return
			end
			if isBindModifier(input.KeyCode) then
				return
			end
			local modifiers = {}
			for _, keyCode in ipairs({
				Enum.KeyCode.LeftControl,
				Enum.KeyCode.RightControl,
				Enum.KeyCode.LeftShift,
				Enum.KeyCode.RightShift,
				Enum.KeyCode.LeftAlt,
				Enum.KeyCode.RightAlt,
			}) do
				if UserInputService:IsKeyDown(keyCode) then
					table.insert(modifiers, keyCode)
				end
			end
			hotkeyBind.modifiers = modifiers
			hotkeyBind.key = input.KeyCode
			awaitingBind = false
			if bindButton then
				bindButton.Text = formatBind()
				bindButton.TextTransparency = 0.3
			end
			return
		end
		if input.KeyCode == hotkeyBind.key then
			local matches = true
			for _, keyCode in ipairs(hotkeyBind.modifiers) do
				if not UserInputService:IsKeyDown(keyCode) then
					matches = false
					break
				end
			end
			if matches then
				if base.Visible then
					base.Visible = false
					if expanded and leaveExpanded then
						leaveExpanded(true)
					end
				else
					base.Visible = true
				end
				return
			end
		end
	end)

	if Camera then
		cameraConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if destroyed then
				return
			end
			local maximum = maxWindowSize()
			local current = Vector2.new(base.AbsoluteSize.X, base.AbsoluteSize.Y)
			if current.X > maximum.X or current.Y > maximum.Y then
				local clamped = Vector2.new(
					math.min(current.X, maximum.X),
					math.min(current.Y, maximum.Y)
				)
				base.Size = UDim2.fromOffset(clamped.X, clamped.Y)
				setSidebarRatio(sidebar.Size.X.Scale, clamped.X)
			end
		end)
	end

	return {
		base = base,
		baseCorner = baseCorner,
		baseStroke = baseStroke,
		clearButton = clearButton,
		dataBox = dataBox,
		etaLabel = etaLabel,
		groupFields = groupFields,
		groupNameBox = groupNameBox,
		groupToggle = groupToggle,
		groupXBox = groupXBox,
		groupYBox = groupYBox,
		groupZBox = groupZBox,
		importButton = importButton,
		importCancelButton = importCancelButton,
		importCard = importCard,
		importFileDropdown = importFileDropdown,
		importFileList = importFileList,
		importLoadButton = importLoadButton,
		importOverlay = importOverlay,
		importStatus = importStatus,
		maximizeButton = maximizeButton,
		nameBox = nameBox,
		perenesenoLabel = perenesenoLabel,
		previewCamera = previewCamera,
		previewRefresh = previewRefresh,
		previewStatus = previewStatus,
		previewViewport = previewViewport,
		progressFill = progressFill,
		removePrefabsButton = removePrefabsButton,
		progressNumbers = progressNumbers,
		progressPercent = progressPercent,
		resizeHandle = resizeHandle,
		setSidebarRatio = setSidebarRatio,
		sidebar = sidebar,
		startButton = startButton,
		statusLabel = statusLabel,
		worldBox = worldBox,
		worldStatus = worldStatus,
	}
end)()

local base = UI.base
local baseCorner = UI.baseCorner
local baseStroke = UI.baseStroke
local clearButton = UI.clearButton
local dataBox = UI.dataBox
local etaLabel = UI.etaLabel
local groupFields = UI.groupFields
local groupNameBox = UI.groupNameBox
local groupToggle = UI.groupToggle
local groupXBox = UI.groupXBox
local groupYBox = UI.groupYBox
local groupZBox = UI.groupZBox
local importButton = UI.importButton
local importCancelButton = UI.importCancelButton
local importCard = UI.importCard
local importFileDropdown = UI.importFileDropdown
local importFileList = UI.importFileList
local importLoadButton = UI.importLoadButton
local importOverlay = UI.importOverlay
local importStatus = UI.importStatus
local maximizeButton = UI.maximizeButton
local nameBox = UI.nameBox
local perenesenoLabel = UI.perenesenoLabel
local previewCamera = UI.previewCamera
local previewRefresh = UI.previewRefresh
local previewStatus = UI.previewStatus
local previewViewport = UI.previewViewport
local progressFill = UI.progressFill
local progressNumbers = UI.progressNumbers
local progressPercent = UI.progressPercent
local removePrefabsButton = UI.removePrefabsButton
local resizeHandle = UI.resizeHandle
local setSidebarRatio = UI.setSidebarRatio
local sidebar = UI.sidebar
local startButton = UI.startButton
local statusLabel = UI.statusLabel
local worldBox = UI.worldBox
local worldStatus = UI.worldStatus

local isTransferring = false

setStatus = function(textValue, color, transparency)
	if destroyed then
		return
	end
	statusLabel.Text = textValue
	statusLabel.TextColor3 = color or Colors.text
	statusLabel.TextTransparency = transparency or 0
	progressFill.BackgroundColor3 = color or Colors.text
end


local expandRestorePosition
local expandRestoreSize
local expandTarget
local expandSearchAt = 0

local function setExpandedDecorations(state)
	baseCorner.CornerRadius = UDim.new(0, state and 0 or 10)
	baseStroke.Transparency = state and 1 or 0.9
	resizeHandle.Visible = not state
end

local function updateExpandedFrame()
	if destroyed or not expanded then
		return
	end
	local target = expandTarget
	if not target or not target.Parent then
		if tick() < expandSearchAt then
			return
		end
		expandSearchAt = tick() + 0.5
		target = findRgeFrame()
		expandTarget = target
	end
	if not target then
		return
	end
	local topLeftInset = GuiService:GetGuiInset()
	local visualPosition = target.AbsolutePosition + topLeftInset
	local visualSize = target.AbsoluteSize
	if visualSize.X < 1 or visualSize.Y < 1 then
		return
	end
	local desiredSize = UDim2.fromOffset(visualSize.X, visualSize.Y)
	local desiredPosition = UDim2.fromOffset(
		visualPosition.X + visualSize.X / 2,
		visualPosition.Y + visualSize.Y / 2
	)
	local sizeChanged = base.Size ~= desiredSize
	if sizeChanged then
		base.Size = desiredSize
	end
	if base.Position ~= desiredPosition then
		base.Position = desiredPosition
	end
	if sizeChanged then
		setSidebarRatio(sidebar.Size.X.Scale, visualSize.X)
	end
end

leaveExpanded = function(restoreGeometry)
	if not expanded then
		return
	end
	expanded = false
	if expandConnection then
		expandConnection:Disconnect()
		expandConnection = nil
	end
	expandTarget = nil
	setExpandedDecorations(false)
	if restoreGeometry and expandRestorePosition and expandRestoreSize then
		base.Position = expandRestorePosition
		base.Size = expandRestoreSize
		setSidebarRatio(sidebar.Size.X.Scale, expandRestoreSize.X.Offset)
	end
end

local function toggleMaximize()
	if destroyed then
		return
	end
	if expanded then
		leaveExpanded(true)
		return
	end
	local target = findRgeFrame()
	if not target then
		setStatus("ФРЕЙМ RGE НЕ НАЙДЕН", Colors.danger, 0)
		return
	end
	expandRestorePosition = base.Position
	expandRestoreSize = base.Size
	expandTarget = target
	expanded = true
	setExpandedDecorations(true)
	updateExpandedFrame()
	if expandConnection then
		expandConnection:Disconnect()
	end
	expandConnection = RunService.RenderStepped:Connect(updateExpandedFrame)
end

maximizeButton.MouseButton1Click:Connect(toggleMaximize)

local function setProgress(current, total)
	if destroyed then
		return
	end
	local ratio = total > 0 and math.clamp(current / total, 0, 1) or 0
	progressFill.Size = UDim2.fromScale(ratio, 1)
	progressPercent.Text = tostring(math.floor(ratio * 100)) .. "%"
	progressNumbers.Text = tostring(current) .. " / " .. tostring(total)
	perenesenoLabel.Text = "Перенесено объектов: " .. tostring(current) .. "/" .. tostring(total)
end

local function formatDuration(seconds)
	local total = math.max(0, math.floor((seconds or 0) + 0.5))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d ч. %d мин. %d сек.", hours, minutes, secs)
	end
	if minutes > 0 then
		return string.format("%d мин. %d сек.", minutes, secs)
	end
	return string.format("%d сек.", secs)
end

local function setEta(seconds)
	if destroyed then
		return
	end
	etaLabel.Text = "Примерное время ожидания: " .. formatDuration(seconds)
end

local function resetProgress()
	setProgress(0, 0)
	setEta(0)
end

local function setBusy(busy)
	if destroyed then
		return
	end
	isTransferring = busy
	startButton.Active = not busy
	startButton.Text = busy and "ПЕРЕНОС..." or "Начать перенос"
	startButton.BackgroundColor3 = busy and Color3.fromRGB(165, 165, 165) or Color3.fromRGB(245, 245, 245)
	startButton.TextTransparency = busy and 0.35 or 0
end

local function updateWorldStatus()
	if destroyed then
		return
	end
	local world = tonumber(worldBox.Text)
	if world then
		worldStatus.Text = "World: " .. tostring(math.floor(world))
	else
		worldStatus.Text = "World: —"
	end
end

worldBox:GetPropertyChangedSignal("Text"):Connect(updateWorldStatus)
updateWorldStatus()
setProgress(0, 0)
setStatus("Ожидание данных", Colors.text, 0.45)
print("S2R++ v1392.1: free build, preview + S2R import + grouping + prefabs")
warn("===DONT CLOSE CONSOLE===")

local function trimText(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isPrefabEntry(info)
	if type(info) ~= "table" or type(info[1]) ~= "string" then
		return false
	end
	local kind = string.lower(info[1])
	return kind == "prefab" or kind == "prop"
end

local function vectorComponents(value)
	if value == nil then
		return nil
	end
	local ok, x, y, z = pcall(function()
		return value.X, value.Y, value.Z
	end)
	if ok and type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return x, y, z
	end
	return nil
end

local function colorComponents(value)
	if value == nil then
		return nil
	end
	local ok, r, g, b = pcall(function()
		return value.R, value.G, value.B
	end)
	if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
	return nil
end

local function getEntryPosition(info)
	if type(info) ~= "table" then
		return nil
	end
	return isPrefabEntry(info) and info[3] or info[2]
end

local function getEntryRotation(info)
	if type(info) ~= "table" then
		return nil
	end
	return isPrefabEntry(info) and info[4] or info[3]
end

local function validateTransferEntry(info, index)
	if type(info) ~= "table" then
		return false, "НЕКОРРЕКТНАЯ ЗАПИСЬ #" .. tostring(index)
	end
	if isPrefabEntry(info) then
		local name = info[2]
		if type(name) ~= "string" or trimText(name) == "" then
			return false, "ПРЕФАБ #" .. tostring(index) .. ": УКАЖИТЕ ИМЯ"
		end
		if not vectorComponents(info[3]) then
			return false, "ПРЕФАБ #" .. tostring(index) .. ": НЕВЕРНАЯ ПОЗИЦИЯ"
		end
		if not vectorComponents(info[4]) then
			return false, "ПРЕФАБ #" .. tostring(index) .. ": НЕВЕРНЫЙ ПОВОРОТ"
		end
		if info[5] ~= nil and not colorComponents(info[5]) then
			return false, "ПРЕФАБ #" .. tostring(index) .. ": НЕВЕРНЫЙ ЦВЕТ"
		end
		if info[6] ~= nil and not vectorComponents(info[6]) then
			return false, "ПРЕФАБ #" .. tostring(index) .. ": НЕВЕРНЫЙ РАЗМЕР"
		end
		return true
	end

	if type(info[1]) ~= "string" or trimText(info[1]) == "" then
		return false, "ЗАПИСЬ #" .. tostring(index) .. ": НЕ УКАЗАН ТИП"
	end
	if not vectorComponents(info[2]) then
		return false, "ЗАПИСЬ #" .. tostring(index) .. ": НЕВЕРНАЯ ПОЗИЦИЯ"
	end
	if not vectorComponents(info[3]) then
		return false, "ЗАПИСЬ #" .. tostring(index) .. ": НЕВЕРНЫЙ ПОВОРОТ"
	end
	if not vectorComponents(info[4]) then
		return false, "ЗАПИСЬ #" .. tostring(index) .. ": НЕВЕРНЫЙ РАЗМЕР"
	end
	if info[5] ~= nil and not colorComponents(info[5]) then
		return false, "ЗАПИСЬ #" .. tostring(index) .. ": НЕВЕРНЫЙ ЦВЕТ"
	end
	return true
end

local function parseLuaTable(raw)
	local source = trimText(raw)
	source = source:gsub("^\239\187\191", "")
	if source == "" then
		return nil
	end
	if source:sub(1, 6) ~= "return" then
		source = "return " .. source
	end
	local success, result = pcall(function()
		return loadstring(source)()
	end)
	if success and type(result) == "table" then
		return result
	end
	return nil
end

local function updatePrefabControls()
	if destroyed then
		return 0
	end

	local prefabCount = 0
	local raw = dataBox.Text
	if trimText(raw) ~= "" then
		local data = parseLuaTable(raw)
		if data then
			for _, info in ipairs(data) do
				if isPrefabEntry(info) then
					prefabCount += 1
				end
			end
		end
	end

	if removePrefabsButton then
		removePrefabsButton.Visible = prefabCount > 0
		removePrefabsButton.Active = prefabCount > 0
	end
	if groupToggle then
		if prefabCount > 0 then
			groupToggle.setEnabled(false)
			groupToggle.setState(false)
			groupEnabled = false
			if groupFields then
				groupFields.Visible = false
			end
		else
			groupToggle.setEnabled(true)
		end
	end
	return prefabCount
end

local function serializeTransferValue(value, seen)
	local valueType = type(value)
	if valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "number" then
		return tostring(value)
	elseif valueType == "boolean" then
		return value and "true" or "false"
	elseif valueType == "nil" then
		return "nil"
	end

	-- В Roblox Vector3 и Color3 — это userdata, а не table. Проверяем их
	-- до отсечения не-table значений, иначе при удалении префабов все
	-- координаты и цвета превращаются в nil.
	local x, y, z = vectorComponents(value)
	if x then
		return string.format("Vector3.new(%s, %s, %s)", tostring(x), tostring(y), tostring(z))
	end

	local r, g, b = colorComponents(value)
	if r then
		-- Сохраняем именно те компоненты, которые были в таблице. RGE
		-- принимает цвет в шкале 0..255, поэтому Color3.new(156, 155, 159)
		-- нельзя переводить в fromRGB(255, 255, 255).
		return string.format(
			"Color3.new(%s, %s, %s)",
			tostring(r),
			tostring(g),
			tostring(b)
		)
	end

	if valueType ~= "table" then
		return nil
	end

	seen = seen or {}
	if seen[value] then
		return nil
	end
	seen[value] = true

	local parts = {}
	local maxIndex = 0
	local hasMap = false
	for key in pairs(value) do
		if type(key) == "number" and key >= 1 and key % 1 == 0 then
			if key > maxIndex then
				maxIndex = key
			end
		else
			hasMap = true
		end
	end

	if hasMap then
		for key, item in pairs(value) do
			local encoded = serializeTransferValue(item, seen)
			if encoded then
				local keyText
				if type(key) == "number" then
					keyText = tostring(key)
				else
					keyText = "[" .. string.format("%q", tostring(key)) .. "]"
				end
				table.insert(parts, keyText .. " = " .. encoded)
			end
		end
	else
		for index = 1, maxIndex do
			local encoded = serializeTransferValue(value[index], seen)
			table.insert(parts, encoded or "nil")
		end
	end

	seen[value] = nil
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function removePrefabEntries()
	if destroyed then
		return
	end

	local data = parseLuaTable(dataBox.Text)
	if not data then
		setStatus("НЕ УДАЛОСЬ РАЗОБРАТЬ ТАБЛИЦУ", Colors.danger, 0)
		return
	end

	local kept = {}
	local removed = 0
	for _, info in ipairs(data) do
		if isPrefabEntry(info) then
			removed += 1
		else
			table.insert(kept, info)
		end
	end

	if removed == 0 then
		setStatus("В ТАБЛИЦЕ НЕТ ПРЕФАБОВ", Colors.warning, 0)
		updatePrefabControls()
		return
	end

	if #kept == 0 then
		dataBox.Text = "{}"
	else
		local lines = {}
		for _, info in ipairs(kept) do
			local encoded = serializeTransferValue(info)
			if not encoded then
				setStatus("НЕ УДАЛОСЬ СЕРИАЛИЗОВАТЬ ТАБЛИЦУ", Colors.danger, 0)
				return
			end
			table.insert(lines, "\t" .. encoded)
		end
		dataBox.Text = "{\n" .. table.concat(lines, ",\n") .. "\n}"
	end

	updatePrefabControls()
	setStatus(string.format("Убрано префабов: %d", removed), Colors.success, 0)
end

updatePrefabControls()

local function findRgeInterface()
	local direct = PlayerGui:FindFirstChild("RGEInterface")
	if direct then
		return direct
	end
	for _, descendant in ipairs(PlayerGui:GetDescendants()) do
		if descendant.Name == "RGEInterface" then
			return descendant
		end
	end
	return nil
end

local function findDescendantByName(root, name)
	local target = string.lower(name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if string.lower(descendant.Name) == target then
			return descendant
		end
	end
	return nil
end

local function getRgeConsoleOutput()
	local interface = findRgeInterface()
	if not interface then
		return nil
	end

	local function isText(instance)
		return instance:IsA("TextLabel") or instance:IsA("TextBox")
	end

	local function countTextRows(container)
		local count = 0
		for _, child in ipairs(container:GetChildren()) do
			if isText(child) then
				count += 1
			else
				for _, descendant in ipairs(child:GetDescendants()) do
					if isText(descendant) then
						count += 1
						break
					end
				end
			end
		end
		return count
	end

	local function countNumeric(container)
		local count = 0
		for _, child in ipairs(container:GetChildren()) do
			if child.Name:match("^%d+$") then
				count += 1
			end
		end
		return count
	end

	-- В разных сборках RGE консоль лежит либо прямо в RGEInterface,
	-- либо в RGEInterface.Frame...Content.Output. Ищем по всему дереву,
	-- но выбираем только контейнеры, действительно похожие на Output.
	local function scoreOutput(candidate)
		if not candidate or not candidate:IsA("GuiObject") then
			return -1
		end
		local numeric = countNumeric(candidate)
		local rows = countTextRows(candidate)
		local score = numeric * 10 + rows
		if numeric >= 10 then
			score += 100
		end
		if string.lower(candidate.Name) == "output" then
			score += 50
		end
		if candidate:IsA("ScrollingFrame") then
			score += 20
		end
		if isGuiChainVisible(candidate) then
			score += 30
		end
		return score
	end

	local best = nil
	local bestScore = -1
	for _, descendant in ipairs(interface:GetDescendants()) do
		if string.lower(descendant.Name) == "output"
			and (descendant:IsA("ScrollingFrame") or descendant:IsA("Frame"))
		then
			local score = scoreOutput(descendant)
			if score > bestScore then
				best = descendant
				bestScore = score
			end
		end
	end
	if best then
		return best
	end

	-- Последний вариант: контейнер с 20 нумерованными строками.
	best = nil
	bestScore = 0
	for _, descendant in ipairs(interface:GetDescendants()) do
		if descendant:IsA("ScrollingFrame") or descendant:IsA("Frame") then
			local numeric = countNumeric(descendant)
			if numeric >= 10 then
				local score = scoreOutput(descendant)
				if score > bestScore then
					best = descendant
					bestScore = score
				end
			end
		end
	end
	return best
end

local S2R_SIGNATURE_TEXT = "[made by mstbek] S2R++ Initialized"
local S2R_SIGNATURE_COLOR = Color3.fromRGB(97, 123, 244)
local S2R_CONSOLE_WARNING_TEXT = "===DONT CLOSE CONSOLE==="
local consoleTransferActive = false

local function isConsoleOutputVisible(output)
	if not output or not output.Parent then
		return false
	end
	local visibleOk, visible = pcall(function()
		return isGuiChainVisible(output)
	end)
	if not visibleOk or not visible then
		return false
	end
	local sizeOk, size = pcall(function()
		return output.AbsoluteSize
	end)
	if not sizeOk or not size then
		return false
	end
	return size.X > 1 and size.Y > 1
end

local function findConsoleTextLabel(row)
	if row:IsA("TextLabel") or row:IsA("TextBox") then
		return row
	end
	for _, descendant in ipairs(row:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
			return descendant
		end
	end
	return nil
end

local function applyConsoleSignatureStyle(row, text, color, visible)
	text = text or (consoleTransferActive and S2R_CONSOLE_WARNING_TEXT or S2R_SIGNATURE_TEXT)
	color = color or (consoleTransferActive and Colors.warning or S2R_SIGNATURE_COLOR)
	row.Name = "21"
	if row:IsA("GuiObject") then
		pcall(function()
			row.Visible = visible ~= false
			row.LayoutOrder = 21
		end)
	end
	local label = findConsoleTextLabel(row)
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Font = Enum.Font.Code
		label.TextSize = 14
		label.Parent = row
	end
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	if label:IsA("TextBox") then
		pcall(function()
			label.TextEditable = false
		end)
	end
end

local function installConsoleSignature()
	local function isConsoleRow(instance)
		if not instance:IsA("GuiObject") then
			return false
		end
		return instance:IsA("TextLabel") or instance:IsA("TextBox") or findConsoleTextLabel(instance) ~= nil
	end

	local function findConsoleTemplate(output)
		local numericBest = nil
		local numericOrder = -math.huge
		local layoutBest = nil
		local layoutOrder = -math.huge
		local fallback = nil

		for _, child in ipairs(output:GetChildren()) do
			if child.Name ~= "21" and isConsoleRow(child) then
				fallback = child
				local order = tonumber(child.Name)
				if order then
					if order > numericOrder then
						numericBest = child
						numericOrder = order
					end
				elseif child.LayoutOrder > layoutOrder then
					layoutBest = child
					layoutOrder = child.LayoutOrder
				end
			end
		end

		return numericBest or layoutBest or fallback
	end

	local function updateConsoleCanvas(output)
		local target = output
		if not target:IsA("ScrollingFrame") then
			local ancestor = target.Parent
			while ancestor and ancestor ~= PlayerGui do
				if ancestor:IsA("ScrollingFrame") then
					target = ancestor
					break
				end
				ancestor = ancestor.Parent
			end
		end
		if not target:IsA("ScrollingFrame") then
			return
		end

		local height = 0
		local layout = target:FindFirstChildOfClass("UIListLayout")
		if layout then
			local ok, contentSize = pcall(function()
				return layout.AbsoluteContentSize
			end)
			if ok and contentSize then
				height = contentSize.Y
			end
		end
		if height <= 0 then
			for _, child in ipairs(target:GetChildren()) do
				if child:IsA("GuiObject") then
					height = math.max(height, child.Position.Y.Offset + child.AbsoluteSize.Y)
				end
			end
		end
		if height > 0 then
			pcall(function()
				target.CanvasSize = UDim2.fromOffset(0, height + 8)
			end)
		end
	end

	local output = getRgeConsoleOutput()
	if not output then
		return false
	end

	local existing = output:FindFirstChild("21")
	if existing then
		if isConsoleRow(existing) then
			applyConsoleSignatureStyle(existing, nil, nil, isConsoleOutputVisible(output))
			updateConsoleCanvas(output)
			return true
		end
		pcall(function()
			existing:Destroy()
		end)
	end

	local template = findConsoleTemplate(output)
	if not template and #output:GetChildren() == 0 then
		return false
	end

	local row = nil
	if template then
		local ok, cloned = pcall(function()
			return template:Clone()
		end)
		if ok and cloned then
			row = cloned
		end
	end
	if not row then
		row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 18)
		row.Font = Enum.Font.Code
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Center
	end

	row.Name = "21"
	if row:IsA("GuiObject") then
		pcall(function()
			row.Visible = true
			row.LayoutOrder = 21
		end)
	end
	row.Parent = output

	if not template and row:IsA("GuiObject") then
		local bottom = 0
		for _, child in ipairs(output:GetChildren()) do
			if child ~= row and child:IsA("GuiObject") then
				bottom = math.max(bottom, child.Position.Y.Offset + child.AbsoluteSize.Y)
			end
		end
		pcall(function()
			row.Position = UDim2.fromOffset(0, bottom)
		end)
	end

	local listLayout = output:FindFirstChildOfClass("UIListLayout")
	if not listLayout and row:IsA("GuiObject") and template then
		local rowHeight = template.AbsoluteSize.Y
		local templateSize = template.Size
		if type(rowHeight) ~= "number" or rowHeight <= 0 then
			rowHeight = templateSize and templateSize.Y.Offset or 18
		end
		if type(rowHeight) ~= "number" or rowHeight <= 0 then
			rowHeight = 18
		end
		local templatePosition = template.Position
		if templatePosition then
			pcall(function()
				row.Position = UDim2.fromOffset(templatePosition.X.Offset, templatePosition.Y.Offset + rowHeight)
			end)
		end
	end

	applyConsoleSignatureStyle(row, nil, nil, isConsoleOutputVisible(output))
	updateConsoleCanvas(output)
	return true
end

local function readRgeConsoleLine(output, index)
	if not output then
		return ""
	end
	local line = output:FindFirstChild(tostring(index))
	if not line then
		return ""
	end
	if line:IsA("TextLabel") or line:IsA("TextBox") then
		return tostring(line.Text or "")
	end
	for _, descendant in ipairs(line:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
			return tostring(descendant.Text or "")
		end
	end
	return ""
end

local function reportRgeConsoleTail()
	local output = getRgeConsoleOutput()
	if not output then
		warn("S2R RGE console: not found")
		return
	end
	local lines = {}
	for index = 18, 20 do
		local text = readRgeConsoleLine(output, index)
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		if text ~= "" then
			table.insert(lines, text)
		end
	end
	if #lines > 0 then
		warn("S2R RGE console: " .. table.concat(lines, " | "))
	else
		warn("S2R RGE console: empty")
	end
end

local function tryInstallConsoleSignature()
	if destroyed then
		return false
	end
	local ok, installed = pcall(installConsoleSignature)
	return ok and installed
end

local function setConsoleTransferState(active)
	consoleTransferActive = active == true
	tryInstallConsoleSignature()
end

task.spawn(function()
	for _ = 1, 80 do
		if destroyed then
			return
		end
		if tryInstallConsoleSignature() then
			return
		end
		task.wait(0.25)
	end
end)

local consoleCheckAt = 0
if RunService and RunService.Heartbeat then
	consoleWatchdogConnection = RunService.Heartbeat:Connect(function()
		if destroyed or not base.Parent then
			if consoleWatchdogConnection then
				consoleWatchdogConnection:Disconnect()
				consoleWatchdogConnection = nil
			end
			return
		end
		local now = tick()
		if now - consoleCheckAt < 1 then
			return
		end
		consoleCheckAt = now
		tryInstallConsoleSignature()
	end)
end

local fireSignal = getExecutorFunction("firesignal") or getExecutorFunction("fireSignal")

local function sendRgeCommand(targetBox, command)
	pcall(function()
		targetBox:CaptureFocus()
	end)
	targetBox.Text = command
	pcall(function()
		targetBox.CursorPosition = #command + 1
	end)
	task.wait(0.03)

	local submitted = false
	if type(fireSignal) == "function" then
		local ok = pcall(fireSignal, targetBox.FocusLost, true)
		submitted = ok
	end
	if not submitted then
		pcall(function()
			targetBox:ReleaseFocus(true)
		end)
	end
	task.wait(0.08)
	return submitted
end

local function getRgeRoot()
	local rge = workspace:FindFirstChild("__RGE")
	if rge then
		return rge
	end
	local replicated = game:GetService("ReplicatedStorage")
	return replicated:FindFirstChild("__RGE")
end

local function getRgeWorldFolder(world)
	local rge = getRgeRoot()
	if not rge then
		return nil
	end
	local direct = rge:FindFirstChild(tostring(world))
	if direct then
		return direct
	end
	for _, child in ipairs(rge:GetChildren()) do
		local numericName = child.Name:match("(%d+)$")
		if numericName and tonumber(numericName) == world then
			return child
		end
	end
	return nil
end

local function getRgeWorldParts(world)
	local worldFolder = getRgeWorldFolder(world)
	if not worldFolder then
		return nil
	end
	return worldFolder:FindFirstChild("Parts")
end

local function normalizeUid(value)
	if type(value) == "string" then
		local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" then
			return trimmed
		end
	elseif type(value) == "number" then
		return tostring(value)
	end
	return nil
end

local function getObjectUid(instance)
	local ok, value = pcall(function()
		return instance:GetAttribute("UID")
	end)
	if ok then
		local uid = normalizeUid(value)
		if uid then
			return uid
		end
	end

	local okAttributes, attributes = pcall(function()
		return instance:GetAttributes()
	end)
	if okAttributes and type(attributes) == "table" then
		for key, attributeValue in pairs(attributes) do
			if type(key) == "string" and string.lower(key) == "uid" then
				local uid = normalizeUid(attributeValue)
				if uid then
					return uid
				end
			end
		end
	end

	local uidChild = instance:FindFirstChild("UID")
	if uidChild then
		local okValue, childValue = pcall(function()
			return uidChild.Value
		end)
		if okValue then
			local uid = normalizeUid(childValue)
			if uid then
				return uid
			end
		end
	end
	return nil
end

-- Снимок состояния мира: ссылки на объекты + их UID.
-- Ссылки позволяют найти новые объекты даже если UID ещё не появился/не читается.
local function snapshotState(world)
	local state = {
		world = world,
		worldFolder = getRgeWorldFolder(world),
		parts = nil,
		refs = {},
		uids = {},
		count = 0,
		nextDeepScan = 0,
	}
	state.parts = state.worldFolder and state.worldFolder:FindFirstChild("Parts")

	local function remember(instance)
		state.refs[instance] = true
		local uid = getObjectUid(instance)
		if uid then
			state.uids[uid] = true
		end
	end

	if state.parts then
		for _, child in ipairs(state.parts:GetChildren()) do
			remember(child)
			state.count += 1
		end
	end
	if state.worldFolder then
		for _, child in ipairs(state.worldFolder:GetChildren()) do
			if child ~= state.parts and child.Name ~= "Triggers" then
				remember(child)
			end
		end
	end
	return state
end

local function isNewInstance(instance, state, sameContainer)
	if state.refs[instance] then
		return false
	end
	local uid = getObjectUid(instance)
	if uid and state.uids[uid] then
		return false
	end
	if uid then
		return true
	end
	return sameContainer
end

local function collectNewFromParts(state)
	local objects = {}
	local parts = getRgeWorldParts(state.world)
	if not parts then
		return objects
	end
	local sameContainer = parts == state.parts
	for _, child in ipairs(parts:GetChildren()) do
		if isNewInstance(child, state, sameContainer) then
			table.insert(objects, child)
		end
	end
	return objects
end

local function collectNewDeep(state)
	local objects = {}
	local worldFolder = getRgeWorldFolder(state.world)
	if not worldFolder then
		return objects
	end
	local parts = worldFolder:FindFirstChild("Parts")
	local sameContainer = worldFolder == state.worldFolder
	for _, child in ipairs(worldFolder:GetChildren()) do
		if child ~= parts and child.Name ~= "Triggers" and isNewInstance(child, state, sameContainer) then
			table.insert(objects, child)
		end
	end
	return objects
end

local function collectNewObjects(state, expected)
	local objects = {}
	local seenRefs = {}
	local seenUids = {}
	local function add(instance)
		if seenRefs[instance] then
			return
		end
		local uid = getObjectUid(instance)
		if uid and seenUids[uid] then
			return
		end
		seenRefs[instance] = true
		if uid then
			seenUids[uid] = true
		end
		table.insert(objects, instance)
	end

	local function addExpanded(instance)
		if getObjectUid(instance) then
			add(instance)
			return
		end
		local ok, descendants = pcall(function()
			return instance:GetDescendants()
		end)
		if not ok then
			return
		end
		for _, descendant in ipairs(descendants) do
			if getObjectUid(descendant) then
				add(descendant)
			end
		end
	end

	for _, object in ipairs(collectNewFromParts(state)) do
		addExpanded(object)
	end

	if expected and #objects < expected and tick() >= (state.nextDeepScan or 0) then
		state.nextDeepScan = tick() + 1
		for _, object in ipairs(collectNewDeep(state)) do
			addExpanded(object)
		end
	end
	return objects
end

local function describeInstance(instance)
	local parts = {}
	local ok, attributes = pcall(function()
		return instance:GetAttributes()
	end)
	if ok and type(attributes) == "table" then
		for key, value in pairs(attributes) do
			table.insert(parts, tostring(key) .. "=" .. tostring(value))
		end
	end
	table.sort(parts)
	return string.format("%s '%s' [%s]", instance.ClassName, instance.Name, table.concat(parts, ", "))
end

local function reportCreationFailure(state, expected, created)
	local parts = getRgeWorldParts(state.world)
	local rge = getRgeRoot()
	local worldFolder = getRgeWorldFolder(state.world)
	warn(string.format(
		"S2R group debug: worldId=%d __RGE=%s worldFolder=%s parts=%s baselineChildren=%d currentChildren=%d detected=%d expected=%d",
		state.world,
		tostring(rge ~= nil),
		tostring(worldFolder ~= nil),
		tostring(parts ~= nil),
		state.count or 0,
		parts and #parts:GetChildren() or 0,
		#created,
		expected
	))
	if rge then
		local names = {}
		for _, child in ipairs(rge:GetChildren()) do
			table.insert(names, child.Name)
		end
		warn("S2R __RGE children: " .. table.concat(names, ", "))
	end
	if parts then
		local raw = {}
		for _, child in ipairs(parts:GetChildren()) do
			if not state.refs[child] then
				table.insert(raw, child)
			end
		end
		warn(string.format("S2R new children by reference: %d", #raw))
		for i = 1, math.min(#raw, 3) do
			warn("S2R new sample: " .. describeInstance(raw[i]))
		end
	end
	reportRgeConsoleTail()
end

local function waitForCreatedObjects(state, expected, timeout)
	local deadline = tick() + (timeout or 30)
	local objects = {}
	local lastReported = -1
	repeat
		objects = collectNewObjects(state, expected)
		if #objects ~= lastReported then
			lastReported = #objects
			setStatus(string.format("Ожидание создания объектов... %d/%d", #objects, expected), Colors.text, 0.2)
		end
		if #objects >= expected then
			return objects
		end
		task.wait(0.25)
	until tick() >= deadline
	return objects
end

local function containsCreatedUid(root, createdUids)
	local uid = getObjectUid(root)
	if uid and createdUids[uid] then
		return true
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		uid = getObjectUid(descendant)
		if uid and createdUids[uid] then
			return true
		end
	end
	return false
end

local function countCreatedUids(root, createdUids)
	local seen = {}
	local uid = getObjectUid(root)
	if uid and createdUids[uid] then
		seen[uid] = true
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		uid = getObjectUid(descendant)
		if uid and createdUids[uid] then
			seen[uid] = true
		end
	end
	local count = 0
	for _ in pairs(seen) do
		count += 1
	end
	return count
end

local function looksLikeGroup(instance)
	if not instance:IsA("Model") then
		return false
	end
	local ok, propName = pcall(function()
		return instance:GetAttribute("PropName")
	end)
	if ok and propName ~= nil then
		return false
	end
	return #instance:GetChildren() > 1
end

local function findGroupObject(state, createdUids, createdRoots)
	local worldFolder = getRgeWorldFolder(state.world)
	if not worldFolder then
		return nil
	end
	local parts = worldFolder:FindFirstChild("Parts")
	local sameWorld = worldFolder == state.worldFolder
	local function isCreatedRoot(instance)
		if createdRoots and createdRoots[instance] == true then
			return true
		end
		local ok, propName = pcall(function()
			return instance:GetAttribute("PropName")
		end)
		return ok and propName ~= nil
	end
	if parts then
		local sameParts = parts == state.parts
		for _, child in ipairs(parts:GetChildren()) do
			if not isCreatedRoot(child)
				and isNewInstance(child, state, sameParts)
				and child:IsA("Model")
				and containsCreatedUid(child, createdUids)
			then
				return child
			end
		end
		for _, child in ipairs(parts:GetChildren()) do
			if not isCreatedRoot(child) and isNewInstance(child, state, sameParts) and looksLikeGroup(child) then
				return child
			end
		end
	end
	for _, child in ipairs(worldFolder:GetChildren()) do
		if child ~= parts
			and child.Name ~= "Triggers"
			and not isCreatedRoot(child)
			and isNewInstance(child, state, sameWorld)
			and child:IsA("Model")
		then
			if containsCreatedUid(child, createdUids) or looksLikeGroup(child) then
				return child
			end
		end
	end
	return nil
end

local function waitForGroupObject(state, createdUids, createdRoots, timeout)
	local deadline = tick() + (timeout or 20)
	repeat
		local groupObject = findGroupObject(state, createdUids, createdRoots)
		if groupObject then
			return groupObject
		end
		task.wait(0.15)
	until tick() >= deadline
	return findGroupObject(state, createdUids, createdRoots)
end

local function waitForGroupName(groupObject, groupName, timeout)
	local deadline = tick() + (timeout or 4)
	repeat
		if groupObject.Parent and groupObject.Name == groupName then
			return true
		end
		task.wait(0.1)
	until tick() >= deadline
	return groupObject.Parent ~= nil and groupObject.Name == groupName
end

local function waitForGroupPosition(groupObject, targetX, targetY, targetZ, timeout)
	local target = Vector3.new(targetX, targetY, targetZ)
	local deadline = tick() + (timeout or 3)
	repeat
		local ok, pivot = pcall(function()
			return groupObject:GetPivot()
		end)
		if not ok or not pivot then
			return true
		end
		if (pivot.Position - target).Magnitude <= 2 then
			return true
		end
		task.wait(0.1)
	until tick() >= deadline
	return false
end

local function collectGroupUidList(created)
	local uids = {}
	local seen = {}
	local function add(uid)
		if uid and not seen[uid] then
			seen[uid] = true
			table.insert(uids, uid)
		end
	end
	for _, object in ipairs(created) do
		local uid = getObjectUid(object)
		if uid then
			add(uid)
		else
			local ok, descendants = pcall(function()
				return object:GetDescendants()
			end)
			if ok then
				for _, descendant in ipairs(descendants) do
					add(getObjectUid(descendant))
				end
			end
		end
	end
	return uids
end

local function getDataBounds(data)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local count = 0

	for _, info in ipairs(data or {}) do
		local x, y, z = vectorComponents(getEntryPosition(info))
		if x then
			count += 1
			minX, minY, minZ = math.min(minX, x), math.min(minY, y), math.min(minZ, z)
			maxX, maxY, maxZ = math.max(maxX, x), math.max(maxY, y), math.max(maxZ, z)
		end
	end

	if count == 0 then
		return nil
	end

	local dx, dy, dz = maxX - minX, maxY - minY, maxZ - minZ
	return {
		minX = minX,
		minY = minY,
		minZ = minZ,
		maxX = maxX,
		maxY = maxY,
		maxZ = maxZ,
		centerX = (minX + maxX) / 2,
		centerY = (minY + maxY) / 2,
		centerZ = (minZ + maxZ) / 2,
		diagonal = math.sqrt(dx * dx + dy * dy + dz * dz),
		count = count,
	}
end

local function getDataSpread(data)
	local bounds = getDataBounds(data)
	return bounds and bounds.diagonal or 0, bounds
end

local function findTeleportPosition(data, usedPositions, preferFar)
	local bounds = getDataBounds(data)
	if not bounds then
		return nil
	end

	local candidates = {}
	for index, info in ipairs(data or {}) do
		local x, y, z = vectorComponents(getEntryPosition(info))
		if x then
			local dx, dy, dz = x - bounds.centerX, y - bounds.centerY, z - bounds.centerZ
			candidates[#candidates + 1] = {
				x = x,
				y = y,
				z = z,
				index = index,
				distance = dx * dx + dy * dy + dz * dz,
			}
		end
	end

	local function pick(ignoreUsed)
		local best = nil
		local bestDistance = nil
		for _, candidate in ipairs(candidates) do
			if ignoreUsed or not (usedPositions and usedPositions[candidate.index]) then
				local better = not best
				if best then
					if preferFar then
						better = candidate.distance > bestDistance
					else
						better = candidate.distance < bestDistance
					end
				end
				if better then
					best = candidate
					bestDistance = candidate.distance
				end
			end
		end
		return best
	end

	local best = pick(false) or pick(true)
	if not best then
		return nil
	end
	return best.x, best.y, best.z, best.index
end

local function normalizedText(instance)
	local text = ""
	pcall(function()
		text = tostring(instance.Text or "")
	end)
	return text
end

local function isButton(instance)
	return instance:IsA("GuiButton") or instance:IsA("TextButton") or instance:IsA("ImageButton")
end

local function asGuiButton(instance, root)
	if isButton(instance) then
		return instance
	end
	local node = instance.Parent
	while node and node ~= root do
		if isButton(node) then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function findGuiButton(root, predicate)
	for _, node in ipairs(root:GetDescendants()) do
		if isButton(node) then
			local name = string.lower(node.Name)
			local text = string.lower(normalizedText(node))
			if predicate(node, name, text) then
				return node
			end
		end
	end
	return nil
end

local function getDefaultViewButton()
	local interface = findRgeInterface()
	if not interface then
		return nil
	end

	local function stationTarget(stations)
		if not stations then
			return nil
		end
		if isButton(stations) then
			return stations
		end
		local legacy = stations:FindFirstChild("1")
		if legacy then
			-- В реальном RGE станция — это ImageLabel/Frame с InputBegan,
			-- а не GuiButton. Возвращаем саму станцию, а не первого
			-- потомка-кнопку (ей может оказаться крестик удаления).
			local okGui, isGui = pcall(function()
				return legacy:IsA("GuiObject")
			end)
			if okGui and isGui then
				return legacy
			end
			local button = asGuiButton(legacy, interface)
			if button then
				return button
			end
			for _, descendant in ipairs(legacy:GetDescendants()) do
				if isButton(descendant) then
					return descendant
				end
			end
			return legacy
		end
		return nil
	end

	local function pageStations(page)
		if not page then
			return nil
		end
		local stations = page:FindFirstChild("Stations")
		if stations then
			return stations
		end
		for _, child in ipairs(page:GetChildren()) do
			if string.lower(child.Name) == "stations" then
				return child
			end
		end
		return nil
	end

	-- Точный путь из RGE: RGEInterface:GetChildren()[3].Stations["1"].
	-- Если эта станция на скрытой странице, клик по ней невозможен —
	-- тогда запоминаем её как запасной вариант и ищем видимую.
	local hiddenFallback = nil
	local children = interface:GetChildren()
	local exactTarget = stationTarget(pageStations(children[3]))
	if exactTarget then
		if isGuiChainVisible(exactTarget) then
			return exactTarget
		end
		hiddenFallback = exactTarget
	end

	local exact = interface:FindFirstChild("DefaultView") or findDescendantByName(interface, "DefaultView")
	if exact then
		local button = asGuiButton(exact, interface)
		if button then
			return button
		end
		for _, descendant in ipairs(exact:GetDescendants()) do
			if isButton(descendant) then
				return descendant
			end
		end
		return exact
	end

	-- Старый путь RGEInterface.Frame.Stations["1"].
	local frame = interface:FindFirstChild("Frame")
	local frameTarget = stationTarget(pageStations(frame))
	if frameTarget then
		return frameTarget
	end

	local byName = findGuiButton(interface, function(_, name)
		return name:gsub("%s+", ""):find("defaultview", 1, true) ~= nil
	end)
	if byName then
		return byName
	end

	local byText = findGuiButton(interface, function(_, _, text)
		return text:gsub("%s+", ""):find("defaultview", 1, true) ~= nil
	end)
	if byText then
		return byText
	end

	local byNameParts = findGuiButton(interface, function(_, name)
		return name:find("default", 1, true) ~= nil and name:find("view", 1, true) ~= nil
	end)
	if byNameParts then
		return byNameParts
	end

	local byTextParts = findGuiButton(interface, function(_, _, text)
		return text:find("default", 1, true) ~= nil and text:find("view", 1, true) ~= nil
	end)
	if byTextParts then
		return byTextParts
	end

	-- Панель Stations выбираем видимую: у RGE несколько страниц, и станция
	-- со скрытой страницы не кликается вообще.
	local stations = nil
	for _, node in ipairs(interface:GetDescendants()) do
		if string.lower(node.Name) == "stations" then
			local nodeVisible = isGuiChainVisible(node)
			local currentVisible = stations ~= nil and isGuiChainVisible(stations)
			if not stations or (nodeVisible and not currentVisible) then
				stations = node
			end
		end
	end
	local stationsTarget = stationTarget(stations)
	if stationsTarget then
		return stationsTarget
	end

	-- Иногда Default View — это TextLabel/Frame, а не GuiButton.
	for _, node in ipairs(interface:GetDescendants()) do
		if node:IsA("GuiObject") then
			local name = string.lower(node.Name)
			local text = string.lower(normalizedText(node))
			local compact = (name .. " " .. text):gsub("%s+", "")
			if compact:find("defaultview", 1, true)
				or (name:find("default", 1, true) and name:find("view", 1, true))
				or (text:find("default", 1, true) and text:find("view", 1, true))
			then
				local button = asGuiButton(node, interface)
				if button then
					return button
				end
				return node
			end
		end
	end
	return hiddenFallback
end

local function describeDefaultViewCandidates(interface)
	if not interface then
		return "RGEInterface не найден"
	end
	local stations = findDescendantByName(interface, "Stations")
	local parts = {}
	for _, node in ipairs(interface:GetDescendants()) do
		if node:IsA("GuiObject") then
			local text = normalizedText(node)
			local haystack = string.lower(node.Name .. " " .. text)
			local relevant = haystack:find("default", 1, true) or haystack:find("view", 1, true)
			if not relevant and stations and node.Name == "1" and node:IsDescendantOf(stations) then
				relevant = true
			end
			if relevant then
				table.insert(parts, node.Name .. " [" .. node.ClassName .. "] text=[" .. text .. "]")
				if #parts >= 8 then
					break
				end
			end
		end
	end
	if #parts == 0 then
		return "кандидатов default/view нет"
	end
	return table.concat(parts, " | ")
end

-- Точка в экранных координатах: виртуальная мышь (VirtualInputManager,
-- mousemove, GetMouseLocation) работает в координатах вьюпорта, а
-- AbsolutePosition — в GUI-координатах, которые у ScreenGui с
-- IgnoreGuiInset = false сдвинуты вниз на высоту топбара. Без этой поправки
-- клик уходит примерно на 36 px выше кнопки — ровно из-за этого
-- DefaultView и «не нажимался».
local function getGuiInsetPixels()
	local insetX, insetY = 0, 0
	pcall(function()
		local inset = GuiService:GetGuiInset()
		insetX = inset.X or 0
		insetY = inset.Y or 0
	end)
	return insetX, insetY
end

local function findScreenGuiAncestor(node)
	local current = node
	while current and current ~= PlayerGui do
		if current:IsA("ScreenGui") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function guiObjectsAtScreenPoint(x, y)
	local list = nil
	local ok = pcall(function()
		list = PlayerGui:GetGuiObjectsAtPosition(x, y)
	end)
	if ok and type(list) == "table" then
		return list
	end
	return nil
end

-- true/false — попали/не попали, nil — проверить нельзя (API недоступен).
local function screenPointHitsNode(node, x, y)
	local list = guiObjectsAtScreenPoint(x, y)
	if not list then
		return nil
	end
	for _, object in ipairs(list) do
		if object == node then
			return true
		end
		local ok, related = pcall(function()
			return object:IsDescendantOf(node) or node:IsDescendantOf(object)
		end)
		if ok and related then
			return true
		end
	end
	return false
end

local lastDefaultViewClickLog = ""

local function clickGuiButton(button)
	if not button then
		return false
	end

	local getConnections = getExecutorFunction("getconnections")
	local fireSignalFn = fireSignal or getExecutorFunction("firesignal") or getExecutorFunction("fireSignal")
	local virtualInputManager
	pcall(function()
		virtualInputManager = game:GetService("VirtualInputManager")
	end)
	local virtualUserService
	pcall(function()
		virtualUserService = game:GetService("VirtualUser")
	end)

	local function isGuiObject(node)
		if not node then
			return false
		end
		local ok, isGui = pcall(function()
			return node:IsA("GuiObject")
		end)
		return ok and isGui
	end

	local function nodeText(node)
		return string.lower(normalizedText(node))
	end

	local function isCloseLike(node)
		local name = string.lower(node.Name or "")
		local text = nodeText(node)
		local combined = name .. " " .. text
		if combined:find("close", 1, true)
			or combined:find("remove", 1, true)
			or combined:find("delete", 1, true)
			or combined:find("закры", 1, true)
			or combined:find("удал", 1, true)
		then
			return true
		end
		local compact = text:gsub("%s+", "")
		return compact == "x" or compact == "×" or compact == "✕" or compact == "✖"
	end

	local function isDefaultLike(node)
		local name = string.lower(node.Name or "")
		local text = nodeText(node)
		local compact = (name .. " " .. text):gsub("%s+", "")
		return compact:find("defaultview", 1, true) ~= nil
			or (name:find("default", 1, true) ~= nil and name:find("view", 1, true) ~= nil)
			or (text:find("default", 1, true) ~= nil and text:find("view", 1, true) ~= nil)
	end

	-- Собираем узлы вокруг станции: сама станция, default-подобные потомки,
	-- остальные потомки и пара предков. В RGE станция — это ImageLabel/Frame
	-- с InputBegan, поэтому важен каждый уровень.
	local nodes = {}
	local seen = {}
	local function addNode(node)
		if isGuiObject(node) and not seen[node] and not isCloseLike(node) then
			seen[node] = true
			table.insert(nodes, node)
		end
	end

	addNode(button)
	local preferred = {}
	local others = {}
	for _, descendant in ipairs(button:GetDescendants()) do
		if isGuiObject(descendant) and not isCloseLike(descendant) then
			if isDefaultLike(descendant) then
				table.insert(preferred, descendant)
			else
				table.insert(others, descendant)
			end
		end
	end
	for _, node in ipairs(preferred) do
		addNode(node)
	end
	for _, node in ipairs(others) do
		addNode(node)
	end
	local ancestor = button.Parent
	local depth = 0
	while isGuiObject(ancestor) and depth < 6 do
		addNode(ancestor)
		ancestor = ancestor.Parent
		depth += 1
	end
	if #nodes == 0 then
		return false
	end

	local function nodeVisible(node)
		local ok, visible = pcall(isGuiChainVisible, node)
		return ok and visible == true
	end

	local function nodeRect(node)
		local ok, position, size = pcall(function()
			return node.AbsolutePosition, node.AbsoluteSize
		end)
		if not ok or not position or not size then
			return nil
		end
		if type(position.X) ~= "number" or type(position.Y) ~= "number"
			or type(size.X) ~= "number" or type(size.Y) ~= "number"
			or size.X <= 1 or size.Y <= 1
		then
			return nil
		end
		return position, size
	end

	local function nodeInViewport(node)
		local position, size = nodeRect(node)
		if not position then
			return false
		end
		local viewport = Camera and Camera.ViewportSize
		if viewport and viewport.X > 0 and viewport.Y > 0 then
			if position.X + size.X < 0 or position.Y + size.Y < 0
				or position.X > viewport.X or position.Y > viewport.Y
			then
				return false
			end
		end
		return true
	end

	-- Станция на скрытой странице RGE не кликается: раньше такой «клик»
	-- проходил по чужим координатам и считался успешным.
	local visibleNodes = {}
	local visibleSet = {}
	for _, node in ipairs(nodes) do
		if nodeVisible(node) and nodeInViewport(node) then
			table.insert(visibleNodes, node)
			visibleSet[node] = true
		end
	end
	local fallbackNodes = {}
	for _, node in ipairs(nodes) do
		if not visibleSet[node] then
			table.insert(fallbackNodes, node)
		end
	end

	-- Варианты экранной точки: центр и смещения внутри станции.
	-- Координаты всегда считаются по правилу топбара (GUI + GuiInset для
	-- ScreenGui без IgnoreGuiInset) — сдвиг в другую сторону здесь недопустим,
	-- иначе клик снова уйдёт мимо кнопки.
	local function candidatePoints(node)
		local position, size = nodeRect(node)
		if not position then
			return {}
		end
		local insetX, insetY = getGuiInsetPixels()
		local screenGui = findScreenGuiAncestor(node)
		local ignoreInset = false
		if screenGui then
			local ok, value = pcall(function()
				return screenGui.IgnoreGuiInset
			end)
			ignoreInset = ok and value == true
		end
		local offsets = {
			{ 0.5, 0.5 },
			{ 0.3, 0.5 },
			{ 0.7, 0.5 },
			{ 0.5, 0.3 },
			{ 0.5, 0.7 },
		}
		local points = {}
		for _, offset in ipairs(offsets) do
			local guiX = position.X + size.X * offset[1]
			local guiY = position.Y + size.Y * offset[2]
			if ignoreInset then
				table.insert(points, { guiX, guiY, guiX, guiY })
			else
				table.insert(points, { guiX + insetX, guiY + insetY, guiX, guiY })
			end
		end
		return points
	end

	local function pickScreenPoint(node)
		local points = candidatePoints(node)
		if #points == 0 then
			return nil
		end
		-- Если точка перекрыта другим GUI, пробуем смещения внутри станции.
		for _, point in ipairs(points) do
			if screenPointHitsNode(node, point[1], point[2]) == true then
				return point[1], point[2], point[3], point[4]
			end
		end
		local point = points[1]
		return point[1], point[2], point[3], point[4]
	end

	local function overlapsS2RWindow(x, y)
		if not base or not base.Visible then
			return false
		end
		local ok, position, size = pcall(function()
			return base.AbsolutePosition, base.AbsoluteSize
		end)
		if not ok or not position or not size then
			return false
		end
		return x >= position.X and x <= position.X + size.X
			and y >= position.Y and y <= position.Y + size.Y
	end

	-- Следим за UserInputService: если событие дошло, клик действительно
	-- отправлен, а не «принят» заглушкой экзекутора.
	local function watchMouseDelivered(fn)
		local delivered = false
		local connection = nil
		pcall(function()
			connection = UserInputService.InputBegan:Connect(function(input)
				local ok, inputType = pcall(function()
					return input.UserInputType
				end)
				if ok and inputType == Enum.UserInputType.MouseButton1 then
					delivered = true
				end
			end)
		end)
		local ok, pressed = pcall(fn)
		task.wait(0.08)
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
		return ok and pressed == true, delivered
	end

	local function pressVirtualInput(x, y)
		local vim = virtualInputManager
		if not vim then
			return false
		end
		if type(vim.SendMouseMoveEvent) == "function" then
			if not pcall(vim.SendMouseMoveEvent, vim, x, y, game) then
				pcall(vim.SendMouseMoveEvent, vim, x, y)
			end
			task.wait(0.02)
		end
		if type(vim.SendMouseButtonEvent) ~= "function" then
			return false
		end
		local down = pcall(vim.SendMouseButtonEvent, vim, x, y, 0, true, game, 1)
		if not down then
			down = pcall(vim.SendMouseButtonEvent, vim, x, y, 0, true, game)
		end
		if not down then
			return false
		end
		task.wait(0.05)
		if not pcall(vim.SendMouseButtonEvent, vim, x, y, 0, false, game, 1) then
			pcall(vim.SendMouseButtonEvent, vim, x, y, 0, false, game)
		end
		return true
	end

	local function pressVirtualUser(x, y)
		if not virtualUserService then
			return false
		end
		local position = Vector2.new(x, y)
		pcall(function()
			virtualUserService:CaptureController()
		end)
		if type(virtualUserService.MoveMouse) == "function" then
			pcall(function()
				virtualUserService:MoveMouse(position)
			end)
		end
		if type(virtualUserService.Button1Down) ~= "function" then
			return false
		end
		if not pcall(function()
			virtualUserService:Button1Down(position)
		end) then
			return false
		end
		task.wait(0.05)
		pcall(function()
			virtualUserService:Button1Up(position)
		end)
		return true
	end

	local function pressUserInputService(x, y)
		local send = UserInputService.SendMouseButtonEvent
		if type(send) ~= "function" then
			return false
		end
		if not pcall(send, UserInputService, x, y, 0, true, game, 1) then
			return false
		end
		task.wait(0.05)
		pcall(send, UserInputService, x, y, 0, false, game, 1)
		return true
	end

	local moveAbsolute = getExecutorFunction("mousemoveabs")
		or getExecutorFunction("mousemove")
		or getExecutorFunction("MouseMove")
	local moveRelative = getExecutorFunction("mousemoverel")
	local clickFn = getExecutorFunction("mouse1click")
		or getExecutorFunction("mouseclick")
		or getExecutorFunction("click")
	local pressFn = getExecutorFunction("mouse1press")
	local releaseFn = getExecutorFunction("mouse1release")

	local function pressExecutorMouse(x, y)
		if moveRelative then
			local currentX, currentY = x, y
			pcall(function()
				local current = UserInputService:GetMouseLocation()
				if current then
					currentX, currentY = current.X, current.Y
				end
			end)
			if not pcall(moveRelative, x - currentX, y - currentY) then
				return false
			end
		elseif moveAbsolute then
			if not pcall(moveAbsolute, x, y) then
				return false
			end
		else
			return false
		end
		task.wait(0.04)
		if clickFn then
			if pcall(clickFn) then
				return true
			end
			return pcall(clickFn, x, y)
		end
		if pressFn and releaseFn then
			if not pcall(pressFn) then
				return false
			end
			task.wait(0.05)
			pcall(releaseFn)
			return true
		end
		return false
	end

	local strategyLog = {}
	local nativeStrategies = {
		{ name = "VirtualInputManager", run = pressVirtualInput },
		{ name = "VirtualUser", run = pressVirtualUser },
		{ name = "UserInputService", run = pressUserInputService },
		{ name = "executor-mouse", run = pressExecutorMouse },
	}

	-- 1. Настоящий клик мышью: RGE обработает его так же, как клик игрока.
	local target = nil
	local screenX, screenY, guiX, guiY = nil, nil, nil, nil
	for _, node in ipairs(visibleNodes) do
		local pointX, pointY, nodeGuiX, nodeGuiY = pickScreenPoint(node)
		if pointX then
			target = node
			screenX, screenY, guiX, guiY = pointX, pointY, nodeGuiX, nodeGuiY
			break
		end
	end

	if target and screenX then
		local restoreVisible = nil
		if overlapsS2RWindow(guiX, guiY) then
			restoreVisible = base.Visible
			base.Visible = false
			task.wait(0.06)
		end
		local delivered = false
		for _, strategy in ipairs(nativeStrategies) do
			local pressed, gotInput = watchMouseDelivered(function()
				return strategy.run(screenX, screenY)
			end)
			table.insert(strategyLog, string.format(
				"%s(%s pressed=%s input=%s)",
				strategy.name,
				tostring(target.Name),
				tostring(pressed),
				tostring(gotInput)
			))
			if gotInput then
				delivered = true
				break
			end
		end
		if restoreVisible ~= nil then
			base.Visible = restoreVisible
		end
		if delivered then
			return true
		end
	end

	-- 2. Прямой вызов обработчиков: станции RGE — ImageLabel/Frame с
	-- InputBegan. Здесь важен UserInputState (а не InputState) и Target:
	-- без них обработчик RGE выходит на первой же проверке.
	local function fakeInput(x, y, state, inputTarget)
		local position = Vector3.new(x or 0, y or 0, 0)
		return {
			UserInputType = Enum.UserInputType.MouseButton1,
			UserInputState = state,
			InputState = state,
			KeyCode = Enum.KeyCode.Unknown,
			Position = position,
			Delta = Vector3.new(0, 0, 0),
			Target = inputTarget,
		}
	end

	local function callConnection(connection, args)
		if not connection then
			return false
		end
		local fire
		pcall(function()
			fire = connection.Fire
		end)
		if type(fire) == "function" then
			if pcall(fire, connection, table.unpack(args)) then
				return true
			end
			if pcall(fire, table.unpack(args)) then
				return true
			end
		end
		local callback
		pcall(function()
			callback = connection.Function
		end)
		if type(callback) ~= "function" then
			pcall(function()
				callback = connection.Callback
			end)
		end
		if type(callback) == "function" and pcall(callback, table.unpack(args)) then
			return true
		end
		return false
	end

	-- "fired" — обработчик точно выполнился, "sent" — сигнал отправлен, но
	-- проверить слушателей нельзя (нет getconnections), false — не вышло.
	local function trySignal(signal, args)
		if not signal then
			return false
		end
		if type(getConnections) == "function" then
			local ok, connections = pcall(getConnections, signal)
			if ok and type(connections) == "table" then
				local count = 0
				for _ in pairs(connections) do
					count += 1
				end
				-- Нет подключений — не считаем firesignal успешным кликом.
				if count == 0 then
					return false
				end
				for _, connection in ipairs(connections) do
					if callConnection(connection, args) then
						return "fired"
					end
				end
				for key, connection in pairs(connections) do
					if type(key) ~= "number" and callConnection(connection, args) then
						return "fired"
					end
				end
				return false
			end
		end
		if type(fireSignalFn) == "function" then
			if pcall(fireSignalFn, signal, table.unpack(args)) then
				return "sent"
			end
		end
		return false
	end

	local signalTargets = {}
	for _, node in ipairs(visibleNodes) do
		table.insert(signalTargets, node)
	end
	for _, node in ipairs(fallbackNodes) do
		table.insert(signalTargets, node)
	end

	-- Станции RGE — ImageLabel/Frame с InputBegan, поэтому для них сначала
	-- пробуем InputBegan, а для настоящих кнопок — MouseButton1Click.
	local function buildSignalAttempts(node, pointX, pointY)
		local beginInput = fakeInput(pointX or 0, pointY or 0, Enum.UserInputState.Begin, node)
		local endInput = fakeInput(pointX or 0, pointY or 0, Enum.UserInputState.End, node)
		local inputAttempts = {
			{ "InputBegan", { beginInput } },
			{ "InputEnded", { endInput } },
		}
		local buttonAttempts = {
			{ "MouseButton1Click", {} },
			{ "Activated", { beginInput } },
			{ "MouseButton1Down", { pointX or 0, pointY or 0 } },
			{ "MouseButton1Up", { pointX or 0, pointY or 0 } },
		}
		local attempts = {}
		if isButton(node) then
			for _, attempt in ipairs(buttonAttempts) do
				table.insert(attempts, attempt)
			end
			for _, attempt in ipairs(inputAttempts) do
				table.insert(attempts, attempt)
			end
		else
			for _, attempt in ipairs(inputAttempts) do
				table.insert(attempts, attempt)
			end
			for _, attempt in ipairs(buttonAttempts) do
				table.insert(attempts, attempt)
			end
		end
		return attempts
	end

	for _, node in ipairs(signalTargets) do
		local pointX, pointY = pickScreenPoint(node)
		pcall(function()
			if node.Active ~= nil then
				node.Active = true
			end
			if node.Selectable ~= nil then
				node.Selectable = true
			end
		end)
		local sentUnverified = false
		for _, attempt in ipairs(buildSignalAttempts(node, pointX, pointY)) do
			local signalOk, signal = pcall(function()
				return node[attempt[1]]
			end)
			if signalOk and signal then
				local result = trySignal(signal, attempt[2])
				if result == "fired" then
					warn(string.format(
						"S2R: DefaultView нажат через %s (%s) — реальная мышь недоступна",
						attempt[1],
						tostring(node.Name)
					))
					return true
				elseif result == "sent" then
					sentUnverified = true
				end
			end
		end
		if sentUnverified then
			warn("S2R: DefaultView вызван через firesignal без проверки слушателей")
			return true
		end
	end

	-- 3. Последний шанс: станции, которые слушают ввод на уровне UIS.
	do
		local firstNode = visibleNodes[1] or signalTargets[1]
		if firstNode then
			local pointX, pointY = pickScreenPoint(firstNode)
			if pointX then
				local beginInput = fakeInput(pointX, pointY, Enum.UserInputState.Begin, firstNode)
				local endInput = fakeInput(pointX, pointY, Enum.UserInputState.End, firstNode)
				-- gameProcessedEvent = true: обработчики игры, которые не
				-- относятся к RGE, не должны реагировать на синтетический клик.
				if trySignal(UserInputService.InputBegan, { beginInput, true }) then
					trySignal(UserInputService.InputEnded, { endInput, true })
					return true
				end
			end
		end
	end

	table.insert(strategyLog, "сигналы: обработчик не выполнился")
	lastDefaultViewClickLog = table.concat(strategyLog, "; ")
	return false
end

local function activateRgeDefaultView(timeout)
	local deadline = tick() + (timeout or 5)
	local lastButton
	local clickAttempts = 0
	while tick() < deadline do
		local ok, button = pcall(getDefaultViewButton)
		if ok and button then
			lastButton = button
			-- Каждый клик — это несколько попыток синтетического ввода,
			-- поэтому не повторяем бесконечно.
			if clickAttempts >= 3 then
				break
			end
			clickAttempts += 1
			if clickGuiButton(button) then
				return true
			end
			task.wait(0.25)
		end
		task.wait(0.1)
	end

	local okInterface, interface = pcall(findRgeInterface)
	local candidates = "RGEInterface недоступен"
	if okInterface then
		local okDescribe, description = pcall(describeDefaultViewCandidates, interface)
		if okDescribe then
			candidates = description
		end
	end
	local target = "цель не найдена"
	if lastButton then
		local okPath, path = pcall(instancePath, lastButton)
		target = (okPath and path or tostring(lastButton.Name)) .. " [" .. tostring(lastButton.ClassName) .. "]"
	end
	local detail = ""
	if lastDefaultViewClickLog ~= "" then
		detail = " Клик: " .. lastDefaultViewClickLog .. "."
	end
	warn("S2R: кнопка DefaultView не найдена или не активирована. Цель: " .. target .. ". " .. candidates .. detail)
	return false
end

local function teleportToTransferredPart(targetBox, data, usedPositions, preferFar)
	local x, y, z, index = findTeleportPosition(data, usedPositions, preferFar)
	if not x then
		return false
	end
	if usedPositions and index then
		usedPositions[index] = true
	end

	setStatus("Телепортация к постройке...", Colors.text, 0.2)
	sendRgeCommand(targetBox, string.format(
		"teleport player %s %.3f %.3f %.3f",
		LocalPlayer.Name,
		x,
		y,
		z
	))
	task.wait(0.6)

	activateRgeDefaultView(5)

	-- Даём удалённым частям прогрузиться и попасть в Parts до детекции.
	task.wait(1.6)
	return true
end

local GROUP_SPREAD_WARN_DISTANCE = 300
local GROUP_TELEPORT_RETRY_LIMIT = 3

local function showGroupTeleportPrompt(titleText, messageText, confirmText, cancelText)
	if destroyed then
		return false
	end
	local root = base.Parent
	if not root then
		return false
	end

	local overlay = make("Frame", {
		Name = "GroupTeleportPrompt",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 120,
	}, root)
	addCorner(overlay, 10)

	local card = make("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 248),
		BackgroundColor3 = Color3.fromRGB(17, 17, 17),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 121,
	}, overlay)
	addCorner(card, 10)
	addStroke(card, 0.9)

	local title = newLabel(card, titleText, 18, 0.08, Enum.FontWeight.SemiBold)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(24, 22)
	title.Size = UDim2.new(1, -48, 0, 24)
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.ZIndex = 122

	local message = newLabel(card, messageText, 13, 0.22, Enum.FontWeight.Regular)
	message.Name = "Message"
	message.Position = UDim2.fromOffset(24, 58)
	message.Size = UDim2.new(1, -48, 0, 108)
	message.TextWrapped = true
	message.TextYAlignment = Enum.TextYAlignment.Top
	message.ZIndex = 122

	local confirm = make("TextButton", {
		Name = "Confirm",
		Position = UDim2.fromOffset(24, 186),
		Size = UDim2.new(0.5, -30, 0, 38),
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Text = confirmText or "Телепорт",
		TextColor3 = Colors.primaryText,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.SemiBold),
		AutoButtonColor = false,
		ZIndex = 122,
	}, card)
	addCorner(confirm, 6)

	local cancel = make("TextButton", {
		Name = "Cancel",
		Position = UDim2.new(0.5, 6, 0, 186),
		Size = UDim2.new(0.5, -30, 0, 38),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Text = cancelText or "Отмена",
		TextColor3 = Colors.text,
		TextTransparency = 0.3,
		TextSize = 13,
		FontFace = interFont(Enum.FontWeight.Medium),
		AutoButtonColor = false,
		ZIndex = 122,
	}, card)
	addCorner(cancel, 6)
	addStroke(cancel, 0.9)

	confirm.MouseEnter:Connect(function()
		tween(confirm, 0.18, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end)
	confirm.MouseLeave:Connect(function()
		tween(confirm, 0.18, { BackgroundColor3 = Color3.fromRGB(245, 245, 245) }):Play()
	end)
	cancel.MouseEnter:Connect(function()
		tween(cancel, 0.18, { BackgroundTransparency = 0.86, TextTransparency = 0.1 }):Play()
	end)
	cancel.MouseLeave:Connect(function()
		tween(cancel, 0.18, { BackgroundTransparency = 0.94, TextTransparency = 0.3 }):Play()
	end)

	local choice = nil
	local function finish(value)
		if choice == nil then
			choice = value
		end
	end

	confirm.MouseButton1Click:Connect(function()
		finish(true)
	end)
	cancel.MouseButton1Click:Connect(function()
		finish(false)
	end)
	pcall(function()
		overlay.AncestryChanged:Connect(function(_, parent)
			if not parent then
				finish(false)
			end
		end)
	end)

	local deadline = tick() + 120
	while choice == nil and not destroyed and overlay.Parent and tick() < deadline do
		task.wait(0.05)
	end

	if overlay.Parent then
		overlay:Destroy()
	end
	return choice == true
end

local PREVIEW_LIMIT = 300
local PREFAB_PREVIEW_SIZE = Vector3.new(2, 2, 2)

local function buildPreview()
	if destroyed or not previewViewport or not previewStatus then
		return
	end

	-- ViewportFrame/CFrame недоступны в некоторых средах — не ломаем панель.
	local hasSpatial = pcall(function()
		local point = Vector3.new(0, 0, 0)
		return CFrame.new(point)
	end)
	if not hasSpatial then
		return
	end

	for _, child in ipairs(previewViewport:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end

	local raw = dataBox.Text
	if trimText(raw) == "" then
		previewStatus.Text = "Нет данных"
		return
	end

	local data = parseLuaTable(raw)
	if not data then
		previewStatus.Text = "Ошибка в Lua-таблице"
		return
	end

	local total = #data
	if total == 0 then
		previewStatus.Text = "Таблица пуста"
		return
	end

	local entries = {}
	local prefabCount = 0
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for i = 1, math.min(total, PREVIEW_LIMIT) do
		local info = data[i]
		if type(info) == "table" then
			local isPrefab = isPrefabEntry(info)
			local px, py, pz = vectorComponents(getEntryPosition(info))
			local sx, sy, sz
			if isPrefab then
				sx, sy, sz = vectorComponents(info[6])
				if not sx then
					sx, sy, sz = PREFAB_PREVIEW_SIZE.X, PREFAB_PREVIEW_SIZE.Y, PREFAB_PREVIEW_SIZE.Z
				end
			else
				sx, sy, sz = vectorComponents(info[4])
			end
			if px and sx then
				sx = math.max(0.05, math.min(tonumber(sx) or 1, 500))
				sy = math.max(0.05, math.min(tonumber(sy) or 1, 500))
				sz = math.max(0.05, math.min(tonumber(sz) or 1, 500))

				local rx, ry, rz = vectorComponents(getEntryRotation(info))
				rx, ry, rz = tonumber(rx) or 0, tonumber(ry) or 0, tonumber(rz) or 0

				local color = info[5]
				if not colorComponents(color) then
					if isPrefab then
						color = Color3.fromRGB(115, 170, 255)
					else
						color = Color3.fromRGB(155, 155, 155)
					end
				end

				table.insert(entries, {
					shape = tostring(info[1] or "part"),
					isPrefab = isPrefab,
					position = Vector3.new(px, py, pz),
					rotation = Vector3.new(rx, ry, rz),
					size = Vector3.new(sx, sy, sz),
					color = color,
					material = isPrefab and nil or info[6],
				})
				if isPrefab then
					prefabCount += 1
				end

				minX = math.min(minX, px - sx / 2)
				minY = math.min(minY, py - sy / 2)
				minZ = math.min(minZ, pz - sz / 2)
				maxX = math.max(maxX, px + sx / 2)
				maxY = math.max(maxY, py + sy / 2)
				maxZ = math.max(maxZ, pz + sz / 2)
			end
		end
	end

	if #entries == 0 then
		previewStatus.Text = "Нет корректных объектов"
		return
	end

	local center = Vector3.new(
		(minX + maxX) / 2,
		(minY + maxY) / 2,
		(minZ + maxZ) / 2
	)

	local model = Instance.new("Model")
	model.Name = "PreviewModel"
	model.Parent = previewViewport

	for _, entry in ipairs(entries) do
		local lowerShape = string.lower(entry.shape)
		local part
		if lowerShape:find("corner", 1, true) and lowerShape:find("wedge", 1, true) then
			part = Instance.new("CornerWedgePart")
		elseif lowerShape:find("wedge", 1, true) then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if lowerShape:find("ball", 1, true) or lowerShape:find("sphere", 1, true) then
				part.Shape = Enum.PartType.Ball
			elseif lowerShape:find("cylinder", 1, true) then
				part.Shape = Enum.PartType.Cylinder
			end
		end

		part.Name = "PreviewPart"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Size = entry.size
		part.Transparency = entry.isPrefab and 0.12 or 0
		part.Color = Color3.fromRGB(155, 155, 155)
		pcall(function()
			part.Color = entry.color
		end)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(entry.position - center) * CFrame.Angles(
			math.rad(entry.rotation.X),
			math.rad(entry.rotation.Y),
			math.rad(entry.rotation.Z)
		)
		if type(entry.material) == "string" and entry.material ~= "" then
			pcall(function()
				part.Material = Enum.Material[entry.material]
			end)
		end
		part.Parent = model
	end

	local extent = math.max(maxX - minX, maxY - minY, maxZ - minZ, 1)
	local boxOk, boxCFrame, boxSize = pcall(function()
		return model:GetBoundingBox()
	end)
	if boxOk and boxCFrame and boxSize then
		local boxExtent = math.max(boxSize.X, boxSize.Y, boxSize.Z, 1)
		extent = math.max(extent, boxExtent)
		center = boxCFrame.Position
	end

	local distance = extent * 2.2 + 6
	local cameraPosition = center + Vector3.new(1, 0.85, 1).Unit * distance
	if previewCamera then
		previewCamera.FieldOfView = 30
		previewCamera.CFrame = CFrame.lookAt(cameraPosition, center)
		previewViewport.CurrentCamera = previewCamera
	end

	local statusText
	if total > #entries then
		statusText = string.format("Показано %d из %d", #entries, total)
	else
		statusText = string.format("Объектов: %d", total)
	end
	if prefabCount > 0 then
		statusText = statusText .. string.format(", префабов: %d", prefabCount)
	end
	previewStatus.Text = statusText
end

local previewRequest = 0
local function schedulePreview()
	previewRequest += 1
	local request = previewRequest
	task.delay(0.45, function()
		if destroyed or request ~= previewRequest then
			return
		end
		local ok, err = pcall(buildPreview)
		if not ok then
			warn("S2R preview error: " .. tostring(err))
			if previewStatus then
				previewStatus.Text = "Ошибка предпросмотра"
			end
		end
	end)
end

dataBox:GetPropertyChangedSignal("Text"):Connect(function()
	schedulePreview()
	updatePrefabControls()
end)
previewRefresh.MouseButton1Click:Connect(function()
	if destroyed then
		return
	end
	local ok, err = pcall(buildPreview)
	if not ok then
		warn("S2R preview error: " .. tostring(err))
		previewStatus.Text = "Ошибка предпросмотра"
	end
end)
removePrefabsButton.MouseButton1Click:Connect(function()
	if destroyed then
		return
	end
	if isTransferring then
		setStatus("ДОЖДИТЕСЬ ЗАВЕРШЕНИЯ ПЕРЕНОСА", Colors.warning, 0)
		return
	end
	removePrefabEntries()
end)
task.delay(0.3, schedulePreview)

local function startBuilding(data, fileName, world, options)
	options = options or {}
	local total = #data
	setProgress(0, total)
	setEta(0)
	if total == 0 then
		error("ТАБЛИЦА ПУСТА", 0)
	end

	local targetBox = getRgeCommandLine()
	if not targetBox then
		error("КОМАНДНАЯ СТРОКА RGE НЕ НАЙДЕНА", 0)
	end

	local groupInfo = options.group
	if groupInfo then
		for _, info in ipairs(data) do
			if isPrefabEntry(info) then
				error("ПРЕФАБЫ НЕЛЬЗЯ ГРУППИРОВАТЬ", 0)
			end
		end
	end
	local baseline = nil
	if groupInfo then
		baseline = snapshotState(world)
	end

	local startTime = tick()
	setStatus("Ввод команд в RGE...", Colors.text, 0.2)
	pcall(function()
		targetBox:CaptureFocus()
	end)
	task.wait(0.1)
	warn(string.format(
		"S2R submit: backend=%s commandBar=%s focused=%s",
		type(fireSignal) == "function" and "firesignal" or "ReleaseFocus",
		instancePath(targetBox),
		tostring(isTextBoxFocused(targetBox))
	))

	local partCount, prefabCount = 0, 0

	for i, info in ipairs(data) do
		if destroyed then
			return
		end
		if type(info) ~= "table" then
			error("НЕКОРРЕКТНАЯ ЗАПИСЬ #" .. i, 0)
		end

		local commands
		if isPrefabEntry(info) then
			local propName = info[2]
			local position = info[3]
			local rotation = info[4]
			if type(propName) ~= "string" or trimText(propName) == "" then
				error("ПРЕФАБ #" .. i .. ": УКАЖИТЕ ИМЯ", 0)
			end
			if not vectorComponents(position) then
				error("ПРЕФАБ #" .. i .. ": НЕВЕРНАЯ ПОЗИЦИЯ", 0)
			end
			if not vectorComponents(rotation) then
				error("ПРЕФАБ #" .. i .. ": НЕВЕРНЫЙ ПОВОРОТ", 0)
			end

			commands = {
				string.format(
					"spawn %d %s %.3f %.3f %.3f %.3f %.3f %.3f",
					world,
					propName,
					position.X,
					position.Y,
					position.Z,
					rotation.X,
					rotation.Y,
					rotation.Z
				),
			}

			local prefabSizeX, prefabSizeY, prefabSizeZ = vectorComponents(info[6])
			if prefabSizeX then
				table.insert(commands, string.format(
					"size %d %% %.3f %.3f %.3f",
					world,
					prefabSizeX,
					prefabSizeY,
					prefabSizeZ
				))
			end

			local color = info[5]
			local r, g, b = colorComponents(color)
			if colorEnabled and r then
				table.insert(commands, string.format(
					"color %d %% %d %d %d",
					world,
					math.floor(r),
					math.floor(g),
					math.floor(b)
				))
			end
			prefabCount += 1
		else
			local shape, position, rotation, size, color, material = info[1], info[2], info[3], info[4], info[5], info[6]
			if not vectorComponents(position) or not vectorComponents(rotation) or not vectorComponents(size) then
				error("НЕКОРРЕКТНАЯ ЗАПИСЬ #" .. i, 0)
			end

			commands = {
				string.format("create %d %s %.3f %.3f %.3f", world, shape, position.X, position.Y, position.Z),
				string.format("move %d %% %.3f %.3f %.3f %.3f %.3f %.3f", world, position.X, position.Y, position.Z, rotation.X, rotation.Y, rotation.Z),
				string.format("size %d %% %.3f %.3f %.3f", world, size.X, size.Y, size.Z),
			}

			local r, g, b = colorComponents(color)
			if colorEnabled and r then
				table.insert(commands, string.format(
					"color %d %% %d %d %d",
					world,
					math.floor(r),
					math.floor(g),
					math.floor(b)
				))
			end

			if materialEnabled and material then
				table.insert(commands, string.format("material %d %% %s", world, material))
			end
			partCount += 1
		end

		for commandIndex, command in ipairs(commands) do
			if destroyed then
				return
			end
			sendRgeCommand(targetBox, command)
			if i == 1 and commandIndex == 1 then
				warn("S2R first command: " .. command:sub(1, 200))
				task.wait(0.2)
				reportRgeConsoleTail()
			end
		end

		if i % 2 == 0 or i == total then
			local elapsed = tick() - startTime
			local estimate = (elapsed / i) * (total - i)
			setProgress(i, total)
			setEta(estimate)
		end
	end

	if destroyed then
		return
	end

	-- Удалённые части не попадают в Parts, пока чанк не прогружен.
	-- Телепортируемся к постройке и включаем DefaultView до детекции/группировки.
	local teleportUsed = {}
	teleportToTransferredPart(targetBox, data, teleportUsed, false)

	local groupObject = nil
	if groupInfo and baseline then
		-- Если части постройки разнесены далеко, предлагаем телепорт к другой части:
		-- это помогает RGE прогрузить все объекты в Parts.
		local spread = getDataSpread(data)
		if spread >= GROUP_SPREAD_WARN_DISTANCE then
			local accepted = showGroupTeleportPrompt(
				"Большое расстояние между частями",
				string.format(
					"Части постройки разнесены примерно на %.0f studs. Это может помешать прогрузке всех объектов в Parts.\n\nТелепортироваться к другой части постройки и включить DefaultView?",
					spread
				),
				"Телепорт к другой части",
				"Продолжить"
			)
			if accepted and not destroyed then
				teleportToTransferredPart(targetBox, data, teleportUsed, true)
			end
		end
		if destroyed then
			return
		end

		setEta(0)
		setStatus("Ожидание создания объектов...", Colors.text, 0.2)
		local created = waitForCreatedObjects(baseline, total, 30)
		local retries = 0
		while #created < total and retries < GROUP_TELEPORT_RETRY_LIMIT and not destroyed do
			local accepted = showGroupTeleportPrompt(
				"Не все объекты прогрузились",
				string.format(
					"Найдено %d из %d объектов. Части постройки могут быть слишком далеко друг от друга.\n\nТелепортироваться к другой части и повторить проверку?",
					#created,
					total
				),
				"Телепорт и повторить",
				"Отмена"
			)
			if not accepted or destroyed then
				break
			end
			retries += 1
			teleportToTransferredPart(targetBox, data, teleportUsed, true)
			setStatus("Ожидание создания объектов...", Colors.text, 0.2)
			created = waitForCreatedObjects(baseline, total, 30)
		end
		if #created < total then
			reportCreationFailure(baseline, total, created)
			error(string.format("СОЗДАНО %d ИЗ %d ОБЪЕКТОВ", #created, total), 0)
		end

		local uidList = collectGroupUidList(created)
		local createdUids = {}
		local createdRoots = {}
		for _, object in ipairs(created) do
			createdRoots[object] = true
		end
		for _, uid in ipairs(uidList) do
			createdUids[uid] = true
		end
		if #uidList == 0 then
			reportCreationFailure(baseline, total, created)
			error("НЕ УДАЛОСЬ ОПРЕДЕЛИТЬ UID ОБЪЕКТОВ", 0)
		end
		if #uidList < total then
			warn(string.format("S2R: UID найдено %d из %d", #uidList, total))
		end

		setStatus("Группировка объектов...", Colors.text, 0.2)
		local beforeGroup = snapshotState(world)
		local groupCommand = string.format("group %d %s", world, table.concat(uidList, " "))
		warn(string.format("S2R: group command length=%d, uids=%d", #groupCommand, #uidList))
		sendRgeCommand(targetBox, groupCommand)
		groupObject = waitForGroupObject(beforeGroup, createdUids, createdRoots, 20)
		if not groupObject then
			warn("S2R group debug: group model not found after command")
			reportRgeConsoleTail()
			error("ГРУППА НЕ СОЗДАНА", 0)
		end

		local groupedCount = countCreatedUids(groupObject, createdUids)
		if groupedCount == 0 then
			warn("S2R: в группе не найдены UID созданных объектов (возможно, RGE пересоздал их)")
		elseif groupedCount < #uidList then
			warn(string.format("S2R: в группе %d из %d объектов", groupedCount, #uidList))
		end

		local groupUid = getObjectUid(groupObject)

		setStatus("Переименование группы...", Colors.text, 0.2)
		local renamed = false
		if groupUid then
			sendRgeCommand(targetBox, string.format("rename %d %s %s", world, groupUid, groupInfo.name))
			renamed = waitForGroupName(groupObject, groupInfo.name, 4)
		end
		if not renamed then
			sendRgeCommand(targetBox, string.format("rename %d %% %s", world, groupInfo.name))
			renamed = waitForGroupName(groupObject, groupInfo.name, 4)
		end
		if not renamed then
			reportRgeConsoleTail()
			error("НЕ УДАЛОСЬ ПЕРЕИМЕНОВАТЬ ГРУППУ", 0)
		end

		setStatus("Позиционирование группы...", Colors.text, 0.2)
		sendRgeCommand(targetBox, string.format(
			"move %d %%%s %.3f %.3f %.3f 0 0 0",
			world,
			groupInfo.name,
			groupInfo.x,
			groupInfo.y,
			groupInfo.z
		))
		local moved = waitForGroupPosition(groupObject, groupInfo.x, groupInfo.y, groupInfo.z, 3)
		if not moved and groupUid then
			sendRgeCommand(targetBox, string.format(
				"move %d %s %.3f %.3f %.3f 0 0 0",
				world,
				groupUid,
				groupInfo.x,
				groupInfo.y,
				groupInfo.z
			))
			moved = waitForGroupPosition(groupObject, groupInfo.x, groupInfo.y, groupInfo.z, 5)
		end
		if not moved then
			warn("S2R: группа не подтвердила позицию после move")
			reportRgeConsoleTail()
		end
	end

	if destroyed then
		return
	end

	if options.save then
		sendRgeCommand(targetBox, "file save " .. fileName)
	end
	setProgress(total, total)
	setEta(0)

	local statusParts = {}
	if prefabCount > 0 then
		table.insert(statusParts, string.format("Партов: %d, Префабов: %d", partCount, prefabCount))
	end
	if groupInfo then
		table.insert(statusParts, "Группа: " .. groupInfo.name)
	end
	if options.save then
		table.insert(statusParts, "Файл: " .. fileName)
	end
	if #statusParts > 0 then
		setStatus("ГОТОВО! " .. table.concat(statusParts, ", "), Colors.success, 0)
	else
		setStatus("ГОТОВО! Перенос завершён", Colors.success, 0)
	end
end

local function beginTransfer(data, fileName, world, options)
	setBusy(true)
	setConsoleTransferState(true)
	task.spawn(function()
		local success, err = pcall(startBuilding, data, fileName, world, options)
		setConsoleTransferState(false)
		if not success then
			warn("S2R transfer error: " .. tostring(err))
			setStatus("ОШИБКА: " .. tostring(err), Colors.danger, 0)
		end
		setBusy(false)
	end)
end

startButton.MouseButton1Click:Connect(function()
	if destroyed or isTransferring then
		return
	end

	local rawData = dataBox.Text
	local fileName = trimText(nameBox.Text)
	local worldNumber = tonumber(worldBox.Text)

	if not worldNumber or worldNumber < 1 or worldNumber % 1 ~= 0 then
		resetProgress()
		setStatus("УКАЖИТЕ НОМЕР: 1, 3, 15", Colors.danger, 0)
		return
	end
	worldNumber = math.floor(worldNumber)

	if saveFileEnabled and fileName == "" then
		fileName = nameBox.PlaceholderText
	end

	if trimText(rawData) == "" or (saveFileEnabled and fileName == "") then
		resetProgress()
		setStatus("ЗАПОЛНИТЕ ВСЕ ПОЛЯ", Colors.danger, 0)
		return
	end

	local groupInfo = nil
	if groupEnabled then
		local groupName = trimText(groupNameBox.Text)
		if groupName == "" then
			resetProgress()
			setStatus("УКАЖИТЕ НАЗВАНИЕ МОДЕЛИ", Colors.danger, 0)
			return
		end
		if groupName:find("%s") or groupName:find("%%") then
			resetProgress()
			setStatus("НАЗВАНИЕ: БЕЗ ПРОБЕЛОВ И СИМВОЛА %", Colors.danger, 0)
			return
		end
		local worldParts = getRgeWorldParts(worldNumber)
		if worldParts then
			for _, child in ipairs(worldParts:GetChildren()) do
				if child.Name == groupName then
					resetProgress()
					setStatus("МОДЕЛЬ С ТАКИМ ИМЕНЕМ УЖЕ ЕСТЬ", Colors.danger, 0)
					return
				end
			end
		end
		local px = tonumber(trimText(groupXBox.Text))
		local py = tonumber(trimText(groupYBox.Text))
		local pz = tonumber(trimText(groupZBox.Text))
		if not px or not py or not pz then
			resetProgress()
			setStatus("УКАЖИТЕ КООРДИНАТЫ pX, pY, pZ", Colors.danger, 0)
			return
		end
		groupInfo = { name = groupName, x = px, y = py, z = pz }
	end

	local result = parseLuaTable(rawData)

	if result and groupInfo then
		local hasPrefab = false
		for _, info in ipairs(result) do
			if isPrefabEntry(info) then
				hasPrefab = true
				break
			end
		end
		if hasPrefab then
			resetProgress()
			updatePrefabControls()
			setStatus("ПРЕФАБЫ НЕЛЬЗЯ ГРУППИРОВАТЬ", Colors.danger, 0)
			return
		end
	end

	if result then
		local valid = true
		for index, info in ipairs(result) do
			local entryOk, validationError = validateTransferEntry(info, index)
			if not entryOk then
				valid = false
				warn("S2R validation: " .. tostring(validationError))
				resetProgress()
				setStatus(validationError, Colors.danger, 0)
				break
			end
		end
		if valid then
			beginTransfer(result, fileName, worldNumber, {
				save = saveFileEnabled,
				group = groupInfo,
			})
		end
	else
		warn("Ошибка парсинга таблицы")
		resetProgress()
		setStatus("ОШИБКА В ДАННЫХ", Colors.danger, 0)
	end
end)

clearButton.MouseButton1Click:Connect(function()
	if destroyed then
		return
	end
	if isTransferring then
		setStatus("ДОЖДИТЕСЬ ЗАВЕРШЕНИЯ ПЕРЕНОСА", Colors.warning, 0)
		return
	end
	dataBox.Text = ""
	resetProgress()
	setStatus("Таблица очищена", Colors.text, 0.45)
end)

local IMPORT_FOLDER = "S2R"
-- Studio не умеет сохранять .txt из плагина: диалог «Сохранить выбор» пишет
-- скрипт как .luau (или .lua), иногда с именем вида RGE_Table.txt.luau.
-- Поэтому принимаем все эти варианты — содержимое у них одинаковое.
local IMPORT_EXTENSIONS = { ".txt", ".lua", ".luau" }

local function isImportFileName(lowerName)
	if string.find(lowerName, ".txt", 1, true) then
		return true
	end
	for _, extension in ipairs(IMPORT_EXTENSIONS) do
		if string.sub(lowerName, -#extension) == extension then
			return true
		end
	end
	return false
end

local importFiles = {}
local importSelectedPath = nil
local importSelectedName = nil
local importDropdownOpen = false

local function setImportStatus(textValue, color)
	if not importStatus then
		return
	end
	importStatus.Text = textValue or ""
	importStatus.TextColor3 = color or Colors.muted
end

local function ensureImportFolder()
	local makefolder = getExecutorFunction("makefolder")
	if type(makefolder) == "function" then
		pcall(makefolder, IMPORT_FOLDER)
		return true
	end
	return false
end

local function readImportFiles()
	local listfiles = getExecutorFunction("listfiles")
	if type(listfiles) ~= "function" then
		return nil, "listfiles недоступен в этом executor"
	end

	local ok, entries = pcall(listfiles, IMPORT_FOLDER)
	if not ok then
		return nil, "Не удалось прочитать папку S2R: " .. tostring(entries)
	end
	if type(entries) ~= "table" then
		return nil, "Папка S2R вернула неверный список файлов"
	end

	local files = {}
	for _, entry in ipairs(entries) do
		local path = tostring(entry)
		local normalized = path:gsub("\\", "/")
		local lower = string.lower(normalized)
		local folderLower = string.lower(IMPORT_FOLDER)
		local isBare = not normalized:find("/", 1, true)
		local inFolder = isBare
			or lower:sub(1, #folderLower + 1) == folderLower .. "/"
			or lower:find("/" .. folderLower .. "/", 1, true) ~= nil
		if inFolder and isImportFileName(lower) then
			local name = normalized:match("([^/]+)$") or normalized
			local fullPath = path
			if isBare then
				fullPath = IMPORT_FOLDER .. "/" .. path
			end
			table.insert(files, { name = name, path = fullPath })
		end
	end
	table.sort(files, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return files
end

local function updateFileDropdownText()
	if importSelectedName then
		importFileDropdown.Text = importSelectedName
	else
		importFileDropdown.Text = "Выберите .txt / .luau файл"
	end
end

local function setImportDropdownOpen(state)
	if state and #importFiles == 0 then
		state = false
	end
	importDropdownOpen = state
	importFileList.Visible = state

	local statusY = state and 226 or 120
	local buttonsY = state and 257 or 151
	local cardHeight = state and 316 or 222

	importStatus.Position = UDim2.fromOffset(24, statusY)
	importLoadButton.Position = UDim2.fromOffset(24, buttonsY)
	importCancelButton.Position = UDim2.new(0.5, 6, 0, buttonsY)
	importCard.Size = UDim2.fromOffset(460, cardHeight)

	if state then
		pcall(function()
			importFileList.CanvasPosition = Vector2.new(0, 0)
		end)
	end
end

local function clearFileOptions()
	for _, child in ipairs(importFileList:GetChildren()) do
		if child.Name == "FileOption" or child.Name == "FileEmpty" then
			child:Destroy()
		end
	end
end

local function createFileOption(file, order)
	local option = make("TextButton", {
		Name = "FileOption",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Colors.text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = file.name,
		TextColor3 = Colors.text,
		TextTransparency = 0.25,
		TextSize = 12,
		FontFace = interFont(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = false,
		LayoutOrder = order,
		ZIndex = 54,
	}, importFileList)
	addCorner(option, 4)
	addPadding(option, 8, 8, 0, 0)

	option.MouseEnter:Connect(function()
		tween(option, 0.12, { BackgroundTransparency = 0.9, TextTransparency = 0.05 }):Play()
	end)
	option.MouseLeave:Connect(function()
		tween(option, 0.12, { BackgroundTransparency = 1, TextTransparency = 0.25 }):Play()
	end)
	option.MouseButton1Click:Connect(function()
		importSelectedPath = file.path
		importSelectedName = file.name
		updateFileDropdownText()
		setImportDropdownOpen(false)
		setImportStatus("Выбран файл: " .. file.name, Colors.success)
	end)
end

local function refreshImportFiles()
	local files, err = readImportFiles()
	clearFileOptions()

	if not files then
		importFiles = {}
		importSelectedPath = nil
		importSelectedName = nil
		updateFileDropdownText()
		setImportDropdownOpen(false)
		setImportStatus(err, Colors.danger)
		return
	end

	importFiles = files
	local stillExists = false
	for _, file in ipairs(files) do
		if file.path == importSelectedPath then
			stillExists = true
			importSelectedName = file.name
			break
		end
	end
	if not stillExists then
		importSelectedPath = nil
		importSelectedName = nil
	end

	if not importSelectedPath and #files > 0 then
		importSelectedPath = files[1].path
		importSelectedName = files[1].name
	end
	updateFileDropdownText()

	if #files == 0 then
		local empty = newLabel(importFileList, "В папке S2R нет .txt / .luau файлов", 11, 0.5)
		empty.Name = "FileEmpty"
		empty.Size = UDim2.new(1, 0, 0, 26)
		empty.ZIndex = 54
		setImportStatus("Папка S2R пуста. Добавьте .txt или .luau файлы.", Colors.warning)
		return
	end

	for index, file in ipairs(files) do
		createFileOption(file, index)
	end
	setImportStatus(string.format("Найдено файлов: %d", #files), Colors.muted)
end

local function closeImportOverlay()
	if importOverlay then
		importOverlay.Visible = false
	end
	setImportDropdownOpen(false)
end

local function loadImportedFile()
	if destroyed or not importOverlay.Visible then
		return
	end

	setImportDropdownOpen(false)
	if not importSelectedPath then
		setImportStatus("Выберите файл из папки S2R", Colors.danger)
		return
	end

	local readfile = getExecutorFunction("readfile")
	if type(readfile) ~= "function" then
		setImportStatus("readfile недоступен в этом executor", Colors.danger)
		return
	end

	local ok, content = pcall(readfile, importSelectedPath)
	if not ok then
		setImportStatus("Не удалось прочитать: " .. tostring(content), Colors.danger)
		return
	end
	if type(content) ~= "string" then
		setImportStatus("Файл пуст или имеет неверный формат", Colors.danger)
		return
	end

	content = content:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
	if trimText(content) == "" then
		setImportStatus("Файл пуст", Colors.danger)
		return
	end

	dataBox.Text = content
	local parsed = parseLuaTable(content)
	if parsed then
		setImportStatus(string.format("Загружено объектов: %d", #parsed), Colors.success)
		if not isTransferring then
			resetProgress()
			setStatus("Таблица загружена из файла", Colors.success, 0)
		end
		task.delay(0.4, function()
			if importOverlay and importOverlay.Visible then
				closeImportOverlay()
			end
		end)
	else
		setImportStatus("Файл загружен, но Lua-таблица не распознана", Colors.warning)
	end
end

importButton.MouseButton1Click:Connect(function()
	if destroyed then
		return
	end
	if isTransferring then
		setStatus("ДОЖДИТЕСЬ ЗАВЕРШЕНИЯ ПЕРЕНОСА", Colors.warning, 0)
		return
	end
	importOverlay.Visible = true
	setImportStatus("", Colors.muted)
	ensureImportFolder()
	refreshImportFiles()
	setImportDropdownOpen(false)
end)

importFileDropdown.MouseButton1Click:Connect(function()
	if destroyed or not importOverlay.Visible then
		return
	end
	if not importDropdownOpen then
		refreshImportFiles()
	end
	setImportDropdownOpen(not importDropdownOpen)
end)

importLoadButton.MouseButton1Click:Connect(loadImportedFile)
importCancelButton.MouseButton1Click:Connect(closeImportOverlay)

ensureImportFolder()

-- Диагностика DefaultView из консоли экзекутора:
--   S2R_TestDefaultView()
-- Печатает найденную станцию, результат клика и лог попыток.
pcall(function()
	local environment = nil
	pcall(function()
		environment = getgenv()
	end)
	if type(environment) ~= "table" then
		environment = _G
	end
	if type(environment) ~= "table" then
		return
	end
	environment.S2R_TestDefaultView = function()
		local okFind, button = pcall(getDefaultViewButton)
		if not okFind or not button then
			local description = "RGEInterface не найден"
			local okInterface, interface = pcall(findRgeInterface)
			if okInterface and interface then
				local okDescribe, text = pcall(describeDefaultViewCandidates, interface)
				if okDescribe then
					description = text
				end
			end
			warn("S2R DefaultView: станция не найдена. " .. description)
			return nil
		end
		warn("S2R DefaultView: станция " .. instancePath(button) .. " [" .. button.ClassName .. "]")
		local clicked = clickGuiButton(button)
		warn("S2R DefaultView: click=" .. tostring(clicked) .. " log=" .. lastDefaultViewClickLog)
		return clicked
	end
end)
