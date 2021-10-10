--!strict

local Collection = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local ChangeHistory = game:GetService("ChangeHistoryService")

local Actions = require(script.Parent.Actions)

local componentsRoot = game:GetService("ServerStorage")
local componentsFolderName = "ComponentList"

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
		selectionChanged = nil,
		updateTriggered = false,
		componentsFolder = componentsRoot:FindFirstChild(componentsFolderName),
		childAddedConn = nil,
		childRemovedConn = nil,
		attributeChangedSignals = {},
		nameChangedSignals = {},
		components = {},
		onUpdate = {},
	}, ComponentManager)

	ComponentManager._global = self

	-- Migration path to new attribute based format.
	if self.componentsFolder then
		ChangeHistory:SetWaypoint("Migrating components folder")

		local migrateCount = 0
		for _, componentInstance in pairs(self.componentsFolder:GetChildren()) do
			if componentInstance:IsA("Folder") then
				local newInstance = Instance.new("Configuration")
				newInstance.Name = componentInstance.Name

				local inherited = {}
				for _, valueInst in pairs(componentInstance:GetChildren()) do
					if valueInst:IsA("ValueBase") then
						newInstance:SetAttribute(valueInst.Name, valueInst.Value)
						inherited[valueInst.Name] = true
					end
				end
				for name, value in pairs(defaultValues) do
					if inherited[name] then
						continue
					end
					newInstance:SetAttribute(name, value)
				end
				newInstance.Parent = self.componentsFolder
				componentInstance.Parent = nil
				migrateCount += 1
			end
		end
		if migrateCount > 0 then
			print(string.format(
				"ComponentEditor: Converted %d components to attribute-based format.",
				migrateCount
			))
		end

		ChangeHistory:SetWaypoint("Migrated components folder")
	end

	self:_updateStore()

	self.selectionChanged = Selection.SelectionChanged:Connect(function()
		self:_updateStore()
		self:_updateUnknown()

		local sel = Selection:Get()
		self.store:dispatch(Actions.SetSelectionActive(#sel > 0))
	end)

	if self.componentsFolder then
		self:_watchFolder()
	end

	return self
end

function ComponentManager:Destroy()
	self.selectionChanged:Disconnect()
	if self.childAddedConn then
		self.childAddedConn:Disconnect()
	end
	if self.childRemovedConn then
		self.childRemovedConn:Disconnect()
	end
	for _, signal in pairs(self.attributeChangedSignals) do
		signal:Disconnect()
	end
	for _, signal in pairs(self.nameChangedSignals) do
		signal:Disconnect()
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

function ComponentManager:_watchFolder()
	for _, child in pairs(self.componentsFolder:GetChildren()) do
		if child:IsA("Configuration") then
			self:_watchChild(child)
		end
	end
	self.childAddedConn = self.componentsFolder.ChildAdded:Connect(function(instance: Instance)
		if instance:IsA("Configuration") then
			self:_watchChild(instance)
		end
	end)
	self.childRemovedConn = self.componentsFolder.ChildRemoved:Connect(function(instance)
		if instance:IsA("Configuration") then
			self:_updateStore()
			local nameChangedSignal = self.nameChangedSignals[instance]
			if nameChangedSignal then
				nameChangedSignal:Disconnect()
				self.nameChangedSignals[instance] = nil
			end
			local attributeChangedSignal = self.attributeChangedSignals[instance]
			if attributeChangedSignal then
				attributeChangedSignal:Disconnect()
				self.attributeChangedSignals[instance] = nil
			end
		end
	end)
end

function ComponentManager:_watchChild(instance: Configuration)
	self:_updateStore()

	self.attributeChangedSignals[instance] = instance.AttributeChanged:Connect(function(_attribute)
		self:_updateStore()
	end)

	self.nameChangedSignals[instance] = instance
		:GetPropertyChangedSignal("Name")
		:Connect(function(_attribute)
			self:_updateStore()
		end)
end

function ComponentManager:_getFolder()
	if not self.componentsFolder then
		self.componentsFolder = Instance.new("Folder")
		self.componentsFolder.Name = componentsFolderName
		self.componentsFolder.Parent = componentsRoot
		self:_watchFolder()
	end
	return self.componentsFolder
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
	local sel = Selection:Get()

	if self.componentsFolder then
		for _, inst in pairs(self.componentsFolder:GetChildren()) do
			if not inst:IsA("Configuration") then
				continue
			end
			local hasAny = false
			local missingAny = false
			local entry: Component = {
				Name = inst.Name,
				Icon = inst:GetAttribute("Icon") or defaultValues.Icon,
				Visible = inst:GetAttribute("Visible") or false,
				DrawType = inst:GetAttribute("DrawType") or defaultValues.DrawType,
				AlwaysOnTop = inst:GetAttribute("AlwaysOnTop") or defaultValues.AlwaysOnTop,
				Group = inst:GetAttribute("Group") or defaultValues.Group,
				Color = inst:GetAttribute("Color") or genColor(inst.Name),
				HasAll = false,
				HasSome = false,
			}
			if entry.Group == "" then
				entry.Group = nil
			end
			if entry.Icon == "" then
				entry.Icon = defaultValues.Icon
			end
			for i = 1, #sel do
				local obj = sel[i]
				if Collection:HasTag(obj, entry.Name) then
					hasAny = true
				else
					missingAny = true
				end
			end
			entry.HasAll = hasAny and not missingAny
			entry.HasSome = hasAny and missingAny
			components[#components + 1] = entry
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

function ComponentManager:_updateUnknown()
	local sel = Selection:Get()

	local knownComponents = {}
	for _, component in pairs(self.components) do
		knownComponents[component.Name] = true
	end

	local unknownComponentsMap = {}
	for _, inst in pairs(sel) do
		local components = Collection:GetTags(inst)
		for _, name in pairs(components) do
			-- Ignore unknown components that start with a dot.
			if not knownComponents[name] and name:sub(1, 1) ~= "." then
				unknownComponentsMap[name] = true
			end
		end
	end
	local unknownComponentsList: { string } = {}
	for component, _ in pairs(unknownComponentsMap) do
		table.insert(unknownComponentsList, component)
	end
	table.sort(unknownComponentsList)

	self.store:dispatch(Actions.SetUnknownComponents(unknownComponentsList))
end

function ComponentManager:_setProp(componentName: string, key: string, value: any)
	local componentsFolder = self:_getFolder()
	local component = componentsFolder:FindFirstChild(componentName)
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
	if not self.componentsFolder then
		return nil
	end

	local instance = self.componentsFolder:FindFirstChild(componentName)
	if not instance then
		return nil
	end

	return instance:GetAttribute(key)
end

function ComponentManager:AddComponent(name)
	-- Early out if component already exists.
	if self.componentsFolder and self.componentsFolder:FindFirstChild(name) then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Creating component %q", name))

	local componentsFolder = self:_getFolder()
	local instance = Instance.new("Configuration")
	instance.Name = name
	instance:SetAttribute("Icon", defaultValues.Icon)
	instance:SetAttribute("Visible", defaultValues.Visible)
	instance:SetAttribute("DrawType", defaultValues.DrawType)
	instance:SetAttribute("AlwaysOnTop", defaultValues.AlwaysOnTop)
	instance:SetAttribute("Group", defaultValues.Group)
	instance:SetAttribute("Color", genColor(name))
	instance.Parent = componentsFolder

	ChangeHistory:SetWaypoint(string.format("Created component %q", name))
end

function ComponentManager:Rename(oldName, newName)
	local instance = self.componentsFolder and self.componentsFolder:FindFirstChild(oldName)
	if not instance then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Renaming component %q to %q", oldName, newName))

	instance.Name = newName
	for _, componentizedInstance in pairs(Collection:GetTagged(oldName)) do
		Collection:RemoveTag(componentizedInstance, oldName)
		Collection:AddTag(componentizedInstance, newName)
	end

	ChangeHistory:SetWaypoint(string.format("Renamed component %q to %q", oldName, newName))
end

function ComponentManager:SelectAll(component: string)
	Selection:Set(Collection:GetTagged(component))
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
	local componentsFolder = self.componentsFolder
	if not componentsFolder then
		return
	end
	local instance = componentsFolder:FindFirstChild(name)
	if not instance then
		return
	end

	ChangeHistory:SetWaypoint(string.format("Deleting component %q", name))

	-- Don't use Destroy as it prevents undo.
	instance.Parent = nil
	for _, inst in pairs(Collection:GetTagged(name)) do
		Collection:RemoveTag(inst, name)
	end

	ChangeHistory:SetWaypoint(string.format("Deleted component %q", name))
end

function ComponentManager:SetComponent(name: string, value: boolean)
	if value then
		ChangeHistory:SetWaypoint(string.format("Applying component %q to selection", name))
	else
		ChangeHistory:SetWaypoint(string.format("Removing component %q from selection", name))
	end

	local sel = Selection:Get()
	for _, obj in pairs(sel) do
		if value then
			Collection:AddTag(obj, name)
		else
			Collection:RemoveTag(obj, name)
		end
	end
	-- No changed events are bound on selected objects, so the store needs
	-- to be manually marked for update.
	self:_updateStore()

	if value then
		ChangeHistory:SetWaypoint(string.format("Applied component %q to selection", name))
	else
		ChangeHistory:SetWaypoint(string.format("Removed component %q from selection", name))
	end
end

type ComponentManager = typeof(ComponentManager.new())

return ComponentManager
