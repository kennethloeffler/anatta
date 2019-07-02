function WSAssert(condition, ...)
	if not condition then
		if next({...}) then
			local success, msg = pcall(function(...)
				return string.format(...)
			end)
			if success then
				error("assertion failed: " .. msg, 2)
			end
		end
		error("assertion failed", 2)
	end
end

return WSAssert
