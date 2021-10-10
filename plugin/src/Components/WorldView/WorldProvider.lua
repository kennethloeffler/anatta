local Collection = game:GetService("CollectionService")

local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComponentManager = require(Modules.Plugin.ComponentManager)
local Maid = require(Modules.Plugin.Maid)

local WorldProvider = Roact.PureComponent:extend("WorldProvider")

function WorldProvider:init()
	self.state = {
		partsList = {},
	}

	self.nextId = 0
	self.partIds = {}
	self.trackedParts = {}
	self.trackedComponents = {}
	self.instanceAddedConns = Maid.new()
	self.instanceRemovedConns = Maid.new()
	self.instanceAncestryChangedConns = Maid.new()
	self.maid = Maid.new()

	local function cameraAdded(camera)
		self.maid.cameraMovedConn = nil
		if camera then
			local origPos = camera.CFrame.Position
			self.maid.cameraMovedConn = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
				local newPos = camera.CFrame.Position
				if (origPos - newPos).Magnitude > 50 then
					origPos = newPos
					self:updateParts()
				end
			end)
		end
	end
	self.maid.cameraChangedConn = workspace
		:GetPropertyChangedSignal("CurrentCamera")
		:Connect(cameraAdded)
	cameraAdded(workspace.CurrentCamera)
end

function WorldProvider:didMount()
	local manager = ComponentManager.Get()

	for _, component in pairs(manager:GetComponents()) do
		if component.Visible == false or component.DrawType == "None" then
			continue
		end
		self:componentAdded(component.Name)
	end
	self.onComponentsUpdatedConn =
		manager:OnComponentsUpdated(function(newComponents, oldComponents)
			local added = {}
			local removed = {}
			for _, component in pairs(newComponents) do
				if component.Visible == false or component.DrawType == "None" then
					continue
				end
				added[component.Name] = component
			end
			for _, component in pairs(oldComponents) do
				if component.Visible == false or component.DrawType == "None" then
					continue
				end
				if added[component.Name] then
					added[component.Name] = nil
				else
					removed[component.Name] = component
				end
			end

			for name in pairs(added) do
				self:componentAdded(name)
			end
			for name in pairs(removed) do
				self:componentRemoved(name)
			end
			self:updateParts()
		end)

	self:updateParts()
end

local function sortedInsert(array, value, lessThan)
	local start = 1
	local stop = #array

	while stop - start > 1 do
		local pivot = math.floor(start + (stop - start) / 2)
		if lessThan(value, array[pivot]) then
			stop = pivot
		else
			start = pivot + 1
		end
	end

	table.insert(array, start, value)
end

