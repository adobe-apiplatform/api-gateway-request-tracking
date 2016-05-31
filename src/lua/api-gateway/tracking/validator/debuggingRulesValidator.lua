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

local BaseValidator = require "api-gateway.validation.validator"
local _M = BaseValidator:new()

---
-- @param config_obj configuration object
-- returns the meta field of the first matched rule.
--
function _M:validate_debug_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_block_match = true
    local debug_rule = trackingManager:getMatchingRulesForRequest("debug",";", stop_at_first_block_match)
    if debug_rule == nil then -- there is no match, so we return nil
        return nil
    end

    return debug_rule.meta or nil
end

function _M:validateRequest(obj)
    local debug_message = self:validate_trace_rules(obj)
    return debug_message
end

return _M