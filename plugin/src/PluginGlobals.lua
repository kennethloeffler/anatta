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

function exports.promptPickColor(dispatch, component: string)
	local module = CoreGui:FindFirstChild("ColorPane")
	if module and module:IsA("ModuleScript") then
		local manager = ComponentManager.Get()
		local ColorPane = require(module)

		ColorPane.PromptForColor({
			PromptTitle = string.format("%s - Select a color", component),
			InitialColor = manager:GetColor(component),
			OnColorChanged = function(color: Color3)
				manager:SetColor(component, color)
			end,
		})
	else
		dispatch(Actions.ToggleColorPicker(component))
	end
end

function exports.showComponentMenu(dispatch, component: string)
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
		exports.currentComponentMenu = nil
		if action == exports.changeIconAction then
			dispatch(Actions.ToggleIconPicker(component))
		elseif action == exports.changeGroupAction then
			dispatch(Actions.ToggleGroupPicker(component))
		elseif action == exports.changeColorAction then
			exports.promptPickColor(dispatch, component)
		elseif action == exports.viewComponentizedAction then
			dispatch(Actions.OpenInstanceView(component))
		elseif action == exports.deleteAction then
			ComponentManager.Get():DelComponent(component)
		elseif action == exports.renameAction then
			dispatch(Actions.SetRenaming(component, true))
		elseif visualTypes[action] then
			ComponentManager.Get():SetDrawType(component, visualTypes[action])
		elseif action ~= nil and action ~= exports.selectAllAction then
			print("Missing handler for action " .. action.Title)
		end
	end)()
end

return exports