function WorldProvider:updateParts()
	debug.profilebegin("[Component Editor] Update WorldProvider")

	local newList = {}

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position

	local function sortFunc(a, b)
		return a.AngularSize > b.AngularSize
	end
	local function partAngularSize(pos, size)
		local dist = (pos - camPos).Magnitude
		local sizeM = size.Magnitude
		return sizeM / dist
	end
	for obj, _ in pairs(self.trackedParts) do
		local class = obj.ClassName
		if class == "Model" then
			local primary = obj.PrimaryPart
			if not primary then
				local children = obj:GetChildren()
				for i = 1, #children do
					if children[i]:IsA("BasePart") then
						primary = children[i]
						break
					end
				end
			end
			if primary then
				local entry = {
					AngularSize = partAngularSize(primary.Position, obj:GetExtentsSize()),
					Instance = obj,
				}
				sortedInsert(newList, entry, sortFunc)
			end
		elseif class == "Attachment" then
			local entry = {
				AngularSize = partAngularSize(obj.WorldPosition, Vector3.new()),
				Instance = obj,
			}
			sortedInsert(newList, entry, sortFunc)
		else -- assume part
			local entry = {
				AngularSize = partAngularSize(obj.Position, obj.Size),
				Instance = obj,
			}
			sortedInsert(newList, entry, sortFunc)
		end
		local size = #newList
		while size > 500 do
			newList[size] = nil
			size = size - 1
		end
	end

	local componentsMap = {}
	for _, component in pairs(ComponentManager.Get():GetComponents()) do
		componentsMap[component.Name] = component
	end

	local adornMap = {}
	for i = 1, #newList do
		local components = Collection:GetComponents(newList[i].Instance)
		local outlines = {}
		local boxes = {}
		local icons = {}
		local labels = {}
		local spheres = {}
		local anyAlwaysOnTop = false
		for j = 1, #components do
			local componentName = components[j]
			local component = componentsMap[componentName]
			if self.trackedComponents[componentName] and component then
				if component.DrawType == "Outline" then
					outlines[#outlines + 1] = component.Color
				elseif component.DrawType == "Box" then
					boxes[#boxes + 1] = component.Color
				elseif component.DrawType == "Icon" then
					icons[#icons + 1] = component.Icon
				elseif component.DrawType == "Text" then
					labels[#labels + 1] = componentName
				elseif component.DrawType == "Sphere" then
					spheres[#spheres + 1] = component.Color
				end
				if component.AlwaysOnTop then
					anyAlwaysOnTop = true
				end
			end
		end

		local partId = self.partIds[newList[i].Instance]

		if #outlines > 0 then
			local r, g, b = 0, 0, 0
			for j = 1, #outlines do
				r = r + outlines[j].r
				g = g + outlines[j].g
				b = b + outlines[j].b
			end
			r = r / #outlines
			g = g / #outlines
			b = b / #outlines
			local avg = Color3.new(r, g, b)
			adornMap["Outline:" .. partId] = {
				Id = partId,
				Part = newList[i].Instance,
				DrawType = "Outline",
				Color = avg,
				AlwaysOnTop = anyAlwaysOnTop,
			}
		end

		if #boxes > 0 then
			local r, g, b = 0, 0, 0
			for j = 1, #boxes do
				r = r + boxes[j].r
				g = g + boxes[j].g
				b = b + boxes[j].b
			end
			r = r / #boxes
			g = g / #boxes
			b = b / #boxes
			local avg = Color3.new(r, g, b)
			adornMap["Box:" .. partId] = {
				Id = partId,
				Part = newList[i].Instance,
				DrawType = "Box",
				Color = avg,
				AlwaysOnTop = anyAlwaysOnTop,
			}
		end

		if #icons > 0 then
			adornMap["Icon:" .. partId] = {
				Id = partId,
				Part = newList[i].Instance,
				DrawType = "Icon",
				Icon = icons,
				AlwaysOnTop = anyAlwaysOnTop,
			}
		end

		if #labels > 0 then
			table.sort(labels)
			if #icons > 0 then
				labels[#labels + 1] = ""
			end
			adornMap["Text:" .. partId] = {
				Id = partId,
				Part = newList[i].Instance,
				DrawType = "Text",
				ComponentName = labels,
				AlwaysOnTop = anyAlwaysOnTop,
			}
		end

		if #spheres > 0 then
			local r, g, b = 0, 0, 0
			for j = 1, #spheres do
				r = r + spheres[j].r
				g = g + spheres[j].g
				b = b + spheres[j].b
			end
			r = r / #spheres
			g = g / #spheres
			b = b / #spheres
			local avg = Color3.new(r, g, b)
			adornMap["Sphere:" .. partId] = {
				Id = partId,
				Part = newList[i].Instance,
				DrawType = "Sphere",
				Color = avg,
				AlwaysOnTop = anyAlwaysOnTop,
			}
		end
	end

	-- make sure it's not the same as the current list
	local isNew = false
	local props = {
		"Part",
		"Icon",
		"Id",
		"DrawType",
		"Color",
		"ComponentName",
		"AlwaysOnTop",
	}
	local oldMap = self.state.partsList
	for key, newValue in pairs(adornMap) do
		local oldValue = oldMap[key]
		if not oldValue then
			isNew = true
			break
		else
			for i = 1, #props do
				local prop = props[i]
				if newValue[prop] ~= oldValue[prop] then
					isNew = true
					break
				end
			end
		end
	end
	if not isNew then
		for key, _oldValue in pairs(oldMap) do
			if not adornMap[key] then
				isNew = true
				break
			end
		end
	end

	if isNew then
		self:setState({
			partsList = adornMap,
		})
	end

	debug.profileend()
end

function WorldProvider:instanceAdded(inst)
	if self.trackedParts[inst] then
		self.trackedParts[inst] = self.trackedParts[inst] + 1
	else
		self.trackedParts[inst] = 1
		self.nextId = self.nextId + 1
		self.partIds[inst] = self.nextId
	end
end

function WorldProvider:instanceRemoved(inst)
	if not self.trackedParts[inst] then
		return
	end

	if self.trackedParts[inst] <= 1 then
		self:removeInstance(inst)
	else
		self.trackedParts[inst] = self.trackedParts[inst] - 1
	end
end

function WorldProvider:removeInstance(inst)
	self.trackedParts[inst] = nil
	self.partIds[inst] = nil
end

local function isTypeAllowed(instance)
	if instance.ClassName == "Model" then
		return true
	end
	if instance.ClassName == "Attachment" then
		return true
	end
	if instance:IsA("BasePart") then
		return true
	end
	return false
end

function WorldProvider:componentAdded(componentName)
	assert(
		not self.trackedComponents[componentName],
		"Newly added component must not already be tracked"
	)
	self.trackedComponents[componentName] = true
	for _, obj in pairs(Collection:GetTagged(componentName)) do
		if isTypeAllowed(obj) then
			if obj:IsDescendantOf(workspace) then
				self:instanceAdded(obj)
			end
			if not self.instanceAncestryChangedConns[obj] then
				self.instanceAncestryChangedConns[obj] = obj.AncestryChanged:Connect(function()
					if not self.trackedParts[obj] and obj:IsDescendantOf(workspace) then
						self:instanceAdded(obj)
						self:updateParts()
					elseif self.trackedParts[obj] and not obj:IsDescendantOf(workspace) then
						self:removeInstance(obj)
						self:updateParts()
					end
				end)
			end
		end
	end
	self.instanceAddedConns[componentName] = Collection
		:GetInstanceAddedSignal(componentName)
		:Connect(function(obj)
			if not isTypeAllowed(obj) then
				return
			end
			if obj:IsDescendantOf(workspace) then
				self:instanceAdded(obj)
				self:updateParts()
			end
			if not self.instanceAncestryChangedConns[obj] then
				self.instanceAncestryChangedConns[obj] = obj.AncestryChanged:Connect(function()
					if not self.trackedParts[obj] and obj:IsDescendantOf(workspace) then
						self:instanceAdded(obj)
						self:updateParts()
					elseif self.trackedParts[obj] and not obj:IsDescendantOf(workspace) then
						self:removeInstance(obj)
						self:updateParts()
					end
				end)
			end
		end)
	self.instanceRemovedConns[componentName] = Collection
		:GetInstanceRemovedSignal(componentName)
		:Connect(function(obj)
			if not isTypeAllowed(obj) then
				return
			end
			self:instanceRemoved(obj)
			self:updateParts()
		end)
end

function WorldProvider:componentRemoved(componentName)
	assert(
		self.trackedComponents[componentName],
		"Attempted to remove a component that isn't tracked"
	)
	self.trackedComponents[componentName] = nil
	for _, obj in pairs(Collection:GetTagged(componentName)) do
		if obj:IsDescendantOf(workspace) then
			self:instanceRemoved(obj)
		end
	end
	self.instanceAddedConns[componentName] = nil
	self.instanceRemovedConns[componentName] = nil
end

function WorldProvider:willUnmount()
	self.onComponentsUpdatedConn:Disconnect()

	self.instanceAddedConns:clean()
	self.instanceRemovedConns:clean()
	self.instanceAncestryChangedConns:clean()
	self.maid:clean()
end

function WorldProvider:render()
	local render = Roact.oneChild(self.props[Roact.Children])
	local partsList = self.state.partsList

	return render(partsList)
end

return WorldProvider
