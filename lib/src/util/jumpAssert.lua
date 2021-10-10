return function(condition, errorMessage, ...)
	if not condition then
		local params = table.pack(...)

		for i, param in pairs(params) do
			params[i] = tostring(param)
		end

		error(errorMessage:format(unpack(params)), 3)
	end
end
