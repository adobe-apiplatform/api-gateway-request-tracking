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
-- Checks if the rule has to be redirected to a different backend.
-- Usage:
-- location /randomlocation {
--      set_by_lua $backend "
--          local m = require 'api-gateway.tracking.validator.rewritingRulesValidator';
--          local v = m:new();
--          local backend = m:validateRequest();
--          return backend;
--      ";
--      content_by_lua "ngx.say(ngx.var.backend)";
-- }
--

local BaseValidator = require "api-gateway.validation.validator"
local _M = BaseValidator:new()

local function getBackendFromRewriteRule( rewrite_rule )
    local backend = rewrite_rule.meta or nil
    local variableManager = ngx.apiGateway.tracking.variableManager
    if ( backend == nil ) then
        return nil
    end
    if ( string.sub(backend, 1, 1) == "$" ) then
        backend = variableManager:getRequestVariable(string.sub(backend, 2), nil)
    end
    return backend
end

---
-- @param config_obj configuration object
-- returns the meta field of the first matched rule.
--
function _M:validate_rewrite_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end
    -- 1. read the keys in the shared dict and compare it with the current request
    local stop_at_first_block_match = true
    local rewrite_rule = trackingManager:getMatchingRulesForRequest("rewrite",";", stop_at_first_block_match)
    if rewrite_rule == nil then -- there is no match, so we return nil
        return nil
    end

    ngx.var.rewritten_by = math.floor(tonumber(rewrite_rule.id)/10000)
    local backend = getBackendFromRewriteRule(rewrite_rule)
    return backend
end

function _M:validateRequest(obj)
    local backend = self:validate_rewrite_rules(obj)
    return backend
end

return _M
