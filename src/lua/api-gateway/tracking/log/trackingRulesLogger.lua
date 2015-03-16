--
-- Publishes the rules matching with the existing local variables ( from the context or form the nginx vars )
--
-- User: ddascal
-- Date: 09/03/15
-- Time: 21:39
--


local _M = {}

local trackingManager
local logger

function _M:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:sendMessage(message)
    if ( message == nil ) then
        return
    end

    logger:log(message)
    ngx.log(ngx.DEBUG, "Tracking message sent: " .. tostring(message) .. ".")
end

function _M:getZMQMessage(rule)
    local timestamp = ngx.time()
    local message = tostring(timestamp) .. " " .. tostring(rule.id) .. ";" .. tostring(rule.domain)
    return message
end

--- Looks in the shared dict with TRACK rules to see if one matched the current request and returns the corresponding value for it
--
function _M:log()
    trackingManager = ngx.apiGateway.tracking.manager
    if (trackingManager == nil) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    logger = ngx.apiGateway.zmqLogger
    if ( logger == nil ) then
        ngx.log(ngx.WARN, "Could not track request. ngx.apiGateway.zmqLogger should not be nil")
        return
    end

    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_block_match = false
    local tracking_rules = trackingManager:getMatchingRulesForRequest("track", ";", stop_at_first_block_match)
    if (tracking_rules == nil) then
        return
    end
    -- 2. for each tracking rule matching the request publish a ZMQ message asyncronously
    for i, rule in pairs(tracking_rules) do
        if ( rule ~= nil ) then
            self:sendMessage(self:getZMQMessage(rule))
        end
    end
end


return _M
