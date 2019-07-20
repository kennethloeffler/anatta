local Serial = require(script.Parent.Parent.Serial)
local Theme = settings().Studio.Theme

local ComponentWidgetList = {}

local function clearParamFields(componentId, numParams, scrollingFrame)
	for _, field in ipairs(scrollingFrame:GetChildren()) do
		if field:IsA("GuiBase") then
			if field.LayoutOrder >= componentId + 1 and field.LayoutOrder <= componentId + numParams then 
				field:Destroy()
			end
		end
	end
end

local function makeParamFields(componentId, paramList, scrollingFrame, gameManager, entityList, pluginManager)
	local componentDesc = gameManager.GetComponentDesc()
	local componentType = componentDesc.GetComponentTypeFromId(componentId)
	local counter = 0
	for _, paramDef in ipairs(paramList) do
		counter = counter + 1
		local paramName = componentDesc.GetParamNameFromId(paramDef.paramId)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
		frame.Size = UDim2.new(1, 0, 0, 16)
		frame.LayoutOrder = componentId + counter
		frame.Parent = scrollingFrame

		local paramNameLabel = Instance.new("TextLabel")
		paramNameLabel.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
		paramNameLabel.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		paramNameLabel.Size = UDim2.new(0, 100, 1, 0)
		paramNameLabel.Text = paramName
		paramNameLabel.TextSize = 8
		paramNameLabel.Parent = frame
		
		local valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.Size = UDim2.new(1, 0, 1, 0)
		valueField.Position = UDim2.new(0, 101, 0, 0)
		valueField.Text = Serial.Serialize(paramDef.paramValue)
		paramNameLabel.TextSize = 8

		valueField.FocusLost:Connect(function()
			pluginManager.AddComponent(scrollingFrame, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {paramName}})
		end)
	end
end

local function shiftLabels(scrollingFrame, componentId, numParams, dir)
	for _, inst in pairs(scrollingFrame:GetChildren()) do
		if inst:IsA("GuiBase") and inst.LayoutOrder > componentId then
			inst.LayoutOrder = dir == 1 and inst.LayoutOrder + numParams or inst.LayoutOrder - numParams
		end
	end
end

local function makeComponentLabels(instance, scrollingFrame, gameManager, entityList, pluginManager)
	local module = instance:FindFirstChild("__WSEntity")

	if not module then
		return
	end
	
	local componentDesc = gameManager.GetComponentDesc()
	local components = Serial.Deserialize(module.Source)
	for componentType, paramList in pairs(components) do
		local componentId = componentDesc.GetComponentIdFromType(componentType)
		local oldLabel = scrollingFrame:FindFirstChild(componentType)
		if not oldLabel then
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -19, 0, 20)
			label.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
			label.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
			label.Text = "  " .. componentType
			label.Name = componentType
			label.LayoutOrder = componentId
			label.Parent = scrollingFrame

			local labelOpen = false
			label.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if not labelOpen then
						labelOpen = true
						shiftLabels(scrollingFrame, componentId, #paramList, 1)
						makeParamFields(componentId, paramList, scrollingFrame, gameManager, entityList, pluginManager)
					else
						labelOpen = false
						clearParamFields(componentId, #paramList, scrollingFrame)
						shiftLabels(scrollingFrame, componentId, #paramList, -1)
					end
				end
			end)
		end
	end
end

function ComponentWidgetList.Init(pluginWrapper)
	local pluginManager = pluginWrapper.PluginManager
	local gameManager = pluginWrapper.GameManager

	pluginManager.ComponentAdded("SelectionUpdate"):Connect(function(scrollingFrame)
		local selectionUpdate = pluginManager.GetComponent(scrollingFrame, "SelectionUpdate")
		local uiListLayout = Instance.new("UIListLayout")
		uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		uiListLayout.Padding = UDim.new(0, 1)
		for _, inst in ipairs(selectionUpdate.EntityList) do
			makeComponentLabels(inst, scrollingFrame, gameManager, selectionUpdate.EntityList)
		end
		pluginManager.KillComponent(scrollingFrame, "SelectionUpdate")
	end)
end

return ComponentWidgetList

