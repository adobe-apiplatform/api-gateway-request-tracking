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
local _M = {}

local kinesisLogger

function _M:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:sendKinesisMessage(kinesis_data)

    local kinesisSwitch = ngx.var.kinesisSwitch
    if (kinesisSwitch == nil or kinesisSwitch == "") then
        kinesisSwitch = "on"
    end
    if ( kinesisLogger ~= nil and (kinesisSwitch ~= nil and kinesisSwitch == "on")) then
        local partition_key = ngx.utctime() .."-".. math.random(ngx.now() * 1000)

        -- Send logs to kinesis
        kinesisLogger:logMetrics(partition_key, cjson.encode(kinesis_data))
    else
        ngx.log(ngx.WARN, "Trace info not sent to kinesis")
    end

end

function _M:getKinesisMessage(rule)
    local kinesis_data = {}

    kinesis_data["id"] = tostring(rule.id)
    kinesis_data["domain"] = tostring(rule.domain)
    kinesis_data["request_body"] = tostring(ngx.var.request_body)

    for key,value in pairs(ngx.header) do
        kinesis_data[tostring(key)] = tostring(value)
    end

    local meta = rule.meta
    local meta_length = table.getn(meta)

    local var_value, index
    for index = 1, meta_length do
        local variableManager = ngx.apiGateway.tracking.variableManager
        var_value = variableManager:getRequestVariable(meta[index], nil)
        kinesis_data[tostring(meta[index])] = tostring(var_value)
    end

    return kinesis_data
end

---
-- @param config_obj configuration object
--
function _M:log_trace_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end

    kinesisLogger = ngx.apiGateway.getAsyncLogger("api-gateway-debugging")
    if ( kinesisLogger == nil ) then
        ngx.log(ngx.WARN, "Could not track request. kinesis logger should not be nil")
        return
    end

    -- 1. read the keys in the shared dict and compare them with the current request
    local stop_at_first_block_match = false
    local tracing_rules = trackingManager:getMatchingRulesForRequest("trace", ";", stop_at_first_block_match)
    if (tracing_rules == nil) then
        return
    end
    -- 2. for each tracing rule matching the request publish a kinesis message asyncronously
    for i, rule in pairs(tracing_rules) do
        if ( rule ~= nil ) then
            local message = self:getKinesisMessage(rule)
            if ( message ~= nil ) then
                ngx.log(ngx.DEBUG, "Sending tracing info to kinesis: " .. cjson.encode(message))
                self:sendKinesisMessage(message)
            end
        end
    end
end

return _M

