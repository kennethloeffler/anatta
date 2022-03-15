local CoreGui = game:GetService("CoreGui")

local Actions = require(script.Parent.Actions)
local ComponentManager = require(script.Parent.ComponentManager)

type Exports = {
	componentMenu: PluginMenu?,
	currentComponentMenu: string?,
	changeIconAction: PluginAction?,
	changeGroupAction: PluginAction?,
	changeColorAction: PluginAction?,
	deleteAction: PluginAction?,
	viewComponentizedAction: PluginAction?,
	renameAction: PluginAction?,
	visualizeBox: PluginAction?,
	visualizeSphere: PluginAction?,
	visualizeOutline: PluginAction?,
	visualizeText: PluginAction?,
	visualizeIcon: PluginAction?,
	selectAllAction: PluginAction?,
}

local exports: Exports = {}

function exports.promptPickColor(dispatch, componentName)
	local module = CoreGui:FindFirstChild("ColorPane")
	if module and module:IsA("ModuleScript") then
		local manager = ComponentManager.Get()
		local ColorPane = require(module)

		ColorPane.PromptForColor({
			PromptTitle = string.format("%s - Select a color", componentName),
			InitialColor = manager:GetColor(componentName),
			OnColorChanged = function(color: Color3)
				manager:SetColor(componentName, color)
			end,
		})
	else
		dispatch(Actions.ToggleColorPicker(componentName))
	end
end

function exports.showComponentMenu(dispatch, component)
	coroutine.wrap(function()
		local visualTypes = {
			[exports.visualizeBox] = "Box",
			[exports.visualizeSphere] = "Sphere",
			[exports.visualizeOutline] = "Outline",
			[exports.visualizeText] = "Text",
			[exports.visualizeIcon] = "Icon",
		}

		exports.currentComponentMenu = component

		local action = exports.ComponentMenu:ShowAsync()
		local componentName = component.Definition.name

		if action == exports.changeIconAction then
			dispatch(Actions.ToggleIconPicker(componentName))
		elseif action == exports.changeGroupAction then
			dispatch(Actions.ToggleGroupPicker(componentName))
		elseif action == exports.changeColorAction then
			exports.promptPickColor(dispatch, componentName)
		elseif action == exports.viewComponentizedAction then
			dispatch(Actions.OpenInstanceView(componentName))
		elseif visualTypes[action] then
			ComponentManager.Get():SetDrawType(componentName, visualTypes[action])
		elseif action ~= nil and action ~= exports.selectAllAction then
			print("Missing handler for action " .. action.Title)
		end
	end)()
end

return exports
