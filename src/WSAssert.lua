function WSAssert(condition, ...)
	if not condition then
		local var = {...}
		if next(var) then
			local success, msg = pcall(function()
				return string.format(unpack(var))
			end)
			if success then
				error("WorldSmith: assertion failed: " .. msg, 2)
			end
		end
		error("WorldSmith: assertion failed", 2)
	end
end

return WSAssert
