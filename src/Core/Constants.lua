local EntityIdWidth = 24

return {
	NONE = {},
	ENTITYID_MASK = bit32.rshift(0xFFFFFFFF, 32 - EntityIdWidth),
	ENTITYID_WIDTH = EntityIdWidth,
	NULL_ENTITYID = 0
}
