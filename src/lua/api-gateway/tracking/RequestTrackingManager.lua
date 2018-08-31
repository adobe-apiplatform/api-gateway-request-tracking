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
-- Exposes utility functions to add/remove Tracking rules ( BLOCK, TRACK, DEBUG, DELAY, RETRY-AFTER )
--
-- You should map this to a REST API Endpoint:
--
--  POST /tracking/{rule_type}
--
--  GET /tracking/{rule_type}
--
-- User: ddascal
-- Date: 09/03/15
-- Time: 21:32
--
local cjson = require "cjson"

local _M = {}

local KNOWN_RULES =
{
    BLOCK   = "blocking_rules_dict",
    TRACK   = "tracking_rules_dict",
    DEBUG   = "debuging_rules_dict",
    DELAY   = "delaying_rules_dict",
    REWRITE = "rewriting_rules_dict",
    ["RETRY-AFTER"] = "retrying_rules_dict"
}

local last_modified_date = {
    BLOCK   = -1,
    TRACK   = -1,
    DEBUG   = -1,
    DELAY   = -1,
    REWRITE = -1,
    ["RETRY-AFTER"] = -1
}

local cached_rules = {
    BLOCK   = {}, --- holds a per worker cache of the BLOCK rules
    TRACK   = {}, --- holds a per worker cache of the TRACK rules
    DEBUG   = {}, --- holds a per worker cache of the DEBUG rules
    DELAY   = {}, --- holds a per worker cache of the DELAY rules
    REWRITE = {}, --- holds a per worker cache of the REWRITE rules
    ["RETRY-AFTER"] = {} --- holds a per worker cache of the RETRY rules
}

--- separates each variable in the domain and format
-- i.e. "domain" : "cc-eco;ccstorage"
-- i.e. "format": "$publisher_org_name;$service_id"
local FORMAT_SEPARATOR = ";"


function _M:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


local function addSingleRule(rule, json_string)
    local rule_type = string.upper(rule.action)
    if (KNOWN_RULES[rule_type] == nil) then
        ngx.log(ngx.WARN, "Could not add rule as it doesn't match the known rules. input=" .. tostring(json_string))
        return false
    end

    local dict_name = KNOWN_RULES[rule_type]
    local dict = ngx.shared[dict_name]
    if (dict == nil) then
        ngx.log(ngx.WARN, "Shared dictionary not defined. Please define it with 'lua_shared_dict " .. tostring(dict_name) .. " 5m';")
        return false
    end

    local now = ngx.now() -- floating-point number for the elapsed time in seconds (including milliseconds as the decimal part)
    local expire_in = rule.expire_at_utc - now
    if (expire_in <= 0) then
        ngx.log(ngx.WARN, "Rule already expired, will expire it form the cache too. input=" .. tostring(json_string))
        dict:set(rule.id .. " " .. rule.domain, "", 0.001, 0)
        return false
    end

    -- TODO: make sure format doesn't have any spaces at all
    ngx.var.track_id = rule.id;
    local success, err, forcible = dict:set(rule.id .. " " .. rule.domain, cjson.encode(rule), expire_in, (rule.data or 0) )
    ngx.log(ngx.WARN, "New blocking rule added at:" .. tostring(ngx.var.msec) .. ", expires in:" .. tostring(expire_in) .. ", Rule:" .. tostring(cjson.encode(rule)))
    dict:set("_lastModified", now, 0)
    return success, err, forcible
end

--- Saves the new rule(s) into the shared dictionary corresponding to the action of the rule
-- @param json_string
-- [{
-- "id": "778.v2",
-- "domain" : "cc-eco;ccstorage",
-- "format": "$publisher_org_name;$service_id",
-- "expire_at_utc": 1408065588999,
-- "action" : "block",
-- "data" : 100
-- }, {...} ]
--
function _M:addRule(json_string)
    if (json_string == nil) then
        ngx.log(ngx.WARN, "No json_string received")
        return false
    end

    local rule = assert(cjson.decode(json_string), "Please provide a valid JSON-encoded string: " .. tostring(json_string))

    ngx.log(ngx.DEBUG, "Adding rules:" .. tostring(json_string))

    -- check to see if the rule(s) came as an array
    if (rule[1] ~= nil) then
        local success, err, forcible
        for i, single_rule in pairs(rule) do
            success, err, forcible = addSingleRule(single_rule, json_string)
            if (success == false) then
                ngx.log(ngx.WARN, "Failed to save rule in cache. err=" .. tostring(err) .. ". Rule:" .. tostring(cjson.encode(single_rule)))
            end
        end
        return success, err, forcible
    end


    return addSingleRule(rule, json_string)
