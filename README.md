api-gateway-request-tracking
============================

Usage and Tracking Handler for the API Gateway

Table of Contents
=================

* [Status](#status)
* [Dependencies](#dependencies)
* [Sample Usage](#sample-usage)
* [Developer Guide](#developer-guide)

Status
======

This module is under active development and is NOT YET production ready.

Dependencies
============

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), [LuaJIT 2.0](http://luajit.org/luajit.html),
[api-gateway-hmac](https://git.corp.adobe.com/adobe-apis/api-gateway-hmac) module and
[api-gateway-request-validation](https://git.corp.adobe.com/adobe-apis/api-gateway-request-validation) module.


Sample usage
============

```nginx
TBD
```

Developer guide
===============

## Install the api-gateway first
 Since this module is running inside the `api-gateway`, make sure the api-gateway binary is installed under `/usr/local/sbin`.
 You should have 2 binaries in there: `api-gateway` and `nginx`, the latter being only a symbolik link.

## Update git submodules
```
git submodule update --init --recursive
```

## Running the tests

```
make test
```

The tests are based on the `test-nginx` library.
This library is added a git submodule under `test/resources/test-nginx/` folder, from `https://github.com/agentzh/test-nginx`.

Test files are located in `test/perl`.
The other libraries such as `Redis`, `test-nginx` are located in `test/resources/`.
Other files used when running the test are also located in `test/resources`.

When tests execute with `make tests`, a few things are happening:
* `Redis` server is compiled and installed in `target/redis-${redis_version}`. The compilation happens only once, not for every tests run, unless `make clear` is executed.
* `Redis` server is started
* `api-gateway` process is started for each test and then closed. The root folder for `api-gateway` is `target/servroot`
* some test files may output the logs to separate files under `target/test-logs`
* when tests complete successfully, `Redis` server is closed

### Prerequisites
#### MacOS
First make sure you have `Test::Nginx` installed. You can get it from CPAN with something like that:
```
sudo perl -MCPAN -e 'install Test::Nginx'
```
( ref: http://forum.nginx.org/read.php?2,185570,185679 )

Then make sure an `nginx` executable is found in path by symlinking the `api-gateway` executable:
```
ln -s /usr/local/sbin/api-gateway /usr/local/sbin/nginx
export PATH=$PATH:/usr/local/sbin/
```
For openresty you can execute:
```
export PATH=$PATH:/usr/local/openresty/nginx/sbin/
```

#### Other Linux systems:
For the moment, follow the MacOS instructions.

### Executing the tests
 To execute the test issue the following command:
 ```
 make test
 ```
 The build script builds and starts a `Redis` server, shutting it down at the end of the tests.
 The `Redis` server is compiled only the first time, and reused afterwards during the tests execution.
 The default configuration for `Redis` is found under: `test/resources/redis/redis-test.conf`

 If you want to run a single test, the following command helps:
 ```
 PATH=/usr/local/sbin:$PATH TEST_NGINX_SERVROOT=`pwd`/target/servroot TEST_NGINX_PORT=1989 prove -I ./test/resources/test-nginx/lib -r ./test/perl/api-gateway/tracking/validator/delayingRulesValidator.t
 ```
 This command only executes the test `delayingRulesValidator.t`.


#### Troubleshooting tests

When executing the tests the `test-nginx`library stores the nginx configuration under `target/servroot/`.
It's often useful to consult the logs when a test fails.
If you run a test but can't seem to find the logs you can edit the configuration for that test specifying an `error_log` location:
```
error_log ../test-logs/delayingRequestValidator_test1_error.log debug;
```

For Redis logs, you can consult `target/redis-test.log` file.

Resources
=========

* Testing Nginx : http://search.cpan.org/~agent/Test-Nginx-0.22/lib/Test/Nginx/Socket.pm
