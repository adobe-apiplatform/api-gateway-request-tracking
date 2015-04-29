# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(1);

plan tests => repeat_each() * (blocks() * 15) ;

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
_EOC_

#no_diff();
no_long_string();
run_tests();

__DATA__


=== TEST 1: test that we can block the request
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/blockingRequestValidator_test1_error.log debug;

        set $validator_custom_error_responses '{
            "BLOCK_REQUEST" : { "http_status" : 429, "error_code" : 429050, "message" : "{\\"error_code\\":\\"429050\\",\\"message\\":\\"Too many requests\\"}","headers" :  { "content-type" : "application/json" } }
        }';

        location ~ /protected-with-blocking-rules/(.*)$ {
            set $subpath $1;
            set $validate_service_plan "on; path=/validate_service_plan; order=1; ";

            access_by_lua "ngx.apiGateway.validation.validateRequest()";
            content_by_lua "ngx.say('not-blocked')";

        }
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 222,
  "domain" : "pub1;subpath-to-block",
  "format": "$publisher_org_name;$subpath",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
},
{
  "id": 223,
  "domain" : "pub1;subpath-to-block-2",
  "format": "$publisher_org_name;$subpath",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
}]
',
"GET /tracking/block",
"GET /protected-with-blocking-rules/subpath-to-block",
"GET /protected-with-blocking-rules/subpath-to-block-2",
"GET /protected-with-blocking-rules/valid-path/and-subpath"
]
--- response_body eval
[
'{"result":"success"}
',
'[{"domain":"pub1;subpath-to-block","format":"$publisher_org_name;$subpath","id":222,"action":"BLOCK","expire_at_utc":"1583910454"},{"domain":"pub1;subpath-to-block-2","format":"$publisher_org_name;$subpath","id":223,"action":"BLOCK","expire_at_utc":"1583910454"}]
',
'{"error_code":"429050","message":"Too many requests"}
',
'{"error_code":"429050","message":"Too many requests"}
',
'not-blocked
'
]
--- error_code eval
 [200, 200, 429, 429, 200]
--- no_error_log
[error]



=== TEST 2: test that we can block the request using variables set by other validators
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;

        error_log ../test-logs/blockingRequestValidator_test2_error.log debug;

        set $publisher_org_name 'pub1';

        location /mock-validate-api-key1 {
            internal;
            content_by_lua '
                ngx.ctx.app_name = "app1"
                ngx.header["Response-Time"] = ngx.now() - ngx.req.start_time()
                ngx.say("OK")
            ';
        }

        location /mock-validate-api-key2 {
            internal;
            content_by_lua '
                ngx.ctx.app_name = "app2"
                ngx.header["Response-Time"] = ngx.now() - ngx.req.start_time()
                ngx.say("OK")
            ';
        }
        location /mock-validate-api-key3 {
            internal;
            set $app_name app3;
            content_by_lua '
                ngx.ctx.app_name = "app3"
                ngx.status = 401
                ngx.print("mocking invalid request")
                ngx.exit(ngx.OK)
            ';
        }


        location ~ /protected-with-blocking-rules/(.*)$ {
            set $subpath $1;
            set $request_validator_1 "on; path=/$subpath; order=1;";
            set $validate_service_plan "on; path=/validate_service_plan; order=2; ";

            access_by_lua "ngx.apiGateway.validation.validateRequest()";
            content_by_lua "ngx.say('not-blocked')";

        }
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 222,
  "domain" : "pub1;app2",
  "format": "$publisher_org_name;$app_name",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
},
{
  "id": 223,
  "domain" : "pub1;app3",
  "format": "$publisher_org_name;$app_name",
  "expire_at_utc": 1583910454,
  "action" : "BLOCK"
}]
',
"GET /tracking/block",
"GET /protected-with-blocking-rules/mock-validate-api-key1",
"GET /protected-with-blocking-rules/mock-validate-api-key2",
"GET /protected-with-blocking-rules/mock-validate-api-key3"
]
--- response_body eval
[
'{"result":"success"}
',
'[{"domain":"pub1;app2","format":"$publisher_org_name;$app_name","id":222,"action":"BLOCK","expire_at_utc":"1583910454"},{"domain":"pub1;app3","format":"$publisher_org_name;$app_name","id":223,"action":"BLOCK","expire_at_utc":"1583910454"}]
',
'not-blocked
',
'{"error_code":"429050","message":"Too many requests"}

',
'mocking invalid request
'
]
--- error_code_like eval
 [200, 200, 200, 429, 401]
--- no_error_log
[error]


