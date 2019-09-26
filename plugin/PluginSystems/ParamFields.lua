local ParamFields = {}
local PluginES

function ParamFields.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginManager

	PluginES.ComponentAdded("ParamField", function(paramField)
		
	end)

	PluginES.ComponentAdded("ClearParamFields", function(clearParamFields)
	end)
end

return ParamFields

