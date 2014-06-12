**Turbocharger** is just a small gem that allows throttling (rate limiting) method calls. The most common use case is to maximize throughput when calling external API.

USAGE
=====

```
  configuration = Turbocharger::Configuration.load_yaml("turbocharger.yml")

  service = {
    "name"       => "dummybook"
    "limit"      => 600,
    "period"     => 600,
    "batch_time" => 1
  }

  rate_limiter = Turbocharger::Service.new(service, configuration)

  rate_limiter.with_rate_limited do
    DummyService.callSomething
  end
```

Configuration options:

* `name` - name of your service (requests are limited per service)
* `limit` - maximum number of requests per time
* `period` - period of time, when given event is blocking others
* `batch_time` - granularity for storing events in seconds (the lower batch time is, the more memory is needed; increasing this value reduces accurancy, `1` is fine for most APIs)

REQUIRES
========

* `ruby` >= 1.9.3 (might work on all versions >= 1.9.0, not tested)
* `rubygems`
* Redis server

TESTING
=======

```
  $ bundle exec rspec
```

ALGORITHM
=========

`timestamp` - time represented as integer
`bucket size` - period / granularity (batch_time)
`time offset` - distance of time [seconds] from beginning of bucket to timestamp (eg. timestamp modulo bucket size)

Logging events
--------------

1. take event timestamp, divide it by bucket size and take floor
2. build key by joining service identifier and value from step one, separated by colon (i.e. "dummybook:2310624")
3. check if given key exists
4. in redis hash specified by key, increment value at time offset by 1
5. set hash (object stored at key) to expire at 2*bucket size if did not exist before

Checking if allowed to publish
------------------------------

1. calculate sum at current bucket (it is stored at key defined in step 2 of logging events)
2. calculate sum at previous bucket ( eg. at key service_name:(current_bucket - 1) ), but take only events that occured after time offset
3. sum values at (1) and (2)
4. if sum is lower than limit - allow event to happen

Main algorithm
--------------

Just a loop - wait until allowed to publish, then log event and yield the code block that it rate-limited. If time exceeded - raise an exception

Final notes
=============

Solution is partly based on idea described at: https://chris6f.com/rate-limiting-with-redis (algorithm is somehow different).

Also, there are some other gems for API calls limiting out there, but usually they lack flexibility or they are not vertically scalable (e.g. you cannot share limits across servers). By contrast, this solution should also work for distributed architectures - one just need to make sure that all parts of internal infrastructure use the same redis instance for throttling calls, and external service identifiers do match.


TODOs
=====

* With small change in RedisBackend#allow_event? method, one could optimise this solution, by limiting the number of server reads. If the return value of this method is changed to be either true or amount of seconds that are left to next call, sleep operation in main loop would wait until the api is free, rather than currently hard-coded 1 second. Therefore, you save execution time (number of Redis calls) on calculating result of allow_event?.
* serious QAing
