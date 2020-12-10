local TestService = game:GetService("TestService")
local ServerStorage = game:GetService("ServerStorage")

local TestEZ = require(TestService.TestEZ)

TestEZ.TestBootstrap:run({ ServerStorage.root })
