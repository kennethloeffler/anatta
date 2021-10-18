local function disconnect(connection)
	connection:Disconnect()
end

local function call(func)
	func()
end

return {
	["function"] = call,
	RBXScriptConnection = disconnect,
	table = disconnect,
	Instance = game.Destroy,
}
