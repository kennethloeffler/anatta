local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComponentList = require(script.Parent.ComponentList)
local ComponentSearch = require(script.Parent.ComponentSearch)
local IconPicker = require(script.Parent.IconPicker)
local ColorPicker = require(script.Parent.ColorPicker)
local WorldView = require(script.Parent.WorldView)
local InstanceView = require(script.Parent.InstanceView)
local GroupPicker = require(script.Parent.GroupPicker)
local TooltipView = require(script.Parent.TooltipView)
local StudioThemeAccessor = require(script.Parent.StudioThemeAccessor)
local rootKey = require(script.Parent.rootKey)

local App = Roact.PureComponent:extend("App")

function App:init()
	self._rootRef = Roact.createRef()
	self._context[rootKey] = self._rootRef
end

function App:render()
	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		[Roact.Ref] = self._rootRef,
	}, {
		Background = StudioThemeAccessor.withTheme(function(theme)
			return Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = theme:GetColor("MainBackground"),
				ZIndex = -100,
			})
		end),
		Container = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1.0,
		}, {
			UIListLayout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,

				-- hack :(
				[Roact.Ref] = function(rbx)
					if rbx then
						spawn(function()
							wait()
							wait()
							rbx:ApplyLayout()
						end)
					end
				end,
			}),

			UIPadding = Roact.createElement("UIPadding"),

			ComponentList = Roact.createElement(ComponentList, {
				Size = UDim2.new(1, 0, 1, -40),
			}),
			ComponentSearch = Roact.createElement(ComponentSearch, {
				Size = UDim2.new(1, 0, 0, 40),
			}),
		}),
		InstanceView = Roact.createElement(InstanceView),
		GroupPicker = Roact.createElement(GroupPicker),
		IconPicker = Roact.createElement(IconPicker),
		ColorPicker = Roact.createElement(ColorPicker),
		WorldView = Roact.createElement(WorldView),
		TooltipView = Roact.createElement(TooltipView),
	})
end

return App
