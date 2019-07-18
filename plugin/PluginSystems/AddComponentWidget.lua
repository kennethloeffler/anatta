local Serial = require(script.Parent.Parent.Serial)

local AddComponentWidget = {}

function AddComponentWidget.Init(plugin)
	local PluginManager = plugin.PluginManager
	local GameManager = plugin.GameManager
	
	PluginManager.ComponentAdded("AddComponentWidgetOpen"):Connect(function(bgFrame)
		local component = PluginManager.GetComponent(bgFrame, "AddComponentWidgetOpen")
		for componentType in pairs(component.Components) do
			
		end
	end
end

return AddComponentWidget
