-- Component.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local WSAssert = require(script.Parent.WSAssert)

local Component = {}

function Component.InstanceReference()
	return "__InstanceReferent"
end

function Component.Define(componentTypeName, paramMap, isEthereal)
	WSAssert(typeof(componentTypeName) == "string" or (typeof(componentTypeName) == "table" and typeof(componentTypeName[1]) == "string"), "bad argument #1 (expected string)")
	WSAssert(typeof(paramMap) == "table", "bad argument #2 (expected table)")

	return { componentTypeName, paramMap, isEthereal }
end

return Component
