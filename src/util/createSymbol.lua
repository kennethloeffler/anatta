local AllSymbols = {}

local Symbol = {}
Symbol.__index = Symbol
Symbol.__metatable = "The metatable of Symbol is locked"

function Symbol:__newindex()
	error(("Attempt to mutate symbol %s"):format(self._symbolName))
end

function Symbol:__tostring()
	return self._symbolName
end

return function(symbolName)
	assert(
		type(symbolName) == "string",
		("bad argument #1: expected string, got %s"):format(type(symbolName))
	)

	if AllSymbols[symbolName] then
		return AllSymbols[symbolName]
	end

	local symbol = setmetatable({
		_symbolName = symbolName
	}, Symbol)

	AllSymbols[symbolName] = symbol

	return symbol
end
