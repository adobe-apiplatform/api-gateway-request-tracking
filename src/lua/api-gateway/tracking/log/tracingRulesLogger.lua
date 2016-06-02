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

local cjson = require "cjson"
local su = require "api-gateway.tracking.util.stringutil"

local _M = {}

function _M:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:buildTraceMessage(rule)
    local data = {}

    data["id"] = tostring(rule.id)
    data["domain"] = tostring(rule.domain)
    data["request_body"] = tostring(ngx.var.request_body)
    data["status"] = tostring(ngx.var.status)

    for key,value in pairs(ngx.header) do
        data[tostring(key)] = tostring(value)
    end

    local meta = rule.meta:split(";")
    local meta_length = table.getn(meta)

    local var_value, index
    for index = 1, meta_length do
        local variableManager = ngx.apiGateway.tracking.variableManager
        local var_name = string.sub(su.trim(meta[index]), 2);
        var_value = variableManager:getRequestVariable(var_name, nil)
        data[var_name] = tostring(var_value)
    end

    return data
end

---
-- @param config_obj configuration object
--
function _M:log_trace_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end

    local tracingLogger = ngx.apiGateway.getAsyncLogger("api-gateway-debugging")
    if ( tracingLogger == nil ) then
        ngx.log(ngx.WARN, "Could not track request. Tracing logger should not be nil")
        return
    end

    -- 1. read the keys in the shared dict and compare them with the current request
    local stop_at_first_block_match = false
    local tracing_rules = trackingManager:getMatchingRulesForRequest("trace", ";", stop_at_first_block_match)
    if (tracing_rules == nil) then
        return
    end
    -- 2. for each tracing rule matching the request publish a tracing message asyncronously
    for i, rule in pairs(tracing_rules) do
        if ( rule ~= nil ) then
            local message = self:buildTraceMessage(rule)
            if ( message ~= nil ) then
                local partition_key = ngx.utctime() .."-".. math.random(ngx.now() * 1000)
                ngx.log(ngx.DEBUG, "Logging tracing info: " .. cjson.encode(message))
                tracingLogger:logMetrics(partition_key, cjson.encode(message));
            end
        end
    end
end

return _M

