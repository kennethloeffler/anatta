return function(name)
	local symbol = newproxy(true)
	local qualifiedName = ("symbol %s"):format(name)

	getmetatable(symbol).__tostring = function()
		return qualifiedName
	end

	return symbol
end
