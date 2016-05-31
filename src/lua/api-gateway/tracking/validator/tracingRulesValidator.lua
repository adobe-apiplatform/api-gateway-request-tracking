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
local BaseValidator = require "api-gateway.validation.validator"
local _M = BaseValidator:new()

local kinesisLogger

function _M:sendKinesisMessage(kinesis_data)
    local partition_key = ngx.utctime() .."-".. math.random(ngx.now() * 1000)

    -- Send logs to kinesis
    kinesisLogger:logMetrics(partition_key, cjson.encode(kinesis_data))

end

function _M:getKinesisMessage(rule)
    local kinesis_data = {}

    kinesis_data["id"] = tostring(rule.id)
    kinesis_data["domain"] = tostring(rule.domain)
    kinesis_data["request_body"] = tostring(ngx.var.request_body)

    for key,value in pairs(ngx.header) do
        kinesis_data[tostring(key)] = tostring(value)
    end

    return kinesis_data
end

---
-- @param config_obj configuration object
--
function _M:validate_trace_rules(config_obj)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( trackingManager == nil ) then
        ngx.log(ngx.WARN, "Please initialize RequestTrackingManager before calling this method")
    end

    kinesisLogger = ngx.apiGateway.getAsyncLogger("kinesis-logger")
    if ( kinesisLogger == nil ) then
        ngx.log(ngx.WARN, "Could not track request. kinesis logger should not be nil")
        return
    end

    -- 1. read the keys in the shared dict and compare them with the current request
    local stop_at_first_block_match = false
    local traceing_rules = trackingManager:getMatchingRulesForRequest("trace", ";", stop_at_first_block_match)
    if (traceing_rules == nil) then
        return
    end
    -- 2. for each traceing rule matching the request publish a kinesis message asyncronously
    for i, rule in pairs(traceing_rules) do
        if ( rule ~= nil ) then
            local message = self:getKinesisMessage(rule)
            self:sendMessage(message)
        end
    end
end

function _M:validateRequest(obj)
    local traced_message = self:validate_trace_rules(obj)
    return traced_message
end

return _M


