--!strict
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local ChangeHistory = game:GetService("ChangeHistoryService")

local Modules = script.Parent.Parent

local Anatta = require(script.Anatta)
local Types = require(Modules.Anatta.Library.Types)

local Actions = require(script.Parent.Actions)

local componentConfigRoot = game:GetService("ServerStorage")
local componentConfigFolder = "ComponentConfigurations"

local componentDefinitionsRoot = game:GetService("ReplicatedStorage")
local componentDefinitionsFolder = "ComponentDefinitions"

local ComponentManager = {}
ComponentManager.__index = ComponentManager

type Component = {
	Name: string,
	Icon: string,
	Visible: boolean,
	DrawType: string,
	Color: Color3,
	AlwaysOnTop: boolean,
	Group: string,
}

local defaultValues = {
	Icon = "tag_green",
	Visible = true,
	DrawType = "Box",
	AlwaysOnTop = false,
	Group = "",
}

ComponentManager._global = nil

local function lerp(start: number, stop: number, t: number): number
	return (stop - start) * t + start
end

local function genColor(name: string): Color3
	local hash = 2166136261
	local prime = 16777619
	local base = math.pow(2, 32)
	for i = 1, #name do
		hash = (hash * prime) % base
		hash = (hash + name:byte(i)) % base
	end
	local h = (hash / math.pow(2, 16)) % 256 / 255
	local s = (hash / math.pow(2, 8)) % 256 / 255
	local v = (hash / math.pow(2, 0)) % 256 / 255

	v = lerp(0.3, 1.0, v)
	s = lerp(0.5, 1.0, s)

	return Color3.fromHSV(h, s, v)
end

