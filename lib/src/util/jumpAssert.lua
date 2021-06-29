return function(condition, errorMessage)
	if not condition then
		error(errorMessage, 3)
	end
end
