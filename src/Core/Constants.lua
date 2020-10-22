local EntityIdWidth = 16

return {
	NONE = {},
	ENTITYID_WIDTH = EntityIdWidth,
	ENTITYID_MASK = bit32.rshift(0xFFFFFFFF, EntityIdWidth),
	NULL_ENTITYID = 0
}