end

--- Returns an object with the current active rules for the given rule_type
--
-- @param rule_type BLOCK, TRACK, DEBUG, DELAY or RETRY-AFTER
--
function _M:getRulesForType(rule_type)
    local rule_type = string.upper(rule_type)
    local dict_name = KNOWN_RULES[rule_type]
    if (dict_name == nil) then
        return {}
    end
    local dict = ngx.shared[dict_name]
    if (dict == nil) then
        ngx.log(ngx.WARN, "Shared dictionary not defined. Please define it with 'lua_shared_dict " .. tostring(dict_name) .. " 5m';")
        return {}
    end
    ngx.log(ngx.DEBUG, "Getting rules for:" .. tostring(dict_name))
    -- 0. check if lastModifiedDate for the dict matches the local date
    local lastModified = dict:get("_lastModified")
    if (lastModified == nil) then
        ngx.log(ngx.DEBUG, "Returning the rules from the cache as lastModified is nil in the dict named=", tostring(dict_name))
        return cached_rules[rule_type]
    end
    -- 1. return the keys from the local variable, if lastModified date allows and if the local cache is not empty
    if (lastModified == last_modified_date[dict_name]) then
        ngx.log(ngx.DEBUG, "Returning the rules from the cache as the dict hasn't been updated in the dict named=", tostring(dict_name))
        return cached_rules[rule_type]
    end
    -- 2. else, read it from the shared dict
    -- docs: http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT.get_keys
    -- will return a max of 1024 keys
    cached_rules[rule_type] = {}
    local keys = dict:get_keys(0)
    local val_string, val, data, domain, expire_at_utc, id, meta, decode_ok
    local i, domain_split_idx
    for i, key in pairs(keys) do
        val_string, data = dict:get(key)
        if (val_string ~= nil and key ~= "_lastModified") then
            domain_split_idx = key:find(" ")
            decode_ok,  val = pcall(cjson.decode, val_string)
            if ( decode_ok and val ~= nil and domain_split_idx ~= nil ) then
                id = key:sub(1, domain_split_idx - 1)
                cached_rules[rule_type][i] = {
                    id              = tonumber(id) or id, -- try to convert it to a number, but if it's not keep the string
                    domain          = key:sub(domain_split_idx + 1),
                    format          = val["format"],
                    expire_at_utc   = val["expire_at_utc"],
                    action          = string.upper(rule_type),
                    meta            = val["meta"],
                    data            = data
                }
            else
                ngx.log(ngx.WARN, "Could not read rule from shared_dict:", tostring(dict_name), "format=", tostring(format), ", key=", tostring(key), ", val=", tostring(val))
            end
        end
    end
    return cached_rules[rule_type]
end

--- Return (boolean, string ) uple. If it's a positive match it returns the componded string value otherwise it returns false
-- Example
-- format  = $publisher_org_name;$service_id;$api_key;
-- domain = pub1;*;*;
--
-- A request where variables publisher_org_name=pub1, service_id=serv1 and api_key=key1 would return :
-- true, "pub1;serv1;key1;"
--
-- A failed match would be when $publisher_org_name is not "pub1". In this case the method returns false
--
-- @param vars table with variable names
-- @param domains table with the domain values for the variables
-- @param cache table used to cache variables
-- @param separator format separator
--
local function matchVarsWithDomains(vars, domains, cache, separator)
    local str = ""
    if (vars == nil or domains == nil) then
        ngx.log(ngx.DEBUG, "Vars or Domains are nil. Quitting...")
        return false, str
    end

    local vars_length = table.getn(vars)
    local domains_length = table.getn(domains)
    if (vars_length ~= domains_length) then
        ngx.log(ngx.DEBUG, "Vars and Domains are not equal in numbers. Quitting...")
        return false, str
    end

    ngx.log(ngx.DEBUG, "Comparing ", vars_length , " vars with ", domains_length, " domains.")
    local v, d, i
    for i = 1, domains_length do
        -- ngx.log(ngx.DEBUG, "VAR " , tostring(i))
        local variableManager = ngx.apiGateway.tracking.variableManager
        v = variableManager:getRequestVariable(vars[i], cache)

        local enable_throttling_using_response_vars = (ngx.var.enable_throttling_using_response_vars == "true")
        if v == nil and enable_throttling_using_response_vars == true then
            v = variableManager:getResponseVariable(vars[i], cache)
        end

        if v == nil then
            return false, str
        end

        -- ngx.log(ngx.DEBUG, "VAL=", v)
        d = domains[i]
        -- ngx.log(ngx.DEBUG, "DOMAIN=", d)
        if (d == "*") then
            str = str .. v .. separator
        else
            if d ~= v then
                return false, str
            end
            str = str .. v .. separator
        end
    end
    return true, str
