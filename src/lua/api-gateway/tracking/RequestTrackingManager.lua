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

local KNWON_RULES = {"BLOCK", "TRACK", "DEBUG", "DELAY", "RETRY-AFTER"}

---
--  adds a new rule into the shared dictionary
function _M:addRule( json_string )
    -- TODO: add the rule into a shared dictionary corresponding to the rule's type ( BLOCK, TRACK, etc )
end

--- Returns an object with the current active rules for the given rule_type
--
-- @param rule_type BLOCK, TRACK, DEBUG, DELAY or RETRY-AFTER
--
function _M:getRulesForType(rule_type)
    if ( KNWON_RULES[rule_type] == nil ) then
        return {}
    end
    return {
        TBD = "TBD"
    }
end

return _M