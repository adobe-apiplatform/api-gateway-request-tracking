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
local cjson = require "cjson"

--- Handler for REST API:
--   POST /tracking
local function _API_POST_Handler()
    local trackingManager = ngx.apiGateway.tracking.manager
    ngx.req.read_body()
    if ( ngx.req.get_method() == "POST" ) then
       local json_string = ngx.req.get_body_data()
       local result = trackingManager:addRule(json_string)
       if ( result ) then
          return ngx.OK
       end
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
    ngx.status = ngx.HTTP_BAD_REQUEST
end

return {
    manager = RequestTrackingManager:new(),
    POST_HANDLER = _API_POST_Handler,
    GET_HANDLER = _API_GET_Handler
}