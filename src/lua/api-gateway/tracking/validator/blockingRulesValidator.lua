--[[
  Copyright 2016 Adobe Systems Incorporated. All rights reserved.

  This file is licensed to you under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the License
   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR RESPRESENTATIONS OF ANY KIND,
   either express or implied.  See the License for the specific language governing permissions and
   limitations under the License.
  ]]


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
_M["log_identifier"] = "throtteling_validator_execution_time";

---
-- @param config_obj configuration object
-- returns a tuple of 2 objects: < http status code , http response >
--
function _M:validate_blocking_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_block_match = true

    local blocking_rule = trackingManager:getMatchingRulesForRequest("block",";", stop_at_first_block_match)
    if blocking_rule == nil then -- there's nothing to block so let this request move on
        ngx.log(ngx.DEBUG, "Request is not blocked by any rule")
        return ngx.HTTP_OK, ""
    end

    ngx.var.blocked_by = math.floor(tonumber(blocking_rule.id)/100000)
    -- there's one blocking rule matching this request
    ngx.var.retry_after = blocking_rule.expire_at_utc - ngx.time()
    ngx.log(ngx.DEBUG, "Request was blocked by rule id=", blocking_rule.id)
    return RESPONSES.BLOCK_REQUEST.error_code, cjson.encode(RESPONSES.BLOCK_REQUEST)
end

function _M:validateRequest(obj)
    return self:exitFn(self:validate_blocking_rules(obj))
end

return _M