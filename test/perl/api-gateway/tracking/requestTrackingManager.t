# /*
#  * Copyright 2016 Adobe Systems Incorporated. All rights reserved.
#  *
#  * This file is licensed to you under the Apache License, Version 2.0 (the "License");
#  * you may not use this file except in compliance with the License.  You may obtain a copy of the License at
#  *
#  *   http://www.apache.org/licenses/LICENSE-2.0
#  *
#  * Unless required by applicable law or agreed to in writing, software distributed under the License
#  *  is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR RESPRESENTATIONS OF ANY KIND,
#  *  either express or implied.  See the License for the specific language governing permissions and
#  *  limitations under the License.
# */
# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use strict;
use warnings;
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(1);

plan tests => repeat_each() * (blocks() * 9);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    # lua_package_path "$pwd/scripts/?.lua;;";
    lua_package_path "src/lua/?.lua;/usr/local/lib/lua/?.lua;;";
    init_by_lua '
        local v = require "jit.v"
        v.on("$Test::Nginx::Util::ErrLogFile")
        require "resty.core"
    ';
     init_worker_by_lua '
        ngx.apiGateway = ngx.apiGateway or {}
        ngx.apiGateway.validation = require "api-gateway.validation.factory"
        ngx.apiGateway.tracking = require "api-gateway.tracking.factory"
     ';
    include "$pwd/conf.d/http.d/*.conf";
    upstream cache_rw_backend {
    	server 127.0.0.1:6379;
    }
    upstream cache_read_only_backend { # Default config for redis health check test
        server 127.0.0.1:6379;
    }
    lua_shared_dict blocking_rules_dict 5m;
    lua_shared_dict tracking_rules_dict 5m;
    lua_shared_dict debugging_rules_dict 5m;
    lua_shared_dict delaying_rules_dict 5m;
    lua_shared_dict retrying_rules_dict 5m;

    client_body_temp_path /tmp/;
    proxy_temp_path /tmp/;
    fastcgi_temp_path /tmp/;
_EOC_

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: test that there are no default rules
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test1_error.log warn;
--- more_headers
X-Test: test
--- request
GET /tracking/track
--- response_body eval
["{}\n"]
--- error_code: 200
--- no_error_log
[error]


=== TEST 2: test that we can add new rules and persist them
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test2_error.log debug;
--- pipelined_requests eval
['POST /tracking/
{
  "id": 222,
  "domain" : "cc-eco;comcast;*",
  "format": "$publisher_org_name;$consumer_org_name;$api_key",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
}
',
'POST /tracking/
{
  "id": 223,
  "domain" : "cc-eco;comcast",
  "format": "$publisher_org_name;$consumer_org_name",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
}
',
'POST /tracking/
{
  "id": 223,
  "domain" : "cc-eco;comcast",
  "format": "$publisher_org_name;$consumer_org_name",
  "expire_at_utc": 1583910454,
  "action" : "DELAY",
  "data" : 123
}
',
"GET /tracking/track",
"GET /tracking/block",
"GET /tracking/delay",
'POST /tracking/
{
  "id": 333,
  "domain" : "cc-eco;comcast;*",
  "format": "$publisher_org_name;$consumer_org_name;$api_plan",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
}
',
"GET /tracking/track"]
--- response_body eval
[
'{"result":"success"}
',
'{"result":"success"}
',
'{"result":"success"}
',
'[{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_key","id":222,"action":"TRACK","expire_at_utc":1583910454}]
',
'[{"domain":"cc-eco;comcast","format":"$publisher_org_name;$consumer_org_name","id":223,"action":"BLOCK","expire_at_utc":1583910454}]
',
'[{"domain":"cc-eco;comcast","format":"$publisher_org_name;$consumer_org_name","data":123,"id":223,"action":"DELAY","expire_at_utc":1583910454}]
',
'{"result":"success"}
',
'[{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_key","id":222,"action":"TRACK","expire_at_utc":1583910454},{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_plan","id":333,"action":"TRACK","expire_at_utc":1583910454}]
'
]
--- error_code eval
 [200, 200, 200, 200, 200, 200, 200, 200]
--- no_error_log
[error]



