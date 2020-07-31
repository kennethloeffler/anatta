--[[

	Helper class for observers and views

]]
local Matcher = {}
Matcher.__index = Matcher

local move = table.move
	and table.move
	or function(t1, f, e, t, t2)
		for i = f, e do
			t2[t] = t1[i]
			t = t + 1
		end
		return t2
	end

local function append(source, destination)
	move(source, 1, #source, #destination + 1, destination)
end

function Matcher:all(...)
	append({ ... }, self.required)

	return self
end

function Matcher:except(...)
	append({ ... }, self.forbidden)

	return self
end

function Matcher:updated(...)
	append({ ... }, self.changed)

	return self
end

return Matcher
