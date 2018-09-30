local CollectionService = game:GetService("CollectionService")

local WorldObjectInfo
local WorldObject = require(script.Parent.WorldSmith.WorldObject)
local StudioWidgets = require(2393391735)
	local CollapsibleTitledSection = StudioWidgets.CollapsibleTitledSection
	local GuiUtilities = StudioWidgets.GuiUtilities
	local ImageButtonWithText = StudioWidgets.ImageButtonWithText
	local LabeledCheckBox = StudioWidgets.LabeledCheckbox
	local LabeledMultiChoice = StudioWidgets.LabeledMultiChoice
	local LabeledSlider = StudioWidgets.LabeledSlider
	local LabeledTextInput = StudioWidgets.LabeledTextInput
	local LabeledInstanceInput = StudioWidgets.LabeledInstanceInput
	local StatefulImageButton = StudioWidgets.StatefulImageButton
	local VerticallyScalingListFrame = StudioWidgets.VerticallyScalingListFrame
	local CustomTextButton = StudioWidgets.CustomTextButton
	local LabeledRadioButton = StudioWidgets.LabeledRadioButton
	local RbxGui = StudioWidgets.RbxGui
	local AutoScalingScrollingFrame = StudioWidgets.AutoScalingScrollingFrame

function CreateDockWidget(guiId, title, initDockState, initEnabled, overrideEnabledRestore, floatXSize, floatYSize, minWidth, minHeight)
	local DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui(
		guiId,
		DockWidgetPluginGuiInfo.new(
		initDockState,
		initEnabled,
		overrideEnabledRestore,
		floatXSize, 
		floatYSize,
		minWidth,
		minHeight
		)
	)
	DockWidgetPluginGui.Title = title
	return DockWidgetPluginGui
end

function clearFrame(frame)
	for _, v in pairs(frame:GetChildren()) do
		if v:IsA("GuiObject") then
			v:Destroy()
		end
	end
end

function createWorldObject(model, worldObject, setParams)
	local obj, container = WorldObject.new(model, worldObject, setParams)
	return obj, container
end

function updateWorldObject(elementBin, setParams)
	for parameter, value in pairs(setParams) do
		elementBin[parameter].Value = value
		if elementBin.Name == "AnimatedDoor" and elementBin.AutomaticTriggers.Value == true then
			elementBin.FrontTrigger.Value.Parent.CFrame = elementBin.PivotPart.Value.CFrame * CFrame.new(elementBin.Parent:GetModelSize().X/2 - elementBin.PivotPart.Value.Size.X/2, 0, 1 + elementBin.TriggerOffset.Value)
			elementBin.BackTrigger.Value.Parent.CFrame = elementBin.PivotPart.Value.CFrame * CFrame.new(elementBin.Parent:GetModelSize().X/2 - elementBin.PivotPart.Value.Size.X/2, 0, -1 - elementBin.TriggerOffset.Value)		
		end
	end
end

local function getDictionarySize(t)
	local counter = 0
	for i, v in pairs(t) do
		if typeof(v) ~= "function" then
			counter = counter + 1
		end
	end
	return counter
end

