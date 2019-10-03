local VerticalScalingList = {}
local PluginES

function VerticalScalingList.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginManager

	PluginES.ComponentAdded("VerticalScalingList", function(verticalScalingList)
		local frame = verticalScalingList.Instance
		local uiListLayout = Instance.new("UIListLayout")
		local prop = (frame:IsA("Frame") and "Size") or (frame:IsA("ScrollingFrame") and "CanvasSize")

		for _, instance in ipairs(frame:GetDescendants()) do
			if instance:IsA("GuiObject") and PluginES.GetComponent(instance.Parent, "VerticalScalingList") then
				frame[prop] = frame[prop] + UDim2.new(0, 0, 0, instance.AbsoluteSize.Y.Offset)
			end
		end

		frame.DescendantAdded:Connect(function(instance)
			if instance:IsA("GuiObject") and PluginES.GetComponent(instance.Parent, "VerticalScalingList") then
				frame[prop] = frame[prop] + UDim2.new(0, 0, 0, instance.AbsoluteSize.Y.Offset)
			end
		end)

		frame.DescendantRemoving:Connect(function(instance)
			if instance:IsA("GuiObject") and PluginES.GetComponent(instance.Parent, "VerticalScalingList") then
				frame[prop] = frame[prop] - UDim2.new(0, 0, 0, instance.AbsoluteSize.Y.Offset)
			end
		end)

		uiListLayout.Parent = frame
	end)
end

return VerticalScalingList

