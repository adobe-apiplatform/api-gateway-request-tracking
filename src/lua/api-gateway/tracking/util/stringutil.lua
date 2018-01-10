local stringutil = {}

-- http://coronalabs.com/blog/2013/04/16/lua-string-magic/
function string:split( pattern, results )
    if not results then
        results = { }
    end
    local start = 1
    local split_start, split_end = string.find( self, pattern, start )
    while split_start do
        table.insert( results, string.sub( self, start, split_start - 1 ) )
        start = split_end + 1
        split_start, split_end = string.find( self, pattern, start )
    end
    table.insert( results, string.sub( self, start ) )
    return results
end

-- http://coronalabs.com/blog/2013/04/16/lua-string-magic/
local function trim( s )
    return string.match( s,"^()%s*$") and "" or string.match(s,"^%s*(.*%S)" )
end

stringutil.trim = trim

return stringutil