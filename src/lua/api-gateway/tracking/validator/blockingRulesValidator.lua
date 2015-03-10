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


local _M = BaseValidator:new()

function _M:validate_blocking_rules(config_obj)
    -- 1. get the shared dict containing blocking rules
    -- 2. read the keys in the shared dict and compare it with the current request
end

function _M:validateRequest(obj)
    return self:validate_blocking_rules(obj)
end

return _M