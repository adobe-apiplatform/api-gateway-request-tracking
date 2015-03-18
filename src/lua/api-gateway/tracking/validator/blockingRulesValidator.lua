--
-- Checks the rules for BLOCK to find if the current request needs to be blocked
-- Usage:
-- location /validate-blocking-rules {
--
--    content_by_lua '
--
--
--    ';
-- }
-- User: ddascal
-- Date: 09/03/15
-- Time: 21:26
-- To change this template use File | Settings | File Templates.
--

local BaseValidator = require "api-gateway.validation.validator"
local cjson = require "cjson"

local RESPONSES = {
        BLOCK_REQUEST = { error_code = "429050", message = "Too many requests"        }
}

local _M = BaseValidator:new()

function _M:validate_blocking_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_block_match = true
    local blocking_rule = trackingManager:getMatchingRulesForRequest("block",";", stop_at_first_block_match)
    if blocking_rule == nil then -- there's nothing to block so let this request move on
        return self:exitFn(ngx.HTTP_OK)
    end
    -- there's one blocking rule matching this request
    return self:exitFn(RESPONSES.BLOCK_REQUEST.error_code, cjson.encode(RESPONSES.BLOCK_REQUEST))
end

function _M:validateRequest(obj)
    return self:validate_blocking_rules(obj)
end

return _M