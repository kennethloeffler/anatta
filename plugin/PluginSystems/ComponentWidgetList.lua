local Serial = require(script.Parent.Parent.Serial)
local Theme = settings().Studio.Theme

local ComponentWidgetList = {}

local function splitCommaDelinNumStr(str)	
	local list = {}
	for s in string.gmatch(str, "([^,]+)") do
		list[#list + 1] = tonumber(s)
	end
	return unpack(list)
end

local function makeParamValueField(paramValue, paramName, componentType, entityList, pluginManager)
	local valueField
	local paramType = typeof(paramValue)
	if paramType == "boolean" then
		valueField = Instance.new("Frame")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.BorderSizePixel = 0
		local box = Instance.new("ImageButton")
		box.AutoButtonColor = false
		box.BackgroundColor3 = Color3.new(1, 1, 1)
		box.Size = UDim2.new(0, 16, 0, 16)
		box.BorderSizePixel = 0
		box.Position = UDim2.new(0, 20, 0, 2)
		box.Image = "rbxasset://textures/TerrainTools/checkbox_square.png"
		box.Parent = valueField
		local check = Instance.new("ImageLabel")
		check.Active = false
		check.Size = UDim2.new(1, 0, 1, 0)
		check.Image = "rbxasset://textures/TerrainTools/icon_tick.png"
		check.BackgroundTransparency = 1
		check.BorderSizePixel = 0
		check.ImageTransparency = paramValue and 0 or 1 
		check.Parent = box
		box.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				paramValue = not paramValue
				print("my value : " .. tostring(paramValue))
				check.ImageTransparency = paramValue and 0 or 1 
				pluginManager.AddComponent(box, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = paramValue}})
			end
		end)
	elseif paramType == "string" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.BorderSizePixel = 0
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.Text = "     " .. paramValue
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = tostring(valueField.Text)}})
		end)
	elseif paramType == "number" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. paramValue
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = tonumber(valueField.Text)}})
		end)
	elseif paramType == "Vector2" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. tostring(paramValue) 
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. tostring(val)
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = Vector2.new(splitCommaDelinNumStr(valueField.Text))}})
		end)
	elseif paramType == "Vector3" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. tostring(paramValue)
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = Vector3.new(splitCommaDelinNumStr(valueField.Text))}})
		end)
	elseif paramType == "UDim" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. tostring(paramValue) 
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = UDim.new(splitCommaDelinNumStr(valueField.Text))}})
		end)
	elseif paramType == "UDim2" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. tostring(paramValue) 
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = UDim2.new(splitCommaDelinNumStr(valueField.Text))}})
		end)
	elseif paramType == "Color3" then
		valueField = Instance.new("TextBox")
		valueField.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		valueField.Size = UDim2.new(0.7, 0, 1, 0)
		valueField.Position = UDim2.new(0.3, 1, 0, 0)
		valueField.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		valueField.BorderSizePixel = 0
		valueField.Text = "     " .. tostring(paramValue) 
		valueField.FocusLost:Connect(function()
			valueField.Text = "     " .. valueField.Text
			pluginManager.AddComponent(valueField, "DoSerializeEntity", {InstanceList = entityList, ComponentType = componentType, Params = {[paramName] = Color3.new(splitCommaDelinNumStr(valueField.Text))}})
		end)
	else
		error("Unexpected type: " .. paramType)
	end	
	return valueField
end

local function clearParamFields(componentType, numParams, scrollingFrame)
	local componentLabelOffset = scrollingFrame:FindFirstChild(componentType).LayoutOrder
	for _, field in ipairs(scrollingFrame:GetChildren()) do
		if field:IsA("GuiBase") then
			if field.LayoutOrder >= componentLabelOffset + 1 and field.LayoutOrder <= componentLabelOffset + numParams then 
				field:Destroy()
			end
		end
	end
end

local function makeParamFields(componentId, paramList, scrollingFrame, gameManager, entityList, pluginManager)
	local componentDesc = gameManager.GetComponentDesc()
	local componentType = componentDesc.GetComponentTypeFromId(componentId)
	local componentLabelOffset = scrollingFrame:FindFirstChild(componentType).LayoutOrder
	local counter = 0
	for _, paramDef in ipairs(paramList) do
		counter = counter + 1
		local paramName = componentDesc.GetParamNameFromId(componentId, paramDef.paramId)
		local paramDefault = componentDesc.GetParamDefault(componentId, paramName)
		local paramType = typeof(paramDefault)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
		frame.Size = UDim2.new(1, 0, 0, 20)
		frame.BorderSizePixel = 0
		frame.LayoutOrder = componentLabelOffset + counter
		frame.Parent = scrollingFrame

		local paramNameLabel = Instance.new("TextLabel")
		paramNameLabel.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		paramNameLabel.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		paramNameLabel.Size = UDim2.new(0.3, 0, 1, 0)
		paramNameLabel.BorderSizePixel = 0
		paramNameLabel.Text = paramName
		paramNameLabel.TextSize = 8
		paramNameLabel.Parent = frame
		
		local valueField = makeParamValueField(paramDef.paramValue, paramName, componentType, entityList, pluginManager)
		valueField.Parent = frame		
	end
end

local function shiftLabels(scrollingFrame, componentType, numParams, dir)
	local componentLabelOffset = scrollingFrame:FindFirstChild(componentType).LayoutOrder
	for _, inst in pairs(scrollingFrame:GetChildren()) do
		if inst:IsA("GuiBase") and inst.LayoutOrder > componentLabelOffset then
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
			label.Size = UDim2.new(1, -18, 0, 24)
			label.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar)
			label.TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
			label.BorderSizePixel = 0
			label.Text = "       " .. componentType
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Name = componentType
			label.LayoutOrder = componentId
			label.Parent = scrollingFrame

			local labelOpen = false
			label.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if not labelOpen then
						labelOpen = true
						shiftLabels(scrollingFrame, componentType, #paramList, 1)
						makeParamFields(componentId, paramList, scrollingFrame, gameManager, entityList, pluginManager)
					else
						labelOpen = false
						clearParamFields(componentType, #paramList, scrollingFrame)
						shiftLabels(scrollingFrame, componentType, #paramList, -1)
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
		uiListLayout.Parent = scrollingFrame
		for _, inst in ipairs(selectionUpdate.EntityList) do
			makeComponentLabels(inst, scrollingFrame, gameManager, selectionUpdate.EntityList, pluginManager)
		end
		pluginManager.KillComponent(scrollingFrame, "SelectionUpdate")
	end)
end

return ComponentWidgetList

