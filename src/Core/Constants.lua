local EntityIdWidth = 24

local NONE = setmetatable({}, {
	__newindex = function()
		error("Attempt to mutate NONE")
	end,
})

return {
	DEBUG = true,
	ENTITYID_MASK = bit32.rshift(0xFFFFFFFF, 32 - EntityIdWidth),
	ENTITYID_WIDTH = EntityIdWidth,
	NONE = NONE,
	NULL_ENTITYID = 0
}
