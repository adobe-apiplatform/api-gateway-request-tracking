--
-- Publishes the rules matching with the existing local variables ( from the context or form the nginx vars )
--
-- User: ddascal
-- Date: 09/03/15
-- Time: 21:39
--


local _M = {}

--- Looks in the shared dict with TRACK rules to see if one matched the current request and returns the corresponding value for it
--
function _M:getMatchingRuleForRequest()
end

return _M