=== TEST 3: test that we can add a batch of rules at once
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test3_error.log debug;
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 222,
  "domain" : "cc-eco;comcast;*",
  "format": "$publisher_org_name;$consumer_org_name;$api_key",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
},
{
  "id": 223,
  "domain" : "cc-eco;comcast",
  "format": "$publisher_org_name;$consumer_org_name",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
}]
',
"GET /tracking/track",
"GET /tracking/block",
'POST /tracking/
[{
  "id": 333,
  "domain" : "cc-eco;comcast;*",
  "format": "$publisher_org_name;$consumer_org_name;$api_plan",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
},{
  "id": 444,
  "domain" : "cc-eco;comcast;*",
  "format": "$publisher_org_name;$consumer_org_name;$app_name",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
}
]',
"GET /tracking/track"]
--- response_body eval
[
'{"result":"success"}
',
'[{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_key","id":222,"action":"TRACK","expire_at_utc":1583910454}]
',
'[{"domain":"cc-eco;comcast","format":"$publisher_org_name;$consumer_org_name","id":223,"action":"BLOCK","expire_at_utc":1583910454}]
',
'{"result":"success"}
',
'[{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_key","id":222,"action":"TRACK","expire_at_utc":1583910454},{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$api_plan","id":333,"action":"TRACK","expire_at_utc":1583910454},{"domain":"cc-eco;comcast;*","format":"$publisher_org_name;$consumer_org_name;$app_name","id":444,"action":"TRACK","expire_at_utc":1583910454}]
'
]
--- error_code_like eval
 [200, 200, 200, 200, 200, 200]
--- no_error_log
[error]



=== TEST 4: test expiration time for the rules
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test4_error.log debug;

        location /test-expiration {
            set_by_lua $generated_expires_at '
                        local ts = ngx.now()
                        local utcdate   = os.date("!*t", ts)
                        local localdate = os.date("*t", ts)
                        localdate.isdst = false -- this is the trick
                        local offset = os.difftime(os.time(localdate), os.time(utcdate))

                        ngx.log(ngx.WARN, "NGX LOCAL TIME = " .. ngx.localtime() .. ", UTC=" .. ngx.utctime() .. ", ngx.now=" ..ngx.now() .. ", ngx.time=" .. ngx.time() .. ", http_time=" .. ngx.http_time( ngx.time() )  )
                        -- NOTE: assumption is that ngx.now() and ngx.time() is UTC
                        -- expire in 1 second
                        return ( ngx.time() + 1 )
            ';
            set $block_1 '{"domain":"cc-eco;comcast","format":"publisher_org_name;consumer_org_name","id":223,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            content_by_lua '
                local trackingManager = ngx.apiGateway.tracking.manager
                trackingManager:addRule(ngx.var.block_1)
                local blocking_rules = trackingManager:getRulesForType("block")
                assert( table.getn(blocking_rules) == 1, "ONE blocking rule should exists")
                assert( blocking_rules[1]["id"] == 223, "Blocking rule should have been saved")
                ngx.sleep(1.5)
                blocking_rules = trackingManager:getRulesForType("block")
                assert( table.getn(blocking_rules) == 0, "Blocking rules should expire")
                ngx.say("OK")
            ';
        }
--- more_headers
X-Test: test
--- request
GET /test-expiration
--- response_body eval
["OK\n"]
--- error_code: 200
--- no_error_log
[error]



