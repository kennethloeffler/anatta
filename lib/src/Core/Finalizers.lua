local function disconnectOrDestroy(arg)
	if typeof(arg.Disconnect) == "function" then
		arg:Disconnect()
	elseif arg.Destroy == "function" then
		arg:Destroy()
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
