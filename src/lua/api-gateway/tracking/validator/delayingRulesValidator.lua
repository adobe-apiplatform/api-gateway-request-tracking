--
-- Created by IntelliJ IDEA.
-- User: szhang
-- Date: 4/23/15
-- Time: 11:52 AM
-- To change this template use File | Settings | File Templates.
--

local BaseValidator = require "api-gateway.validation.validator"


local _M = BaseValidator:new()

function _M:validate_delaying_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_delay_match = true
    local delaying_rule = trackingManager:getMatchingRulesForRequest("delay",";", stop_at_first_delay_match)
    if delaying_rule == nil then -- don not delay request
    return self:exitFn(ngx.HTTP_OK)
    end
    -- there's one delaying rule matching this request
    -- TODO: read the value from config_obj
    ngx.sleep(9);
    return self:exitFn(ngx.HTTP_OK)
end

function _M:validateRequestForDelaying(obj)
    return self:validate_delaying_rules(obj)
end

return _M
