-- VerticalScalingList.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local VerticalScalingList = {}
local PluginES

function VerticalScalingList.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES

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
