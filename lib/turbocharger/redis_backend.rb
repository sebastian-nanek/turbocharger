require 'redis'

module Turbocharger
  class RedisBackend
    attr_reader :service_name, :period, :batch_time, :limit, :config

    # pass an instance of Turbocharger::Service
    def initialize(service)
      @service_name, @period, @batch_time, @limit =
        service.name, service.period, service.batch_time, service.limit

      @config = service.config

      @connection = Redis.new(redis_configuration)
    end

    # stores event occurrence at given timestamp
    # bucket expires after batch_time
    # does not perform validation if given event is valid
    # - use allow_event? first
    def log_event(timestamp)
      key = service_key(service_name, timestamp)
      hash_key = timestamp % batch_time

      did_not_exist = !@connection.exists(key)

      @connection.hincrby(key, hash_key, 1)
      @connection.expire(key, 2*period/batch_time) if did_not_exist
    end

    # checks if it is possible to store a new event at timestamp provided
    def allow_event?(timestamp)
      key = service_key(service_name, timestamp)
      previous_key = service_key(service_name,
        (timestamp - batch_time * period))
      previous_bucket_boundary_time = timestamp % ( period / batch_time )

      current_bucket_sum = @connection.
        hvals(key).
        map(&:to_i).
        reduce {|agg, v| agg+v }

      previous_bucket = @connection.hgetall(previous_key)

      # select block dismisses all events that happened before boundary time
      previous_bucket_sum = previous_bucket.
        select { |key, value| key.to_i > previous_bucket_boundary_time }.
        values.
        map(&:to_i).
        reduce {|agg, v| agg+v }

      events_count = previous_bucket_sum.to_i + current_bucket_sum.to_i

      (events_count < limit)
    end

    private
    def redis_configuration
      {
        host: config.host,
        port: config.port
      }
    end

    def service_key(service_name, timestamp)
      time_bucket = batch_id(timestamp)

      "#{service_name}:#{time_bucket}"
    end

    def batch_id(timestamp)
      (timestamp / ( period / batch_time )).floor
    end
  end
end
