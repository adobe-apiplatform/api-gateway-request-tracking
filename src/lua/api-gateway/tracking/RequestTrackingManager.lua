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

local KNWON_RULES =
    {
        BLOCK = "blocking_rules_dict",
        TRACK = "tracking_rules_dict",
        DEBUG = "debuging_rules_dict",
        DELAY = "delaying_rules_dict",
        ["RETRY-AFTER"] = "retrying_rules_dict"
    }

local last_modified_date = {
    BLOCK = -1,
    TRACK = -1,
    DEBUG = -1,
    DELAY = -1,
    ["RETRY-AFTER"] = -1
}

local cached_rules = {
    BLOCK = {}, --- holds a per worker cache of the BLOCK rules
    TRACK = {}, --- holds a per worker cache of the TRACK rules
    DEBUG = {}, --- holds a per worker cache of the DEBUG rules
    DELAY = {}, --- holds a per worker cache of the DELAY rules
    ["RETRY-AFTER"] = {} --- holds a per worker cache of the RETRY rules
}


function _M:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


local function addSingleRule(rule)
    local rule_type = string.upper(rule.action)
    if ( KNWON_RULES[rule_type] == nil ) then
        ngx.log(ngx.WARN, "Could not add rule as it doesn't match the known rules. input=" .. tostring(json_string) )
        return false
    end

    local dict_name = KNWON_RULES[rule_type]
    local dict = ngx.shared[ dict_name ]
    if ( dict == nil ) then
        ngx.log(ngx.WARN, "Shared dictionary not defined. Please define it with 'lua_shared_dict " .. tostring(dict_name) .. " 5m';")
        return false
    end

    local now = ngx.time()
    local expire_in = rule.expire_at_utc - now
    if ( expire_in <= 0 ) then
        ngx.log(ngx.WARN, "Rule already expired, will expire it form the cache too. input=" ..tostring(json_string))
        dict:set( rule.format, "", 0.001, 0)
        return false
    end

    -- TODO: make sure format doesn't have any spaces at all
    local success, err, forcible = dict:set(rule.format, rule.expire_at_utc .. " " .. rule.domain, expire_in, rule.id)
    dict:set("_lastModified", now, 0)
    return success, err, forcible
end

--- Saves the new rule(s) into the shared dictionary corresponding to the action of the rule
-- @param json_string
--     [{
--          "id": "778.v2",
--          "domain" : "cc-eco;ccstorage",
--          "format": "$publisher_org_name;$service_id",
--          "expire_at_utc": 1408065588999,
--          "action" : "block"
--      }, {...} ]
--
function _M:addRule( json_string )
    if ( json_string == nil ) then
        ngx.log(ngx.WARN, "No json_string received")
        return false
    end

    local rule = assert( cjson.decode(json_string), "Please provide a valid JSON-encoded string: " .. tostring(json_string) )

    ngx.log(ngx.DEBUG, "Adding rules:" .. tostring(json_string))

    -- check to see if the rule(s) came as an array
    if ( rule[1] ~= nil ) then
        local success, err, forcible
        for i, single_rule in pairs(rule) do
            success, err, forcible = addSingleRule(single_rule)
            if ( success == false ) then
                ngx.log(ngx.WARN, "Failed to save rule in cache. err=" .. tostring(err) ..  ". Rule:" .. tostring(cjson.encode(single_rule)))
            end
        end
        return success, err, forcible
    end


    return addSingleRule(rule)
end

--- Returns an object with the current active rules for the given rule_type
--
-- @param rule_type BLOCK, TRACK, DEBUG, DELAY or RETRY-AFTER
--
function _M:getRulesForType(rule_type)
    local rule_type = string.upper(rule_type)
    local dict_name = KNWON_RULES[rule_type]
    if ( dict_name == nil ) then
        return {}
    end
    local dict =  ngx.shared[ dict_name ]
    if ( dict == nil ) then
        ngx.log(ngx.WARN, "Shared dictionary not defined. Please define it with 'lua_shared_dict " .. tostring(dict_name) .. " 5m';")
        return {}
    end
    ngx.log(ngx.DEBUG, "Getting rules for:" .. tostring(dict_name) )
    -- 0. check if lastModifiedDate for the dict matches the local date
    local lastModified = dict:get("_lastModified")
    if ( lastModified == nil  ) then
        return cached_rules[rule_type]
    end
    -- 1. return the keys from the local variable, if lastModified date allows and if the local cache is not empty
    if ( lastModified == last_modified_date[dict_name] ) then
        return cached_rules[rule_type]
    end
    -- 2. else, read it from the shared dict
    -- docs: http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT.get_keys
    -- wil return a max os 1024 keys
    cached_rules[rule_type] = {}
    local keys = dict:get_keys()
    local val
    local id
    local domain
    local expire_at_utc
    local split_idx
    for i, key in pairs(keys) do
        if ( key ~= "_lastModified") then
            val, id = dict:get(key)
            split_idx = val:find(" ")
            cached_rules[rule_type][i] = {
                id = id,
                format = key,
                domain = val:sub(split_idx+1),
                expire_at_utc = val:sub(1, split_idx-1),
                action = string.lower(rule_type)
            }
        end
    end
    return cached_rules[rule_type]
end

return _M