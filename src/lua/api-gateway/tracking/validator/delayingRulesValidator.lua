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
-- Created by IntelliJ IDEA.
-- User: szhang
-- Date: 4/23/15
-- Time: 11:52 AM
-- To change this template use File | Settings | File Templates.
--

local BaseValidator = require "api-gateway.validation.validator"


local _M = BaseValidator:new()

---
-- value in seconds for the default delay
--
local DEFAULT_DELAY = 2

local function getActualDelay( delaying_rule )
    local actualDelay = delaying_rule.data or DEFAULT_DELAY
    if ( actualDelay == 0 ) then
        actualDelay = DEFAULT_DELAY
    end
    return math.random( actualDelay / 2, actualDelay  )
end

---
-- @param config_obj configuration object
--
function _M:validate_delaying_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_delay_match = true
    local delaying_rule = trackingManager:getMatchingRulesForRequest("delay",";", stop_at_first_delay_match)
    if delaying_rule == nil then -- do not delay request
        return ngx.HTTP_OK
    end
    -- there's one delaying rule matching this request
    local actualDelay = getActualDelay(delaying_rule)

    ngx.var.request_delayed = actualDelay
    ngx.log(ngx.DEBUG, "delaying request with " .. tostring(actualDelay) .. " seconds out of the rule setting: " .. tostring(delaying_rule.data) .. " seconds")
    ngx.sleep(actualDelay);
    return ngx.HTTP_OK
end

function _M:validateRequest(obj)
    return self:exitFn(self:validate_delaying_rules(obj))
end

return _M