end

local function extractMatchedItemsFromIterator(iterator, named_var)
    local counter = 0
    local match_table = {}
    while true do
        local m, err = iterator()
        if err then
            ngx.log(ngx.ERR, "Domain Iterator error: ", err)
            return {}
        end

        if not m or counter > 100 then
            -- no match found (any more)
            break
        end
        counter = counter + 1
        match_table[counter] = m[named_var]
    end
    return match_table
end

---
-- Returns an object with only the rules matching the current request variables. It's up to the caller to decide what to do with the result
-- @param rule_type BLOCK, TRACK, DEBUG, DELAY or RETRY-AFTER
-- @param separator For instance ";". It's the character separating the values and variables
-- @param exit_on_first_match Default:true. When true the method exits on the first match.
-- This is useful for BLOCK, DELAY or RETRY-AFTER behaviours when the first match would alter the request status.
-- For tracking purposes, fail_fast would be false so that all matches are reported
--
function _M:getMatchingRulesForRequest(rule_type, separator, exit_on_first_match)
    local var_cache = {} -- table used to cache variables once read
    local format_separator = separator or FORMAT_SEPARATOR
    local fail_fast = true
    if (exit_on_first_match == false) then
        fail_fast = false
    end

    ngx.log(ngx.DEBUG, "Getting matching rules for:", rule_type, ", separator=", format_separator, " exit_on_first_match=", tostring(fail_fast))
    local active_rules = self:getRulesForType(rule_type)

    local format, domain, expire_at_utc, action, id, data, meta, match_success, compiled_domain
    local matched_variables, matched_domains, err
    local matched_rules_counter = 0
    local matched_rules = {}
    for i, rule in pairs(active_rules) do
        ngx.log(ngx.DEBUG, "... probing rule id=", tostring(rule.id) )
        matched_variables = {}
        id = rule.id
        format = rule.format
        domain = rule.domain
        action = rule.action
        meta   = rule.meta
        expire_at_utc = rule.expire_at_utc
        data = rule.data
        ngx.log(ngx.DEBUG, "... matching format=", tostring(format), " with domain=", tostring(domain), " id=", tostring(id))
        if (format ~= nil and domain ~= nil and action ~= nil and expire_at_utc ~= nil and id ~= nil) then
            -- j - enable PCRE JIT compilation
            -- o - compile once
            matched_domains = {}
            matched_variables = {}
            local iterator, err = ngx.re.gmatch(domain, "(?<domains>[^;]+)" .. format_separator .. "?", "jo")

            if (not iterator) then
                ngx.log(ngx.WARN, "Could not extract domain values for : [", tostring(domain), "]. Error:", tostring(err))
            else
                matched_domains = extractMatchedItemsFromIterator(iterator, "domains")
                --[[                for k, v in pairs(matched_domains) do
                                    ngx.log(ngx.DEBUG, "MATCHED DOMAIN k=", tostring(k), ", v=", tostring(v))
                                end]]

                local iterator, err = ngx.re.gmatch(format, "\\$(?<vars>[\\-\\w]+).?", "jo")
                if (not iterator) then
                    ngx.log(ngx.WARN, "Could not extract format variables for : [", tostring(format), "]. Error:", tostring(err), ", match table=", tostring(matched_variables))
                else
                    matched_variables = extractMatchedItemsFromIterator(iterator, "vars")
                    --[[for k, v in pairs(matched_variables) do
                        ngx.log(ngx.DEBUG, "MATCHED VAR k=", tostring(k), ", v=", tostring(v))
                    end]]
                    match_success, compiled_domain = matchVarsWithDomains(matched_variables, matched_domains, var_cache, format_separator)
                    if (match_success == true) then
                        ngx.log(ngx.DEBUG, "Found a matching rule for id=", tostring(id), ", at i=", tostring(i), " compiled_domain=", tostring(compiled_domain))
                        matched_rules_counter = matched_rules_counter + 1
                        matched_rules[matched_rules_counter] = {
                            id = id,
                            format = format,
                            domain = compiled_domain,
                            data = data,
                            meta = meta,
                            expire_at_utc = expire_at_utc
                        }
                        if fail_fast == true then
                            return matched_rules[matched_rules_counter]
                        end
                    end
                    ngx.log(ngx.DEBUG, "... rule doesn't match. id=", tostring(rule.id))
                end
            end
        end
    end
    if ( next(matched_rules) == nil ) then
        return nil
    end
    return matched_rules
end

return _M