function ComponentManager.new(store)
	local self = setmetatable({
		store = store,
		anattaWorld = store:getState().AnattaWorld,
		selectionChanged = nil,
		updateTriggered = false,
		definitionsFolder = componentDefinitionsRoot:FindFirstChild(componentDefinitionsFolder),
		definitionAddedConn = nil,
		definitionRemovedConn = nil,
		definitionChangedConns = nil,
		configurationsFolder = componentConfigRoot:FindFirstChild(componentConfigFolder),
		configurationChangedConns = {},
		configurationChangedSignals = {},
		components = {},
		componentDefinitions = {},
		onUpdate = {},
	}, ComponentManager)

	ComponentManager._global = self

	self:_updateStore()

	self.selectionChanged = Selection.SelectionChanged:Connect(function()
		self:_updateStore()

		local sel = Selection:Get()
		self.store:dispatch(Actions.SetSelectionActive(#sel > 0))
	end)

	if self.configurationsFolder then
		self:_watchConfigurations()
	end

	if not self.definitionsFolder then
		task.spawn(function()
			self.definitionsFolder =
				componentDefinitionsRoot:WaitForChild(componentDefinitionsFolder)

			self:_watchDefinitions()
		end)
	else
		self:_watchDefinitions()
	end

	return self
end

function ComponentManager:Destroy()
	self.selectionChanged:Disconnect()
	if self.definitionAddedConn then
		self.definitionAddedConn:Disconnect()
	end
	if self.definitionRemovedConn then
		self.definitionRemovedConn:Disconnect()
	end
	for _, signal in pairs(self.configurationChangedConns) do
		signal:Disconnect()
	end
	for _, connections in pairs(self.configurationChangedSignals) do
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
end

function ComponentManager.Get(): ComponentManager
	return ComponentManager._global
end

function ComponentManager:GetComponents(): { Component }
	return self.components
end

function ComponentManager:OnComponentsUpdated(func)
	local connection = {
		Disconnect = function(id)
			self.onUpdate[id] = nil
		end,
	}
	self.onUpdate[connection] = func
	return connection
end

function ComponentManager:_watchConfigurations()
	for _, child in pairs(self.configurationsFolder:GetChildren()) do
		if child:IsA("Configuration") then
			self:_watchConfiguration(child)
		end
	end
end

function ComponentManager:_watchDefinitions()
	local function tryDefineComponent(instance)
		if instance.ClassName ~= "ModuleScript" then
			return false
		end

		local world = self.store:getState().AnattaWorld
		local registry = world.registry
		local requireSuccess, newDefinition = pcall(require, instance:Clone())

		if not requireSuccess then
			warn(newDefinition)
			return false
		end

		assert(Types.ComponentDefinition(newDefinition))

		local defineSuccess, defineResult = pcall(registry.defineComponent, registry, newDefinition)

		if not defineSuccess then
			for definition in pairs(registry._pools) do
				if definition.name == newDefinition.name then
					self.componentDefinitions[definition.name] = definition
					self:AddComponent(definition.name)
					return true
				end
			end

			warn(defineResult)
			return false
		end

		self.componentDefinitions[newDefinition.name] = newDefinition
		self:AddComponent(newDefinition.name)
		return true
	end

	for _, instance in ipairs(self.definitionsFolder:GetDescendants()) do
		tryDefineComponent(instance)
	end

	self.definitionAddedConn = self.definitionsFolder.DescendantAdded:Connect(tryDefineComponent)
end

function ComponentManager:_watchConfiguration(instance: Configuration)
	local originalName = instance.name

	self:_updateStore()

	self.configurationChangedConns[instance] =
		instance.AttributeChanged:Connect(function(_attribute)
			self:_updateStore()
		end)

	self.configurationChangedSignals[instance] = {
		instance:GetPropertyChangedSignal("Parent"):Connect(function()
			task.defer(function()
				instance.Parent = self.configurationsFolder
			end)
		end),
		instance:GetPropertyChangedSignal("Name"):Connect(function()
			instance.Name = originalName
		end),
	}
end

function ComponentManager:_getFolder()
	if not self.configurationsFolder then
		self.configurationsFolder = Instance.new("Folder")
		self.configurationsFolder.Name = componentConfigFolder
		self.configurationsFolder.Parent = componentConfigRoot
		self:_watchConfigurations()
	end
	return self.configurationsFolder
end

function ComponentManager:_updateStore()
	if not self.updateTriggered then
		self.updateTriggered = true
		spawn(function()
			self:_doUpdateStore()
		end)
	end
end

function ComponentManager:_doUpdateStore()
	self.updateTriggered = false
	local components: { [number]: Component } = {}
	local groups: { [string]: boolean } = {}
	local selected = Selection:Get()

	if self.configurationsFolder then
		for _, config in pairs(self.configurationsFolder:GetChildren()) do
			if not config:IsA("Configuration") then
				continue
			end

			local hasAny = false
			local missingAny = false
			local entry: Component = {
				Name = config.Name,
				Icon = config:GetAttribute("Icon") or defaultValues.Icon,
				Visible = config:GetAttribute("Visible") or false,
				DrawType = config:GetAttribute("DrawType") or defaultValues.DrawType,
				AlwaysOnTop = config:GetAttribute("AlwaysOnTop") or defaultValues.AlwaysOnTop,
				Group = config:GetAttribute("Group") or defaultValues.Group,
				Color = config:GetAttribute("Color") or genColor(config.Name),
				Definition = self.componentDefinitions[config.Name],
				HasAll = false,
				HasSome = false,
			}

			if entry.Group == "" then
				entry.Group = nil
			end

			if entry.Icon == "" then
				entry.Icon = defaultValues.Icon
			end

			for _, instance in ipairs(selected) do
				if CollectionService:HasTag(instance, entry.Name) then
					hasAny = true
				else
					missingAny = true
				end
			end

			entry.HasAll = hasAny and not missingAny
			entry.HasSome = hasAny and missingAny
			table.insert(components, entry)

			if entry.Group then
				groups[entry.Group] = true
			end
		end
	end

	table.sort(components, function(a, b)
		return a.Name < b.Name
	end)

	local oldComponents = self.components

	self.components = components
	self.store:dispatch(Actions.SetComponentData(components))

	local groupList = {}

	for name, _true in pairs(groups) do
		table.insert(groupList, name)
	end

	table.sort(groupList)

	self.store:dispatch(Actions.SetGroupData(groupList))

	for _, func in pairs(self.onUpdate) do
		func(components, oldComponents)
	end
end

function ComponentManager:_setProp(componentName: string, key: string, value: any)
	local configurationsFolder = self:_getFolder()
	local component = configurationsFolder:FindFirstChild(componentName)
	if not component then
		error("Setting property of non-existent component `" .. tostring(componentName) .. "`")
	end

	-- don't do unnecessary updates
	if component:GetAttribute(key) == value then
		return false
	end

	ChangeHistory:SetWaypoint(string.format(
		"Setting property %q of component %q",
		key,
		componentName
	))
	component:SetAttribute(key, value)
	ChangeHistory:SetWaypoint(string.format("Set property %q of component %q", key, componentName))

	return true
end

function ComponentManager:_getProp(componentName: string, key: string)
	if not self.configurationsFolder then
		return nil
	end

	local instance = self.configurationsFolder:FindFirstChild(componentName)
	if not instance then
		return nil
	end

	return instance:GetAttribute(key)
end

function ComponentManager:AddComponent(name)
	-- Early out if component already exists.
	if self.configurationsFolder and self.configurationsFolder:FindFirstChild(name) then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Creating component %q", name))

	local configurationsFolder = self:_getFolder()
	local instance = Instance.new("Configuration")
	instance.Name = name
	instance:SetAttribute("Icon", defaultValues.Icon)
	instance:SetAttribute("Visible", defaultValues.Visible)
	instance:SetAttribute("DrawType", defaultValues.DrawType)
	instance:SetAttribute("AlwaysOnTop", defaultValues.AlwaysOnTop)
	instance:SetAttribute("Group", defaultValues.Group)
	instance:SetAttribute("Color", genColor(name))
	instance.Parent = configurationsFolder

	ChangeHistory:SetWaypoint(string.format("Created component %q", name))
end

function ComponentManager:Rename(oldName, newName)
	local instance = self.configurationsFolder and self.configurationsFolder:FindFirstChild(oldName)
	if not instance then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Renaming component %q to %q", oldName, newName))

	instance.Name = newName
	for _, componentizedInstance in pairs(CollectionService:GetTagged(oldName)) do
		CollectionService:RemoveTag(componentizedInstance, oldName)
		CollectionService:AddTag(componentizedInstance, newName)
	end

	ChangeHistory:SetWaypoint(string.format("Renamed component %q to %q", oldName, newName))
end

function ComponentManager:SelectAll(component: string)
	Selection:Set(CollectionService:GetTagged(component))
end

function ComponentManager:GetIcon(name: string): string
	return self:_getProp(name, "Icon") or defaultValues.Icon
end

function ComponentManager:GetVisible(name: string): boolean
	return self:_getProp(name, "Visible") or defaultValues.Visible
end

function ComponentManager:GetDrawType(name: string): string
	return self:_getProp(name, "DrawType") or defaultValues.DrawType
end

function ComponentManager:GetColor(name: string): Color3
	return self:_getProp(name, "Color") or defaultValues.Color
end

function ComponentManager:GetAlwaysOnTop(name: string): boolean
	return self:_getProp(name, "AlwaysOnTop") or defaultValues.AlwaysOnTop
end

function ComponentManager:GetGroup(name: string): string
	return self:_getProp(name, "Group") or defaultValues.Group
end

function ComponentManager:SetIcon(name: string, icon: string?)
	self:_setProp(name, "Icon", icon or "")
end

function ComponentManager:SetVisible(name: string, visible: boolean)
	self:_setProp(name, "Visible", visible)
end

function ComponentManager:SetDrawType(name: string, type: string)
	self:_setProp(name, "DrawType", type)
end

function ComponentManager:SetColor(name: string, color: Color3)
	self:_setProp(name, "Color", color)
end

function ComponentManager:SetAlwaysOnTop(name: string, value: boolean)
	self:_setProp(name, "AlwaysOnTop", value)
end

function ComponentManager:SetGroup(name: string, value: string?)
	self:_setProp(name, "Group", value or "")
end

function ComponentManager:DelComponent(name: string)
	local configurationsFolder = self.configurationsFolder
	if not configurationsFolder then
		return
	end
	local instance = configurationsFolder:FindFirstChild(name)
	if not instance then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Deleting component %q", name))

	-- Don't use Destroy as it prevents undo.
	instance.Parent = nil
	for _, inst in pairs(CollectionService:GetTagged(name)) do
		CollectionService:RemoveTag(inst, name)
	end

	ChangeHistory:SetWaypoint(string.format("Deleted component %q", name))
end

function ComponentManager:SetComponent(component, value: boolean)
	if value then
		ChangeHistory:SetWaypoint(string.format("Applying component %q to selection", component.Name))
	else
		ChangeHistory:SetWaypoint(string.format(
			"Removing component %q from selection",
			component.Name
		))
	end

	local selected = Selection:Get()
	local world = self.store:getState().AnattaWorld
	local definition = component.Definition

	for _, instance in pairs(selected) do
		if value then
			local success, err = Anatta.addComponent(world, instance, definition)

			if not success then
				warn(err)
			end
		else
			local success, err = Anatta.removeComponent(world, instance, definition)

			if not success then
				warn(err)
			end
		end
	end

	-- No changed events are bound on selected objects, so the store needs
	-- to be manually marked for update.
	self:_updateStore()

	if value then
		ChangeHistory:SetWaypoint(string.format("Applied component %q to selection", component.Name))
	else
		ChangeHistory:SetWaypoint(string.format(
			"Removed component %q from selection",
			component.Name
		))
	end
end

type ComponentManager = typeof(ComponentManager.new())

return ComponentManager
