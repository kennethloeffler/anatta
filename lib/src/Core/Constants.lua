local EntityIdWidth = 24

return {
	Debug = true,
	EntityIdMask = bit32.rshift(0xFFFFFFFF, 32 - EntityIdWidth),
	EntityIdWidth = EntityIdWidth,
	EntityAttributeName = "__entity",
	NullEntityId = 0,
}
