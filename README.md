api-gateway-request-tracking
============================

Usage and Tracking Handler for the API Gateway.


Table of Contents
=================

* [Status](#status)
* [Dependencies](#dependencies)
* [Design considerations](#design-considerations)
* [Definitions](#definitions)
* [Sample Usage](#sample-usage)
* [Developer Guide](#developer-guide)

Status
======

This module is under active development and is considered production ready.

Dependencies
============

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), [LuaJIT 2.0](http://luajit.org/luajit.html),
[api-gateway-zmq-logger](https://github.com/adobe-apiplatform/api-gateway-zmq-logger),
[api-gateway-request-validation](https://github.com/adobe-apiplatform/api-gateway-request-validation), and [api-gateway-hmac](https://github.com/adobe-apiplatform/api-gateway-hmac) module.

Design considerations
=======================

This module is usually used for enforcing rate limiting and throttling policies. 
It is by design that business rules for the policies are not implemented in this module. A different microservice should be responsible for obtaining usage information, tracking the requests, and then notifying the gateways when an action needs to be taken.  

Bellow are the design principles used by this module:

 * **Async**. Requests are not blocked while checking the remaining quotas.
   * Quotas are tracked into a centralized microservice.
   * The microservice should notify all the Gateway nodes when a limit is reached. 
   * The Gateways enforce policies but are not aware of the business logic of the policies.
 * **Non blocking**. The impact on the request time should be as low as possible. 
   Some actions are still blocking when stopping or delaying requests but for other cases such as reporting the usage, actions should be non-blocking.   
 * **High-performance**. Support hundreds of thousands of requests per second.
   * Enforcing limits should not downgrade the performance of the Gateway.
     * It should avoid congesting the network.
     * It should avoid congesting the number of available ports.
     * It should cause no downtime of the Gateway.
 * **Adaptive**. Nodes may come up or go down at any time.
 * There's an allowance of 2 - 5% overflow on the imposed limits. ( a limit of 10,000 requests per second may allow 10,500 requests per second in practice ).
 * **Fail-safe**. In the event that the microservice component goes down all traffic should be permitted until it recovers.

[Back to TOC](#table-of-contents)

Definitions
===========

### Tracking Domain
The Tracking Domain is a formula involving a **group of variables** and the associated **values** they may take. 
It represents the identifier for matching requests requiring a special action ( `track`, `block`, `delay`, `rewrite`).  

Let's look at some examples in the table below.

| Variable         | Expected Value | Used for tracking requests ... |
| ----------------- | --------------- | -------------- |
| `$service_id`     | `service_1`     | hitting the `service_1` service. |
| `$app_name`       | `my_application` | coming from `my_application` regardless of the service it hits. |
| `$service_id;$app_name` | `service_1;my_application` | coming from an application named `my_application` but this time the limit applies only in the context of the `service_1` service.|
| `$service_id;$request_method` | `service_1;POST` | hitting the `service_1` service using the `POST` http method. |

  Pretty much any NGINX variable or user defined variable can be used to create the domain for tracking requests. 
  This includes HTTP headers, query parameters, or URI parts. 
  
>TIP: The Expected Value can be a wildcard (`*`) not only a static value.  

### Tracking Rules 
A Tracking Rule is a tuple created from a **tracking domain**, an **expiration time**, and an **action**. 
 For example to `block` all requests having `x-api-key` header=`1234` for `100ms` the following rule can be added:

```json
{
  "id": 777,
  "domain" : "1234",
  "format": "$http_x_api_key",
  "expire_at_utc": 1408065588203,
  "action" : "BLOCK"
}
```    

* `id` - is an identifier for the rule
* `domain` and `format` - is the actual domain as defined above. `domain` field holds the Expected Value for the variables defined in the `format` field.
   `$http_x_api_key` is the NGINX variable holding the value of the header `x-api-key`.
* `expire_at_utc` - the timestamp in UTC when this rule should expire. In order to enforce this rule for `100ms` the rule has to specify a timestamp with `+100ms` in the future from the current time.
* `action` - describes what to do when a request matches the **tracking domain** and in this example the action is to `BLOCK` the request most probably returning a `429` Status Code.

This module implements the following actions:

#### TRACK
This action causes the Gateway to start logging usage information into a message queue. The default implementation uses ZMQ.
As mentioned above, this module assumes theres's a microservice listening for these messages, making further decisions for the next actions to be applied. 

In the example bellow the following Tracking Rule starts logging all requests containing `X-Api-Key` header with a value of `1234`:
```json
{
  "id": 777,
  "domain" : "1234",
  "format": "$http_x_api_key",
  "expire_at_utc": 1408065588203,
  "action" : "TRACK"
}
```

It's also possible to capture all the traffic regardless of the value of the `X-Api-Key` header. The following example illustrates how to capture all the traffic for a given host:
```json
{
  "id": 777,
  "domain" : "example.com;*",
  "format": "$host;$http_x_api_key",
  "expire_at_utc": 1408065588203,
  "action" : "TRACK"
}
```
In this case the Gateway logs the value of the `$host` and also the value of the `X-Api-Key` header. This is useful to count the usage by API-KEY and take a corresponding action that affects only that API-KEY. 

#### BLOCK
This action blocks requests and returns a `429` HTTP Status code in the response. 

#### DELAY
This action delays requests using a random number between the actual delay / 2 and the actual delay. For example if the delay is set to `5` seconds this module delays requests using a random number between `2.5` seconds and `5` seconds. 
 Delaying strategy works great for short spikes in traffic. It is best to start delaying requests before blocking them. 



#### REWRITE
This action 

[Back to TOC](#table-of-contents)

Sample usage
============

```nginx
TBD
```

[Back to TOC](#table-of-contents)

Developer guide
===============

## Running the tests

```bash
 make test-docker
```

Test files are located in `test/perl` folder and are based on the `test-nginx` library.
This library is added as a git submodule under `test/resources/test-nginx/` folder, from `https://github.com/agentzh/test-nginx`.

The other libraries such as `Redis`, `test-nginx` would be located in `test/resources/`.
Other files used when running the test are also located in `test/resources`.

 If you want to run a single test edit [docker-compose.yml](test/docker-compose.yml) and replace in `entrypoint` 
 `/tmp/perl` with the actual path to the test ( i.e. `/tmp/perl/my_test.t`)
 
 The complete `entrypoint` config would look like:
```
 entrypoint: ["prove", "-I", "/usr/local/test-nginx-0.24/lib", "-I", "/usr/local/test-nginx-0.24/inc", "-r", "/tmp/perl/my_test.t"]
```
This will only run `my_test.t` test file.

## Running the tests with a native binary
 
 The Makefile also exposes a way to run the tests using a native binary:
 
```
 make test
```
This is intended to be used when the native binary is present and available on `$PATH`.

[Back to TOC](#table-of-contents)
