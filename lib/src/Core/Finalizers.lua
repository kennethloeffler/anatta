local function disconnectOrDestroy(arg)
	if typeof(arg.Disconnect) == "function" then
		arg:Disconnect()
	elseif typeof(arg.Destroy) == "function" then
		arg:Destroy()
	elseif typeof(arg.disconnect) == "function" then
		arg:disconnect()
	elseif typeof(arg.destroy) == "function" then
		arg:destroy()
	end
end

local dummyConnection = game.Changed:Connect(function() end)

dummyConnection:Disconnect()

local function call(func)
	func()
end

return {
	["function"] = call,
	RBXScriptConnection = dummyConnection.Disconnect,
	table = disconnectOrDestroy,
	Instance = game.Destroy,
}
