local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")

local Theme = settings().Studio.Theme
local PluginES
local GameES
local SelectionConnection

local ComponentListWidget = {}

function ComponentListWidget.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES

	local mainToolbar = pluginWrapper.GetToolbar("WorldSmith")
	local listComponentButton = pluginWrapper.GetButton(mainToolbar, "List components...", "Displays/hides a menu which can be used to view components on selected instances, edit their parameters, or remove them")
	local componentListWidget = pluginWrapper.GetDockWidget("Components", Enum.InitialDockState.Float, true, false,  200, 300)
	local scrollingFrame = Instance.new("ScrollingFrame")

	componentListWidget.Title = "Components"

	PluginES.AddComponent(scrollingFrame, "VerticalScalingList")

	scrollingFrame.TopImage = ""
	scrollingFrame.BottomImage = ""
	scrollingFrame.ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Light)
	scrollingFrame.BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 16
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollingFrame.Parent = componentListWidget

	listComponentButton.Click:Connect(function()
		componentListWidget.Enabled = not componentListWidget.Enabled
	end)

	PluginES.ComponentAdded("SelectionUpdate", function()
		local selected = Selection:Get()

		local numSelected = #selected
		local instancesByComponentId = {}
		local t

		if numSelected == 0 then
			componentListWidget.Title = "Components"
		elseif numSelected == 1 then
			componentListWidget.Title = ("Components - %s \"%s\""):format(selected[1].ClassName, selected[1].Name)
		else
			componentListWidget.Title = ("Components - %s items"):format(numSelected)
		end

		for _, instance in ipairs(selected) do
			if CollectionService:HasTag(instance, "__WSEntity") then
				for _, component in pairs(GameES.GetComponents(instance)) do
					t = instancesByComponentId[component._componentId] or {}
					instancesByComponentId[component._componentId] = t
					t[#t + 1] = instance
				end
			end
		end

		for _, componentLabel in ipairs(PluginES.GetListTypedComponent(scrollingFrame, "ComponentLabel")) do
			local componentId = componentLabel.ComponentId

			if not instancesByComponentId[componentId] then
				PluginES.KillComponent(componentLabel)
			else
				componentLabel.EntityList = instancesByComponentId[componentId]
				PluginES.AddComponent(componentLabel.Instance[componentId], "UpdateParamFields", {componentLabel})
				instancesByComponentId[componentId] = nil
			end
		end

		for componentId, entityList in pairs(instancesByComponentId) do
			PluginES.AddComponent(scrollingFrame, "ComponentLabel", {
				ComponentId = componentId,
				EntityList = entityList
			})
		end

	end)

	SelectionConnection = Selection.SelectionChanged:Connect(function()
		PluginES.AddComponent(componentListWidget, "SelectionUpdate")
	end)
end

function ComponentListWidget.OnUnloaded()
	SelectionConnection:Disconnect()
end

return ComponentListWidget
