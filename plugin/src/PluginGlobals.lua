local CoreGui = game:GetService("CoreGui")

local Actions = require(script.Parent.Actions)
local ComponentManager = require(script.Parent.ComponentManager)

type Exports = {
	tagMenu: PluginMenu?,
	currentTagMenu: string?,
	changeIconAction: PluginAction?,
	changeGroupAction: PluginAction?,
	changeColorAction: PluginAction?,
	deleteAction: PluginAction?,
	viewTaggedAction: PluginAction?,
	renameAction: PluginAction?,
	visualizeBox: PluginAction?,
	visualizeSphere: PluginAction?,
	visualizeOutline: PluginAction?,
	visualizeText: PluginAction?,
	visualizeIcon: PluginAction?,
	selectAllAction: PluginAction?,
}

local exports: Exports = {}

function exports.promptPickColor(dispatch, tag: string)
	local module = CoreGui:FindFirstChild("ColorPane")
	if module and module:IsA("ModuleScript") then
		local manager = ComponentManager.Get()
		local ColorPane = require(module)

		ColorPane.PromptForColor({
			PromptTitle = string.format("%s - Select a color", tag),
			InitialColor = manager:GetColor(tag),
			OnColorChanged = function(color: Color3)
				manager:SetColor(tag, color)
			end,
		})
	else
		dispatch(Actions.ToggleColorPicker(tag))
	end
end

function exports.showTagMenu(dispatch, tag: string)
	coroutine.wrap(function()
		local visualTypes = {
			[exports.visualizeBox] = "Box",
			[exports.visualizeSphere] = "Sphere",
			[exports.visualizeOutline] = "Outline",
			[exports.visualizeText] = "Text",
			[exports.visualizeIcon] = "Icon",
		}

		exports.currentTagMenu = tag
		local action = exports.TagMenu:ShowAsync()
		exports.currentTagMenu = nil
		if action == exports.changeIconAction then
			dispatch(Actions.ToggleIconPicker(tag))
		elseif action == exports.changeGroupAction then
			dispatch(Actions.ToggleGroupPicker(tag))
		elseif action == exports.changeColorAction then
			exports.promptPickColor(dispatch, tag)
		elseif action == exports.viewTaggedAction then
			dispatch(Actions.OpenInstanceView(tag))
		elseif action == exports.deleteAction then
			ComponentManager.Get():DelTag(tag)
		elseif action == exports.renameAction then
			dispatch(Actions.SetRenaming(tag, true))
		elseif visualTypes[action] then
			ComponentManager.Get():SetDrawType(tag, visualTypes[action])
		elseif action ~= nil and action ~= exports.selectAllAction then
			print("Missing handler for action " .. action.Title)
		end
	end)()
end

return exports
