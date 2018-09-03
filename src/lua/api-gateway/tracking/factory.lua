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


-- This factory creates the tracking object to be instatiated when the API Gateway starts
--
--  Usage:
--      init_worker_by_lua '
--          ngx.apiGateway = ngx.apiGateway or {}
--          ngx.apiGateway.tracking = require "api-gateway.validation.tracking"
--      ';
--
-- User: ddascal
-- Date: 10/03/15
-- Time: 19:56
--

local RequestTrackingManager = require "api-gateway.tracking.RequestTrackingManager"
local VariableManager = require "api-gateway.tracking.VariableManager"
local BlockingRulesValidator = require "api-gateway.tracking.validator.blockingRulesValidator"
local DelayingRulesValidator = require "api-gateway.tracking.validator.delayingRulesValidator"
local TrackingRulesLogger    = require "api-gateway.tracking.log.trackingRulesLogger"
local cjson = require "cjson"

--- Handler for REST API:
--   POST /tracking
local function _API_POST_Handler()
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( ngx.req.get_method() == "POST" ) then
       ngx.req.read_body()

       local json_string = ngx.req.get_body_data()

       -- Check http://openresty-reference.readthedocs.io/en/latest/Lua_Nginx_API/#ngxreqget_body_data for details
       if (json_string == nil) then
           ngx.log(ngx.WARN, "ngx.req.get_body_data() returned nil, maybe the request body has been read into disk files; retrying")

           local body_file_name = ngx.req.get_body_file()

           if (body_file_name == nil) then
               ngx.log(ngx.WARN, "ngx.req.get_body_file() returned nil, maybe the request body has not been read or has been read into memory")
           else
               ngx.log(ngx.DEBUG, "ngx.req.get_body_file() returned ", body_file_name)

               local body_file = io.open(body_file_name, "rb")

               json_string = body_file:read("*all")
               ngx.log(ngx.DEBUG, "Read '", json_string, "' from ", body_file_name)
           end
       end

       local success, err, forcible = trackingManager:addRule(json_string)
       if ( success ) then
          ngx.say('{"result":"success"}')
          return ngx.OK
       end
       ngx.log(ngx.WARN, "Error saving a new Rule:" .. tostring(json_string) .. ".Reason: err=" .. tostring(err), ", forcible=" .. tostring(forcible))
       return ngx.HTTP_BAD_REQUEST
    end
end

--- Handler for REST API:
--    GET /tracking/{rule_type}
--
local function _API_GET_Handler(rule_type)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( ngx.req.get_method() == "GET" ) then
        local rules = trackingManager:getRulesForType(rule_type )
        ngx.say( cjson.encode(rules) )
        return ngx.OK
    end
    return ngx.HTTP_BAD_REQUEST
end

--- Validates the request to see if there's any Blocking rule matching. If yes, it blocks the request
--
local function _validateServicePlan()
    local blockingRulesValidator = BlockingRulesValidator:new()
    local http_code, http_body = blockingRulesValidator:validate_blocking_rules()
    if(http_code ~= ngx.HTTP_OK) then
        return blockingRulesValidator:exitFn(http_code, http_body)
    end
    local delayingRulesValidator = DelayingRulesValidator:new()
    return delayingRulesValidator:validateRequest()
end

--- Track the rules that are active, sending an async message to a queue with the usage
-- This method should be called from the log phase ( log_by_lua )
--
local function _trackRequest()
   local trackingRulesLogger = TrackingRulesLogger:new()
    return trackingRulesLogger:log()
end

return {
    manager = RequestTrackingManager:new(),
    variableManager = VariableManager,
    validateServicePlan = _validateServicePlan,
    track = _trackRequest,
    POST_HANDLER = _API_POST_Handler,
    GET_HANDLER = _API_GET_Handler
}
