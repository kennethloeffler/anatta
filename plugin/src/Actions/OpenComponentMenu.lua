return function(isMenuOpen, name)
	return {
		type = "OpenComponentMenu",
		isMenuOpen = isMenuOpen,
		component = name,
	}
end