main = function()
	
	local canCreateWindow = true
	local isInInstanceSelection = false
	
	local function getSelection()
		local t = game.Selection:Get()
		local counter = 0
		local obj
		for i, v in pairs(t) do
			counter = counter + 1
			obj = v
		end
		if counter == 1 then
			return obj
		end
	end
	
	local Toolbar = plugin:CreateToolbar("WorldSmith")
	local EditorWindow = Toolbar:CreateButton("Editor", "Opens the WorldSmith editor menu", "http://www.roblox.com/asset/?id=2408111785")
	local RefreshWorldObjects = Toolbar:CreateButton("Refresh WorldObjects", "Refreshes the list of available WorldObjects", "http://www.roblox.com/asset/?id=2408135150") 
	local Settings = Toolbar:CreateButton("Settings", "Opens the settings menu", "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png")
	local DockWidgetPluginGui = CreateDockWidget("WorldSmith", "WorldSmith Editor", Enum.InitialDockState.Float, true, false, 150, 150, 150, 150)
	
	spawn(function()
		while wait(0.5) do
			if DockWidgetPluginGui.Parent ~= nil then
				if not game.ServerScriptService:WaitForChild("WorldSmith", 2) then
					local bin = script.Parent.WorldSmith:Clone()
					bin.Parent = game.ServerScriptService	
				end
				WorldObjectInfo = require(game.ServerScriptService.WorldSmith.WorldObjectInfo)
			else
				break
			end
		end
	end)
	
	spawn(function() 
		while wait(0.5) do
			if DockWidgetPluginGui.Parent ~= nil then
				if not game.ReplicatedStorage:WaitForChild("WorldSmith", 2) then
					local bin = Instance.new("Folder")
					bin.Name = "WorldSmith"
					bin.Parent = game.ReplicatedStorage	
					game.ServerScriptService.WorldSmith.WorldSmithClientMain:Clone().Parent = bin
					game.ServerScriptService.WorldSmith.WorldSmithClientUtilities:Clone().Parent = bin
				end
			else
				break
			end
		end
	end)
	
	local WorldObjectList = VerticallyScalingListFrame.new("ActionList")
	local WorldObjectFrame = AutoScalingScrollingFrame.new("ActionFrame", WorldObjectList._uiListLayout)
	local WorldObjectSection = CollapsibleTitledSection.new("Actions", "No element selected!", true, false, false)
	WorldObjectFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
	WorldObjectFrame:GetFrame().Parent = DockWidgetPluginGui
	WorldObjectList:GetFrame().Parent = WorldObjectSection:GetContentsFrame()
	WorldObjectSection:GetSectionFrame().Parent = WorldObjectFrame:GetFrame()
	
	local function updateWorldObjectFrame(selectedObj)
		WorldObjectSection._frame.TitleBarVisual.TitleLabel.Text = "WorldObjects: " .. selectedObj.Name
		clearFrame(WorldObjectList:GetFrame())
		for worldObject, parameters in pairs(WorldObjectInfo) do
			local worldObjectTitle = CollapsibleTitledSection.new(worldObject, worldObject, true, false, false)
			local paramList = VerticallyScalingListFrame.new("worldObjectList")
			local worldObjectCreationButton = CustomTextButton.new("Create", "Create")
			worldObjectCreationButton:getButton().Size = UDim2.new(0.5, 0, 0, 20)
			paramList:AddChild(worldObjectCreationButton:getButton())
			WorldObjectList:AddChild(worldObjectTitle:GetSectionFrame())
			WorldObjectList:AddChild(paramList:GetFrame())
			worldObjectCreationButton:getButton().MouseButton1Down:connect(function()
				createParameterWindow(selectedObj, worldObject, parameters, paramList)
			end)
			for _, container in pairs(selectedObj:GetChildren()) do
				if container:IsA("Folder") then
					if container.Name == worldObject then
						createWorldObjectButton(selectedObj, worldObject, WorldObjectInfo[worldObject], paramList, container)
					end
				end
			end
		end
	end
	
	function createWorldObjectButton(selectedObj, worldObject, parameters, paramList, paramContainer)
		if canCreateWindow then
			local button = CustomTextButton.new(worldObject, worldObject)
			local deleteButton = CustomTextButton.new("delete", "x")
			button:getButton().Size = UDim2.new(1, -60, 0, 20)
			deleteButton:getButton().Size = UDim2.new(0, 20, 0, 20)
			deleteButton:getButton().Position = UDim2.new(1, 0, 0, 0)
			deleteButton:getButton().Parent = button:getButton()
			paramList:AddChild(button:getButton())
			button:getButton().MouseButton1Click:connect(function()
				createParameterWindow(selectedObj, worldObject, parameters, nil, paramContainer)
			end)
			deleteButton:getButton().MouseButton1Click:connect(function()
				if paramContainer then
					for i, v in pairs(paramContainer.Parent:GetChildren()) do
						if v:FindFirstChild("Motor6D") then
							v.Motor6D:Destroy()
						end
					end
					if not selectedObj:FindFirstChildWhichIsA("Folder") then
						CollectionService:RemoveTag(selectedObj, "WorldObject")
					end
					paramContainer:Destroy()
					button:getButton():Destroy()
					updateWorldObjectFrame(selectedObj)
				end
			end)
			return button
		end
	end
	
	function createStringParameterInput(parameter, setParams, parameterList, loadedParam, okButton, okButtonFunction)
		local textbox = LabeledTextInput.new(parameter, parameter, loadedParam or "(none)")
		textbox:SetValueChangedFunction(function()
			setParams[parameter] = textbox:GetValue()
		end)
		parameterList:AddChild(textbox:GetFrame())
	end
	
	function createNumberParameterInput(parameter, setParams, parameterList, loadedParam, okButton, okButtonFunction)
		local textbox = LabeledTextInput.new(parameter, parameter, loadedParam or "0")
		textbox:SetValueChangedFunction(function()
			setParams[parameter] = tonumber(textbox:GetValue())
		end)
		parameterList:AddChild(textbox:GetFrame())
	end
	
	function createBoolParameterInput(parameter, setParams, parameterList, loadedParam)
		local checkbox = LabeledCheckBox.new(parameter, parameter, loadedParam)
		checkbox:SetValueChangedFunction(function()
			setParams[parameter] = checkbox:GetValue()
		end)
		parameterList:AddChild(checkbox:GetFrame())
	end
		
	function createInstanceParameterInput(parameter, setParams, parameterList, loadedParam, okButton, okButtonFunction)
		local textbox = LabeledInstanceInput.new(parameter, parameter, loadedParam or "")
		textbox:SetInstanceClass("Instance")
		textbox:SetInstanceChangedFunction(function()
			setParams[parameter] = textbox:GetInstance()
		end)
		parameterList:AddChild(textbox:GetFrame())
	end
	
	function createParameterWindow(selectedObj, worldObject, parameters, paramList, paramContainer)
		local setParams = {}
		local paramLen = getDictionarySize(parameters)
		if canCreateWindow then
			local con
			canCreateWindow = false	
			
			local parameterList = VerticallyScalingListFrame.new("param")
			local paramWindow = CreateDockWidget("paramWindow", worldObject, Enum.InitialDockState.Float, true, true, 400, 200, 400, 200)
			paramWindow:BindToClose(function() 
				if con then con:Disconnect() con = nil end
				isInInstanceSelection = false
				canCreateWindow = true
				paramWindow:Destroy() 
			end)
			
			local bg = GuiUtilities.MakeFrame("background")
			bg.Parent = paramWindow
			bg.Size = UDim2.new(1, 0, 1, 0)
			
			local okButton = CustomTextButton.new("OK", "OK")
			okButton:getButton().Size = UDim2.new(0, 100, 0, 20)
			okButton:getButton().Position = UDim2.new(0.5, -105, 1, -30)
			okButton:getButton().Parent = bg
			
			local okButtonFunction = (function()
				if con then con:Disconnect() con = nil end
				isInInstanceSelection = false
				canCreateWindow = true
				paramWindow:Destroy()
				if paramList then
					local bin, container = createWorldObject(selectedObj, worldObject, setParams)
					createWorldObjectButton(selectedObj, worldObject, parameters, paramList, bin)
					updateWorldObjectFrame(selectedObj)
					if WorldObjectInfo[worldObject]._init ~= nil then
						WorldObjectInfo[worldObject]._init(setParams, container)
					end
				else
					updateWorldObject(paramContainer, setParams)
					updateWorldObjectFrame(selectedObj)
				end
			end)
			
			okButton:getButton().MouseButton1Click:connect(okButtonFunction)
						
			local cancelButton = CustomTextButton.new("Cancel", "Cancel")
			cancelButton:getButton().Size = UDim2.new(0, 100, 0, 20)
			cancelButton:getButton().Position = UDim2.new(0.5, 5, 1, -30)
			cancelButton:getButton().Parent = bg
			cancelButton:getButton().MouseButton1Click:connect(function()
				if con then con:Disconnect() con = nil end
				isInInstanceSelection = false
				canCreateWindow = true
				paramWindow:Destroy()
			end)
			
			local scrollingFrame = AutoScalingScrollingFrame.new("parameters", parameterList._uiListLayout)
			scrollingFrame:GetFrame().Size = UDim2.new(0, 300, 0.8, 0)
			scrollingFrame:GetFrame().Position = UDim2.new(0.5, -150, 0, 10)
			parameterList:GetFrame().Parent = scrollingFrame:GetFrame()
			scrollingFrame:GetFrame().Parent = bg
			
			if paramContainer then
				for _, parameter in pairs(paramContainer:GetChildren()) do
					if parameter:IsA("ObjectValue") then
						createInstanceParameterInput(parameter.Name, setParams, parameterList, parameter.Value.Name)
						setParams[parameter.Name] = parameter.Value
					elseif parameter:IsA("NumberValue") then
						createNumberParameterInput(parameter.Name, setParams, parameterList, tonumber(parameter.Value))
						setParams[parameter.Name] = tonumber(parameter.Value)
					elseif parameter:IsA("StringValue") then
						createStringParameterInput(parameter.Name, setParams, parameterList, parameter.Value)
						setParams[parameter.Name] = parameter.Value
					elseif parameter:IsA("BoolValue") then
						createBoolParameterInput(parameter.Name, setParams, parameterList, parameter.Value)
						setParams[parameter.Name] = parameter.Value
					end
				end
			else
				for parameter, _type in pairs(parameters) do
					if _type == "Instance" then
						createInstanceParameterInput(parameter, setParams, parameterList)
						setParams[parameter] = Instance.new("IntValue") -- might leak? idk
					elseif _type == "number" then
						createNumberParameterInput(parameter, setParams, parameterList)
						setParams[parameter] =	0
					elseif _type == "string" then
						createStringParameterInput(parameter, setParams, parameterList)
						setParams[parameter] =	""
					elseif _type == "boolean" then
						createBoolParameterInput(parameter, setParams, parameterList, true)
						setParams[parameter] =	true
					end
				end
			end
		end
	end
	
	local selectionCon
	selectionCon = game.Selection.SelectionChanged:connect(function()
		if DockWidgetPluginGui.Parent ~= nil then
			local obj = getSelection()
			if obj then
				if canCreateWindow and not isInInstanceSelection then
					updateWorldObjectFrame(obj)			
				end
			else
				clearFrame(WorldObjectList:GetFrame())
				WorldObjectSection._frame.TitleBarVisual.TitleLabel.Text = "No model selected!"
			end
		else
			selectionCon:Disconnect()
		end
	end)

	EditorWindow.Click:connect(function()
		DockWidgetPluginGui.Enabled = not DockWidgetPluginGui.Enabled
		clearFrame(WorldObjectList:GetFrame())
	end)
	
	RefreshWorldObjects.Click:connect(function()
		local newWorldObjects = game.ServerScriptService.WorldSmith.WorldObjectInfo:Clone()
		game.ServerScriptService.WorldSmith.WorldObjectInfo:Destroy()
		newWorldObjects.Parent = game.ServerScriptService.WorldSmith
		WorldObjectInfo = require(newWorldObjects)
	end)
	
	Settings.Click:connect(function()
		local settings = {
			
		}
		
		local func = {
			
		}
		
		local settingsWindow = CreateDockWidget("settings", "WorldSmith Settings", Enum.InitialDockState.Float, true, true, 300, 300, 300, 300)
		settingsWindow:BindToClose(function()
			settingsWindow:Destroy()
		end)
		
		local bg = GuiUtilities.MakeFrame("background")
		bg.Parent = settingsWindow
		bg.Size = UDim2.new(1, 0, 1, 0)
		
		local settingsList = VerticallyScalingListFrame.new("settings")
		local settingsFrame = AutoScalingScrollingFrame.new("settings", settingsList._uiListLayout)
		settingsFrame:GetFrame().Parent = bg
		settingsFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
		settingsList:GetFrame().Parent = settingsFrame:GetFrame()
		
		for setting, defaultValue in pairs(settings) do
			local element
			if typeof(defaultValue) == "boolean" then
				element = LabeledCheckBox.new(setting, setting, defaultValue, false)
				element:GetFrame().Size = UDim2.new(1, 0, 0, GuiUtilities.kStandardPropertyHeight)
				element:SetValueChangedFunction(function(value)
					func[setting](value)
					plugin:SetSetting(setting, value)
				end)
				settingsList:AddChild(element:GetFrame())
			end
			if plugin:GetSetting(setting) ~= nil then
				element:SetValue(plugin:GetSetting(setting))
			end
		end
	end)
end

main()