=== TEST 5: test that rules match request variables
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test5_error.log debug;

        set $publisher_org_name pub1;

        location /test-request-match {
            set_by_lua $generated_expires_at '
                        -- NOTE: assumption is that ngx.now() and ngx.time() is UTC
                        -- expire in 1 second
                        return ( ngx.time() + 1 )
            ';
            set $block_1 '{"domain":"pub1;consumer8;","format":"!publisher_org_name;!consumer_org_name;","id":221,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_2 '{"domain":"pub1;consumer2;","format":"!publisher_org_name;!consumer_org_name;","id":222,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_3 '{"domain":"pub1;consumer3;","format":"!publisher_org_name;!consumer_org_name;","id":223,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_7 '{"domain":"pub1;consumer1;","format":"!publisher_org_name;!consumer_org_name;","id":227,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_4 '{"domain":"pub1;consumer4;","format":"!publisher_org_name;!consumer_org_name;","id":224,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_5 '{"domain":"pub1;consumer5;","format":"!publisher_org_name;!consumer_org_name;","id":225,"action":"BLOCK","expire_at_utc":$generated_expires_at}';
            set $block_6 '{"domain":"pub1;consumer6;","format":"!publisher_org_name;!consumer_org_name;","id":226,"action":"BLOCK","expire_at_utc":$generated_expires_at}';

            # track all consumers for pub1 publisher, but also track all consumers in general
            set $track_1 '{"domain":"pub1;*;","format":"!publisher_org_name;!consumer_org_name;","id":321,"action":"TRACK","expire_at_utc":$generated_expires_at}';
            set $track_2 '{"domain":"*","format":"!consumer_org_name","id":322,"action":"TRACK","expire_at_utc":$generated_expires_at}';

            set $consumer_org_name consumer6;

            content_by_lua '
                local trackingManager = ngx.apiGateway.tracking.manager
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_1,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_2,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_3,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_4,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_5,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_6,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.block_7,"!", "$$", "jo"))

                trackingManager:addRule(ngx.re.gsub(ngx.var.track_1,"!", "$$", "jo"))
                trackingManager:addRule(ngx.re.gsub(ngx.var.track_2,"!", "$$", "jo"))

                local blocking_rules = trackingManager:getMatchingRulesForRequest("block",";", true)
                assert( blocking_rules ~= nil, "At least one blocking rule should exists. " )
                assert( blocking_rules["id"] == 226, "Blocking rule 226 should be matched. Found: ", blocking_rules["id"])

                local stop_after_first_match = false
                local tracking_rules = trackingManager:getMatchingRulesForRequest("track", ";", stop_after_first_match)
                local n = table.getn(tracking_rules)
                assert( n == 2, "TWO tracking rules should have matched on this request. Found:" .. tostring(n))
                assert( tracking_rules[1].domain == "pub1;consumer6;", "Wrong domain value. Expected: pub1;consumer6;  Found:" .. tracking_rules[1].domain )
                assert( tracking_rules[2].domain == "consumer6;", "Wrong domain value. Expected: consumer6;  Found:" .. tracking_rules[2].domain )

                ngx.sleep(1.5)
                blocking_rules = trackingManager:getMatchingRulesForRequest("block")
                assert( blocking_rules == nil, "Blocking rule should have expired." )

                tracking_rules = trackingManager:getMatchingRulesForRequest("track", ";", stop_after_first_match)
                assert( tracking_rules == nil, "Tracking rules should have expired." )

                ngx.say("OK")
            ';
        }
--- more_headers
X-Test: test
--- request
GET /test-request-match
--- response_body eval
["OK\n"]
--- error_code: 200
--- no_error_log
[error]


=== TEST 6: test with an invalid dictionary key/value pair
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/tracking_service.conf;
        error_log ../test-logs/requestTrackingManager_test6_error.log debug;

        location /add-invalid-entries {
            set_by_lua_block $generated_expires_at {
                        -- NOTE: assumption is that ngx.now() and ngx.time() is UTC
                        -- expire in 1 second
                        return ( ngx.time() + 1 )
            }

            content_by_lua_block {
                local trackingManager = ngx.apiGateway.tracking.manager
                local dict_name = "blocking_rules_dict"
                local dict = ngx.shared[dict_name]
                assert( dict ~= nil,  "Shared dictionary not defined. Please define it with 'lua_shared_dict " .. tostring(dict_name) .. " 5m';")

                dict:set("_lastModified", ngx.now(), 0)
                ngx.sleep(0.5)

                -- add an invalid empty string in the dictionary
                dict:add("key1","")

                local r = trackingManager:getRulesForType("BLOCK")
                assert( r ~= nil, "Results should not be nil")
                ngx.say(tostring(r[1]))
                ngx.say("added invalid value")
            }

        }
--- more_headers
X-Test: test
--- pipelined_requests eval
[
"GET /add-invalid-entries",
"GET /tracking/block"
]
--- response_body eval
[
"added invalid value\n",
"{}\n"
]
--- error_code_like eval
 [200,200]
--- no_error_log
[error]




