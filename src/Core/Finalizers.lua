local function disconnect(connection)
	connection:Disconnect()
end

return {
	RBXScriptConnection = disconnect,
	table = disconnect,
	Instance = game.Destroy,
}
