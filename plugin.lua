local CollectionService = game:GetService("CollectionService")
local EntityManager
local ComponentDesc

if not game:GetService("RunService"):IsStudio() or game:GetService("RunService"):IsRunMode() then
	repeat wait() until false
end

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
				if game.ReplicatedStorage:WaitForChild("WorldSmith", 0.5) then
					if EntityManager then EntityManager:Destroy() end
					EntityManager = require(game.ReplicatedStorage.WorldSmith.EntityManager)
					ComponentDesc = EntityManager:_getComponentDesc()
				else
					local bin = script.Parent.WorldSmith:Clone()
					bin.ServerSystems:Destroy()
					bin.Parent = game.ReplicatedStorage
				end
			else
				if EntityManager then EntityManager:Destroy() end
				break
			end
		end
	end)
	
	spawn(function() 
		while wait(0.5) do
			if DockWidgetPluginGui.Parent ~= nil then
				if not game.ServerScriptService:WaitForChild("WorldSmith", 0.5) then
					local bin = Instance.new("Folder")
					bin.Name = "WorldSmith"
					local s = script.Parent.WorldSmith.ServerSystems:Clone()
					s.Parent = bin
					bin.Parent = game.ServerScriptService
				end
			else
				break
			end
		end
	end)

	repeat wait() until EntityManager
	
	local ComponentList = VerticallyScalingListFrame.new("ComponentList")
	local ComponentFrame = AutoScalingScrollingFrame.new("ComponentFrame", ComponentList._uiListLayout)
	ComponentFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
	ComponentFrame:GetFrame().Parent = DockWidgetPluginGui
	ComponentList:GetFrame().Parent = ComponentFrame:GetFrame()
	
	local function updateComponentFrame(instance)
		if CollectionService:HasTag(instance, "entity") then
			DockWidgetPluginGui.Title = "Components - " .. instance.Name
			clearFrame(ComponentList:GetFrame())
			createComponentSectionsForEntity(instance.GUID.Value)
		end
	end
	
	local newComponentList = VerticallyScalingListFrame.new("AddComponentList")
	local newComponentFrame = AutoScalingScrollingFrame.new("AddComponentFrame", newComponentList._uiListLayout)
	newComponentFrame:GetFrame().Size = UDim2.new(1, 0, 1, 0)
	newComponentFrame:GetFrame().Parent = AddComponentPluginGui
	newComponentList:GetFrame().Parent = newComponentFrame:GetFrame()
	
	local function updateAddComponentFrame()
		clearFrame(newComponentList:GetFrame())
		for component, parameters in pairs(ComponentDesc) do
			local ComponentCreationButton = CustomTextButton.new(component, parameters._metadata.ComponentType)
			ComponentCreationButton:getButton().Size = UDim2.new(1, 0, 0, 20)
			newComponentList:AddChild(ComponentCreationButton:getButton())
			ComponentCreationButton:getButton().MouseButton1Down:connect(function()
					local paramList = {}
				for param, v in pairs(parameters) do
					if typeof(v) == "string" then
							local setVal
						if v == "Instance" then
							setVal = Instance.new("BoolValue")
						elseif v == "boolean" then
							setVal = true
						elseif v == "string" then
								setVal = ""
						elseif v == "number" then
							setVal = 0
						end
						paramList[param] = setVal
					end
				end
				if getSelection() then
					EntityManager:AddComponent(getSelection(), parameters._metadata.ComponentType, paramList, true, true)
					updateComponentFrame(getSelection())
				end
			end)
		end
	end
	updateAddComponentFrame()		
	
	local function createParameterInput(param, value, component)
		local input
		local paramName = EntityManager:_getParamNameFromId(param, component._componentId)
		if typeof(value) == "Instance" then
			input = LabeledInstanceInput.new(paramName, paramName, value and value.Name)
			input:SetInstanceClass("Instance")
			input:SetInstanceChangedFunction(function()
				component[paramName] = input:GetInstance()
			end)
		elseif typeof(value) == "number" then
			input = LabeledTextInput.new(paramName, paramName, value and tonumber(value))
			input:SetValueChangedFunction(function()
				component[paramName] = tonumber(input:GetValue()) or 0
			end)
		elseif typeof(value) == "boolean" then
			input = LabeledCheckBox.new(paramName, paramName, value, false)
			input:SetValueChangedFunction(function()
				component[paramName] = input:GetValue()
			end)
		elseif typeof(value) == "string" then
			input = LabeledTextInput.new(paramName, paramName, value and tostring(value))
			input:SetValueChangedFunction(function()
				component[paramName] = tostring(input:GetValue())
			end)
		end
		return input
	end
	
	function createComponentSectionsForEntity(entity)
		local components = EntityManager._entityMap[entity]
		for componentId in pairs(components) do
			local componentName = ComponentDesc[componentId]._metadata.ComponentType
			local ComponentSection = CollapsibleTitledSection.new(componentName, componentName, true, true)
			ComponentList:AddChild(ComponentSection:GetSectionFrame())
			for paramId, value in ipairs(EntityManager._componentMap[componentId][entity]) do
				local input = createParameterInput(paramId, value, EntityManager._componentMap[componentId][entity])
				if input then
					input:GetFrame().Parent = ComponentSection:GetContentsFrame()
				end
			end
		end
	end
	
	local selectionCon
	selectionCon = game.Selection.SelectionChanged:connect(function()
		if DockWidgetPluginGui.Parent ~= nil then
			local instance = getSelection()
			if instance then
				if not isInInstanceSelection then
					updateComponentFrame(instance)	
				end
			else
				DockWidgetPluginGui.Title = "Components"
				clearFrame(ComponentList:GetFrame())
			end
		else
			selectionCon:Disconnect()
		end
	end)

	ComponentWindow.Click:connect(function()
		DockWidgetPluginGui.Enabled = not DockWidgetPluginGui.Enabled
		clearFrame(ComponentList:GetFrame())
	end)
	
	AddComponentWindow.Click:connect(function()
		AddComponentPluginGui.Enabled = not AddComponentPluginGui.Enabled
	end)
	
	RefreshDependencies.Click:connect(function()
		local c = game.ReplicatedStorage.WorldSmith.ComponentDesc:Clone()
		game.ReplicatedStorage.WorldSmith.ComponentDesc:Destroy()
		c.Parent = game.ReplicatedStorage.WorldSmith
		ComponentDesc = require(game.ReplicatedStorage.WorldSmith.ComponentDesc)
		updateAddComponentFrame()
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
