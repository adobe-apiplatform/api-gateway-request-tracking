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
-- Exposes an utility function to retrieve a request variable.
--

local _M = {}
local RESPONSE_STATUS_VARIABLE_NAME = "response_status"

--- Returns the value of the variable by looking first into cache table, the into the ngx.ctx scope and then into ngx.var scope.
-- An optional cache table may be provided to look first in the cache
-- @param request_var the name of the variable to look for
-- @param cache table used for local caching of variables
--
function _M:getRequestVariable(request_var, cache)
    -- read it first from the local cache table
    if cache ~= nil and cache[request_var] ~= nil then
        return cache[request_var]
    end

    local ctx_var = ngx.ctx[request_var]
    if ctx_var ~= nil then
        cache[request_var] = ctx_var
        return ctx_var
    end

    local ngx_var = ngx.var[request_var]
    cache[request_var] = ngx_var
    return ngx_var
end

--- Returns the value of the variable by looking first into cache table, then into response status.
-- An optional cache table may be provided to look first in the cache
-- @param response_var the name of the variable to look for
-- @param cache table used for local caching of variables
function _M:getResponseVariable(response_var, cache)
    if cache ~= nil and cache[response_var] ~= nil then
        return cache[response_var]
    end

    local response_status = tostring(ngx.status)
    if response_var == RESPONSE_STATUS_VARIABLE_NAME and response_status ~= nil then
        cache[response_var] = response_status
        return response_status
    end

    return nil
end

return _M
