local Anatta = require(script.Parent.Parent.Anatta)

local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = require(script.Parent.Parent.Anatta.Library.Core.Type)

local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix

return function(plugin)
	local components = {
		Instance = t.Instance,
		PendingValidation = t.none,
		ForceEntityAttribute = t.none,
		ValidationListener = t.none,
	}

	local renamedComponents = {}

	for name, definition in pairs(components) do
		renamedComponents[PRIVATE_COMPONENT_PREFIX .. name] = definition
	end

	local anatta = Anatta.new(renamedComponents)

	anatta:loadSystem(Systems.CheckSelectedAttributes)
	anatta:loadSystem(Systems.Components)
	anatta:loadSystem(Systems.ForceEntityAttribute)

	local reloadButton = plugin:createButton({
		icon = "",
		active = false,
		tooltip = "Reload the plugin",
		toolbar = plugin:createToolbar("Anatta"),
		name = "Reload",
	})

	local reloadConnection = reloadButton.Click:Connect(function()
		plugin:reload()
		reloadButton:SetActive(false)
	end)

	plugin:beforeUnload(function()
		anatta:unloadSystems(Systems)
		reloadConnection:Disconnect()
	end)
end
