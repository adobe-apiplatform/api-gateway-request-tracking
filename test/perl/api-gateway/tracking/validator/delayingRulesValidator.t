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


=== TEST 1: test that we can delay the request
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/delayingRequestValidator_test1_error.log debug;

        location ~ /protected-with-delaying-rules/(.*)$ {
            set $subpath $1;
            set $validate_service_plan "on; path=/validate_service_plan; order=1; ";

            access_by_lua "ngx.apiGateway.validation.validateRequest()";
            content_by_lua 'ngx.say(ngx.var.validate_request_response_time)';

        }
--- timeout: 10
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 222,
  "domain" : "pub1;subpath-to-delay",
  "format": "$publisher_org_name;$subpath",
  "expire_at_utc": 1583910454,
  "action" : "DELAY"
},
{
  "id": 223,
  "domain" : "pub1;subpath-to-delay-2",
  "format": "$publisher_org_name;$subpath",
  "expire_at_utc": 1583910454,
  "action" : "DELAY"
}]
',
"GET /tracking/delay",
"GET /protected-with-delaying-rules/subpath-to-delay",
"GET /protected-with-delaying-rules/subpath-to-delay-2",
"GET /protected-with-delaying-rules/valid-path/and-subpath"
]
--- response_body_like eval
[
'\{"result":"success"\}.*',
'.*{"domain":"pub1;subpath-to-delay","format":"\$publisher_org_name;\$subpath","id":222,"action":"DELAY","expire_at_utc":"1583910454"},{"domain":"pub1;subpath-to-delay-2","format":"\$publisher_org_name;\$subpath","id":223,"action":"DELAY","expire_at_utc":"1583910454"}.*',
'(\d{2,4})+',
'(\d{2,4})+',
"0
"
]
--- error_code_like eval
 [200, 200, 200, 200, 200]
--- no_error_log
[error]


