local ContextActionService = game:GetService("ContextActionService")

local WorldSmithUtilities = {}

local clientSideActiveWorldObjects = {}
local clientSideAssignedWorldObjects = {}

WorldSmithUtilities.inVehicle = false

function WorldSmithUtilities.YieldUntilComponentLoaded(component) -- VERY UGLY HACK! does it work reliably? who really knows?
	local lastNum = 0
	while true do
		local numChildren = #component:GetChildren()
		if numChildren > 0 then
			lastNum = numChildren
		end
		wait()
		if lastNum > 0 and lastNum == #component:GetChildren() then break end
	end
end

function WorldSmithUtilities.CreateArgDictionary(componentChildren)
	local t = {}
	for i, v in ipairs(componentChildren) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

function WorldSmithUtilities.UnpackInputs(componentRef)
	local desktopPCEnum1, desktopPCEnum2 = componentRef.desktopPC.Value:match("([^,]+),([^,]+)")
	local mobileEnum1, mobileEnum2 = componentRef.mobile.Value:match("([^,]+),([^,]+)")
	local consoleEnum1, consoleEnum2 = componentRef.console.Value:match("([^,]+),([^,]+)")
	local inputs = {componentRef.desktopPC.Value ~= "" and Enum[desktopPCEnum1][desktopPCEnum2] or nil, componentRef.mobile.Value ~= "" and Enum[mobileEnum1][mobileEnum2] or nil, componentRef.console.Value ~= "" and Enum[consoleEnum1][consoleEnum2] or nil}
	return unpack(inputs)
end

function WorldSmithUtilities.Query(componentRef, param)
	if componentRef[param] then
		return componentRef[param].Value
	else
		error("WorldObject '".. componentRef.Name .. "' does not have parameter '" .. param .. "'")
	end
end

return WorldSmithUtilities
