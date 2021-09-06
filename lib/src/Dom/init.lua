local tryFromDom = require(script.tryFromDom)
local tryFromAttribute = require(script.tryFromAttribute)
local tryFromTag = require(script.tryFromTag)
local tryToAttribute = require(script.tryToAttribute)

return {
	tryFromAttribute = tryFromAttribute,
	tryFromDom = tryFromDom,
	tryFromTag = tryFromTag,
	tryToAttribute = tryToAttribute,
}
