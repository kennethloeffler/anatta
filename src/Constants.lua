local EntityIdWidth = 16

return {
	STRICT = true,
	ENTITYID_WIDTH = EntityIdWidth,
	ENTITYID_MASK = bit32.rshift(0xFFFFFFFF, EntityIdWidth),
	NULL_ENTITYID = 0
}
