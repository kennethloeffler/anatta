local Collection = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComponentizedInstanceProvider = Roact.PureComponent:extend("ComponentizedInstanceProvider")

function ComponentizedInstanceProvider:init()
	self.nextId = 1
	self.partIds = {}

	self.selectionChangedConn = Selection.SelectionChanged:Connect(function()
		self:updateState(self.props.componentName)
	end)
	self.ancestryChangedConns = {}
	self.nameChangedConns = {}

	self.state = {
		parts = {},
		selected = {},
	}
end

function ComponentizedInstanceProvider:updateState(componentName)
	local selected = {}
	for _, instance in pairs(Selection:Get()) do
		selected[instance] = true
	end

	local parts = {}
	if componentName then
		parts = Collection:GetTagged(componentName)
	end

	for i, part in pairs(parts) do
		local path = {}
		local cur = part.Parent
		while cur and cur ~= game do
			table.insert(path, 1, cur.Name)
			cur = cur.Parent
		end

		local id = self.partIds[part]
		if not id then
			id = self.nextId
			self.nextId = self.nextId + 1
			self.partIds[part] = id
		end

		parts[i] = {
			id = id,
			instance = part,
			path = table.concat(path, "."),
		}
	end

	table.sort(parts, function(a, b)
		if a.path < b.path then
			return true
		end
		if b.path < a.path then
			return false
		end

		if a.instance.Name < b.instance.Name then
			return true
		end
		if b.instance.Name < b.instance.Name then
			return false
		end

		if a.instance.ClassName < b.instance.ClassName then
			return true
		end
		if b.instance.ClassName < b.instance.ClassName then
			return false
		end

		return false
	end)

	self:setState({
		parts = parts,
		selected = selected,
	})
	return parts, selected
end

function ComponentizedInstanceProvider:didUpdate(prevProps)
	local componentName = self.props.componentName

	if componentName ~= prevProps.componentName then
		local parts = self:updateState(componentName)

		-- Setup signals
		if self.instanceAddedConn then
			self.instanceAddedConn:Disconnect()
			self.instanceAddedConn = nil
		end
		if self.instanceRemovedConn then
			self.instanceRemovedConn:Disconnect()
			self.instanceRemovedConn = nil
		end
		for _, conn in pairs(self.ancestryChangedConns) do
			conn:Disconnect()
		end
		for _, conn in pairs(self.nameChangedConns) do
			conn:Disconnect()
		end
		self.ancestryChangedConns = {}
		self.nameChangedConns = {}
		if componentName then
			self.instanceAddedConn = Collection:GetInstanceAddedSignal(componentName):Connect(function(inst)
				self.nameChangedConns[inst] = inst:GetPropertyChangedSignal("Name"):Connect(function()
					self:updateState(componentName)
				end)
				self.ancestryChangedConns[inst] = inst.AncestryChanged:Connect(function()
					self:updateState(componentName)
				end)
				self:updateState(componentName)
			end)
			self.instanceRemovedConn = Collection:GetInstanceRemovedSignal(componentName):Connect(function(inst)
				self.nameChangedConns[inst]:Disconnect()
				self.nameChangedConns[inst] = nil
				self.ancestryChangedConns[inst]:Disconnect()
				self.ancestryChangedConns[inst] = nil
				self:updateState(componentName)
			end)
		end

		for _, entry in pairs(parts) do
			local part = entry.instance
			self.nameChangedConns[part] = part:GetPropertyChangedSignal("Name"):Connect(function()
				self:updateState(componentName)
			end)
			self.ancestryChangedConns[part] = part.AncestryChanged:Connect(function()
				self:updateState(componentName)
			end)
		end
	end
end

function ComponentizedInstanceProvider:willUnmount()
	if self.instanceAddedConn then
		self.instanceAddedConn:Disconnect()
	end
	if self.instanceRemovedConn then
		self.instanceRemovedConn:Disconnect()
	end
	self.selectionChangedConn:Disconnect()
	for _, conn in pairs(self.ancestryChangedConns) do
		conn:Disconnect()
	end
	for _, conn in pairs(self.nameChangedConns) do
		conn:Disconnect()
	end
end

function ComponentizedInstanceProvider:render()
	local props = self.props

	return Roact.oneChild(props[Roact.Children])(self.state.parts, self.state.selected)
end

return ComponentizedInstanceProvider
