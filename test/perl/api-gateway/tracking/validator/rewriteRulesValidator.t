# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(1);

plan tests => repeat_each() * (blocks() * 18);

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
    lua_shared_dict rewriting_rules_dict 5m;
_EOC_

#no_diff();
no_long_string();
run_tests();

__DATA__


=== TEST 1: test simple rewrite for remote_ip=127.0.0.1
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/blockingRequestValidator_test1_error.log info;

        location /test-rewrite {
            set_by_lua $backend "
            	local m = require 'api-gateway.tracking.validator.rewritingRulesValidator';
                local v = m:new();
                local backend = m:validateRequest();
                return backend;
            ";
            content_by_lua "ngx.say(ngx.var.backend)";

        }
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 100,
  "domain" : "127.0.0.1",
  "format": "$remote_addr",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass.com"
},{
  "id": 200,
  "domain" : "127.0.0.1",
  "format": "$remote_addr",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass2.com"
}
]
',
"GET /tracking/track",
"GET /tracking/block",
"GET /tracking/delay",
"GET /tracking/rewrite",
"GET /test-rewrite"
]
--- response_body eval
[
'{"result":"success"}
',
'{}
',
'{}
',
'{}
',
'[{"domain":"127.0.0.1","format":"$remote_addr","id":100,"action":"REWRITE","meta":"sp.adobepass.com","expire_at_utc":1583910454},{"domain":"127.0.0.1","format":"$remote_addr","id":200,"action":"REWRITE","meta":"sp.adobepass2.com","expire_at_utc":1583910454}]
',
'sp.adobepass.com
'
]
--- error_code eval
 [200, 200, 200, 200, 200, 200]
--- no_error_log
[error]

=== TEST 2: test simple rewrite for X-Test-Header: Test-Header-Value (first match wins)
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/blockingRequestValidator_test2_error.log info;

        location /test-rewrite {
            set_by_lua $backend "
              local m = require 'api-gateway.tracking.validator.rewritingRulesValidator';
                local v = m:new();
                local backend = m:validateRequest();
                return backend;
            ";
            content_by_lua "ngx.say(ngx.var.backend)";

        }
--- more_headers
X-Test-Header: Test-Header-Value
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 100,
  "domain" : "Test-Header-Value",
  "format": "$http_x_test_header",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass.com"
},{
  "id": 200,
  "domain" : "127.0.0.1",
  "format": "$remote_addr",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass2.com"
}
]
',
"GET /tracking/track",
"GET /tracking/block",
"GET /tracking/delay",
"GET /tracking/rewrite",
"GET /test-rewrite"
]
--- response_body eval
[
'{"result":"success"}
',
'{}
',
'{}
',
'{}
',
'[{"domain":"Test-Header-Value","format":"$http_x_test_header","id":100,"action":"REWRITE","meta":"sp.adobepass.com","expire_at_utc":1583910454},{"domain":"127.0.0.1","format":"$remote_addr","id":200,"action":"REWRITE","meta":"sp.adobepass2.com","expire_at_utc":1583910454}]
',
'sp.adobepass.com
'
]
--- error_code eval
 [200, 200, 200, 200, 200, 200]
--- no_error_log
[error]

=== TEST 3: test simple rewrite for query param: device-id=apple-tv1 (first match wins)
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/blockingRequestValidator_test3_error.log info;

        location /test-rewrite {
            set_by_lua $backend "
              local m = require 'api-gateway.tracking.validator.rewritingRulesValidator';
                local v = m:new();
                local backend = m:validateRequest();
                return backend;
            ";
            content_by_lua "ngx.say(ngx.var.backend)";

        }
--- more_headers
X-Test-Header: Test-Header-Value
--- pipelined_requests eval
['POST /tracking/
[{
  "id": 100,
  "domain" : "apple_tv1",
  "format": "$arg_device_id",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass.com"
},{
  "id": 200,
  "domain" : "127.0.0.1",
  "format": "$remote_addr",
  "expire_at_utc": 1583910454,
  "action" : "REWRITE",
  "meta": "sp.adobepass2.com"
}
]
',
"GET /tracking/track",
"GET /tracking/block",
"GET /tracking/delay",
"GET /tracking/rewrite",
"GET /test-rewrite?device_id=apple_tv1"
]
--- response_body eval
[
'{"result":"success"}
',
'{}
',
'{}
',
'{}
',
'[{"domain":"apple_tv1","format":"$arg_device_id","id":100,"action":"REWRITE","meta":"sp.adobepass.com","expire_at_utc":1583910454},{"domain":"127.0.0.1","format":"$remote_addr","id":200,"action":"REWRITE","meta":"sp.adobepass2.com","expire_at_utc":1583910454}]
',
'sp.adobepass.com
'
]
--- error_code eval
 [200, 200, 200, 200, 200, 200]
--- no_error_log
[error]
