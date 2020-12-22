local TestService = game:GetService("TestService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(TestService.TestEZ)

TestEZ.TestBootstrap:run {
	ReplicatedStorage:FindFirstChild("AnattaPlugin")
		or ReplicatedStorage:FindFirstChild("anatta")
}
