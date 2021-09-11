local RunService = game:GetService("RunService")

local client = require(script.client)
local server = require(script.server)

return function(remoteEntityMap)
	if RunService:IsClient() then
		client(remoteEntityMap)
	elseif RunService:IsServer() then
		server(remoteEntityMap)
	end
end
