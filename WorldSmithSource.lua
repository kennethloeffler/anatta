local CollectionService = game:GetService("CollectionService")
local ComponentInfo
local Component = require(script.Parent.WorldSmithServer.Component)

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

function createWorldObject(model, component, setParams)
	local obj, container = Component.new(model, component, setParams)
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

local function main()
	
	local canCreateWindow = true
	local isInInstanceSelection = false
	
	local Toolbar = plugin:CreateToolbar("WorldSmith")
	local AddComponentWindow = Toolbar:CreateButton("Add components...", "Opens a window where components may be added to selected instance(s)", "http://www.roblox.com/asset/?id=2408111785")	
	local ComponentWindow = Toolbar:CreateButton("Show components", "Opens a window which displays all the components contained in the selected instance(s)", "rbxassetid://2482648512")
	local RigidBody = Toolbar:CreateButton("Create rigid body...", "Creates a rigid body out of a selected model (model must have a PrimaryPart)", "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png")	
	local RefreshDependencies = Toolbar:CreateButton("Refresh components...", "Refreshes the list of available components", "http://www.roblox.com/asset/?id=2408135150")
	local Settings = Toolbar:CreateButton("Settings", "Opens the settings menu", "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png")
	local DockWidgetPluginGui = CreateDockWidget("WorldSmithComponents", "Components", Enum.InitialDockState.Float, true, false, 150, 150, 150, 150)
	local AddComponentPluginGui = CreateDockWidget("WorldSmithAddComponents", "Add components...", Enum.InitialDockState.Float, true, false, 150, 150, 150, 150)
	
	spawn(function()
		while wait(0.5) do
			if DockWidgetPluginGui.Parent ~= nil then
				if not game.ServerScriptService:WaitForChild("WorldSmithServer", 0.5) then
					local bin = script.Parent.WorldSmithServer:Clone()
					bin.Parent = game.ServerScriptService	
				end
				ComponentInfo = require(game.ServerScriptService.WorldSmithServer.ComponentInfo)
			else
				break
			end
		end
	end)
	
	spawn(function() 
		while wait(0.5) do
			if DockWidgetPluginGui.Parent ~= nil then
				if not game.ReplicatedStorage:WaitForChild("WorldSmithClient", 0.5) then
					local bin = script.Parent.WorldSmithClient:Clone()
					bin.Parent = game.ReplicatedStorage	
				end
			else
				break
			end
		end
	end)
	
	repeat wait() until ComponentInfo
	
	local WorldObjectList = VerticallyScalingListFrame.new("ActionList")
	local WorldObjectFrame = AutoScalingScrollingFrame.new("ActionFrame", WorldObjectList._uiListLayout)
	local WorldObjectSection = CollapsibleTitledSection.new("Actions", "No instance selected!", true, false, false)
	WorldObjectFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
	WorldObjectFrame:GetFrame().Parent = DockWidgetPluginGui
	WorldObjectList:GetFrame().Parent = WorldObjectSection:GetContentsFrame()
	WorldObjectSection:GetSectionFrame().Parent = WorldObjectFrame:GetFrame()
	
	local newComponentList = VerticallyScalingListFrame.new("AddComponentList")
	local newComponentFrame = AutoScalingScrollingFrame.new("AddComponentFrame", newComponentList._uiListLayout)
	newComponentFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
	newComponentFrame:GetFrame().Parent = AddComponentPluginGui
	newComponentList:GetFrame().Parent = newComponentFrame:GetFrame()
	for worldObject, parameters in pairs(ComponentInfo) do
		local worldObjectCreationButton = CustomTextButton.new(worldObject, worldObject)
		worldObjectCreationButton:getButton().Size = UDim2.new(0.5, 0, 0, 20)
		newComponentList:AddChild(worldObjectCreationButton:getButton())
		worldObjectCreationButton:getButton().MouseButton1Down:connect(function()
			createParameterWindow(getSelection(), worldObject, parameters, true)
		end)
	end
	
	local function updateWorldObjectFrame(selectedObj)
		WorldObjectSection._frame.TitleBarVisual.TitleLabel.Text = "Components: " .. selectedObj.Name
		clearFrame(WorldObjectList:GetFrame())
		for _, container in pairs(selectedObj:GetChildren()) do
			if container:IsA("Folder") then
				createWorldObjectButton(selectedObj, container.Name, ComponentInfo[container.Name], WorldObjectList, container)
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
				createParameterWindow(selectedObj, worldObject, parameters, false, paramContainer)
			end)
			deleteButton:getButton().MouseButton1Click:connect(function()
				if paramContainer then
					for i, v in pairs(paramContainer.Parent:GetChildren()) do
						if v:FindFirstChild("Motor6D") then
							v.Motor6D:Destroy()
						end
					end
					if not selectedObj:FindFirstChildWhichIsA("Folder") then
						CollectionService:RemoveTag(selectedObj, "entity")
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
	
	function createParameterWindow(selectedObj, worldObject, parameters, createNewComponent, paramContainer)
		if not getSelection() then return end
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
				if createNewComponent then
					local _, parameterContainer = createWorldObject(selectedObj, worldObject, setParams)
					if ComponentInfo[worldObject]._init ~= nil then
						ComponentInfo[worldObject]._init(setParams, parameterContainer)
					end
					updateWorldObjectFrame(selectedObj)
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
						createInstanceParameterInput(parameter.Name, setParams, parameterList, parameter.Value.Name or "")
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

	ComponentWindow.Click:connect(function()
		DockWidgetPluginGui.Enabled = not DockWidgetPluginGui.Enabled
		clearFrame(WorldObjectList:GetFrame())
	end)
	
	AddComponentWindow.Click:connect(function()
		clearFrame(newComponentList:GetFrame())
		for worldObject, parameters in pairs(ComponentInfo) do
			local worldObjectCreationButton = CustomTextButton.new(worldObject, worldObject)
			worldObjectCreationButton:getButton().Size = UDim2.new(0.5, 0, 0, 20)
			newComponentList:AddChild(worldObjectCreationButton:getButton())
			worldObjectCreationButton:getButton().MouseButton1Down:connect(function()
				createParameterWindow(getSelection(), worldObject, parameters, true)
			end)
		end
		AddComponentPluginGui.Enabled = not AddComponentPluginGui.Enabled
	end)
	
	RefreshDependencies.Click:connect(function()
		ComponentInfo = require(game.ServerScriptService.WorldSmithServer.ComponentInfo)
		clearFrame(newComponentList:GetFrame())
		for worldObject, parameters in pairs(ComponentInfo) do
			local worldObjectCreationButton = CustomTextButton.new(worldObject, worldObject)
			worldObjectCreationButton:getButton().Size = UDim2.new(0.5, 0, 0, 20)
			newComponentList:AddChild(worldObjectCreationButton:getButton())
			worldObjectCreationButton:getButton().MouseButton1Down:connect(function()
				createParameterWindow(getSelection(), worldObject, parameters, true)
			end)
		end
	end)
	
	RigidBody.Click:connect(function()
		local selection = getSelection()
		if selection and selection:IsA("Model") then
			if not selection.PrimaryPart then error("WorldSmith: Model must have a PrimaryPart to create rigid body") return end
			for _, part in pairs(selection:GetChildren()) do
				if part ~= selection.PrimaryPart and part:IsA("BasePart") then
					local motor6d = Instance.new("Motor6D")
					motor6d.Parent = part
					motor6d.C0 = part.CFrame:inverse() * selection.PrimaryPart.CFrame
					motor6d.Part0 = part
					motor6d.Part1 = selection.PrimaryPart
					part.Anchored = false
				end
			end
		end
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