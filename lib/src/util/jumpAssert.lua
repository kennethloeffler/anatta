return function(condition, errorMessage, ...)
	if not condition then
		local params = table.create(select("#", ...))

		for i = 1, select("#", ...) do
			params[i] = tostring(select(i, ...))
		end

		error(errorMessage:format(table.unpack(params)), 3)
	end
end
