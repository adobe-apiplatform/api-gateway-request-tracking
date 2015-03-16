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

        local function loadrequire(module)
            local function requiref(module)
                require(module)
            end
            local res = pcall(requiref,module)
            if not(res) then
                ngx.log(ngx.WARN, "Module ", module, " was not found.")
                return nil
            end
            return require(module)
        end
        -- when the ZmqModule is not present the script does not break
        local ZmqLogger = loadrequire("api-gateway.zmq.ZeroMQLogger")

        if (not ngx.apiGateway.zmqLogger ) and ( ZmqLogger ~= nil ) then
            ngx.log(ngx.INFO, "Starting new ZmqLogger on pid ", tostring(ngx.worker.pid()), " ...")
            ngx.apiGateway.zmqLogger = ZmqLogger:new()
            ngx.apiGateway.zmqLogger:connect(ZmqLogger.SOCKET_TYPE.ZMQ_PUB, "ipc:///tmp/nginx_queue_listen")
        end
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


=== TEST 1: test that we send the correct message out to the message queue
--- http_config eval: $::HttpConfig
--- config
        include ../../api-gateway/default_validators.conf;
        include ../../api-gateway/tracking_service.conf;
        set $publisher_org_name 'pub1';

        error_log ../test-logs/trackingRulesLogger_test1_error.log debug;

        location ~ /t/(.*)$ {
            set $consumer_org_name $1;
            set $validate_service_plan "on; path=/validate_service_plan; order=1; ";

            access_by_lua "ngx.apiGateway.validation.validateRequest()";
            content_by_lua "ngx.say('not-blocked')";
            log_by_lua '
                ngx.apiGateway.tracking.track()
            ';
        }
--- pipelined_requests eval
['POST /tracking/
{
  "id": 111,
  "domain" : "*;*;200;*",
  "format": "$publisher_org_name;$consumer_org_name;$status;$request_method",
  "expire_at_utc": 1583910454,
  "action" : "TRACK"
}
',
"GET /tracking/track",
"GET /t/org1",
"POST /t/org2",
"OPTIONS /t/org1"
]
--- response_body eval
[
'{"result":"success"}
',
'[{"domain":"*;*;200;*","format":"$publisher_org_name;$consumer_org_name;$status;$request_method","id":111,"action":"TRACK","expire_at_utc":"1583910454"}]
',
'not-blocked
',
'not-blocked
',
'not-blocked
'
]
--- error_code_like eval
 [200, 200, 200, 200, 200]
--- no_error_log
[error]

