module Turbocharger
  class Service
    attr_reader :name, :limit, :period, :batch_time, :config, :client

    # Service initialisation:
    #   Turbocharger::Service.new(service_hash, Turbocharger::RedisBackend)
    def initialize(service, configuration, backend = Turbocharger::RedisBackend)
      @name, @limit, @period, @batch_time =
        service[:name], service[:limit], service[:period], service[:batch_time]

      @config = configuration
      @client = backend.new(self)
    end

    # example use:
    #   @facebook = Turbocharger::Service.new(facebook_configuration)
    #   @facebook.with_rate_limited do
    #     Facebook.callSomething
    #   end
    def with_rate_limited(&block)
      retries = 0

      begin
        if client.allow_event?(Time.now.to_i)
          client.log_event(Time.now.to_i)
          return block.call if block_given?
        elsif !config.retry_limit.nil? && retries >= config.retry_limit
          raise Turbocharger::RateTimeout.new "Rate exceeded, could not perform another request within given retries limit."
        else
          retries += 1
          sleep batch_time
        end
      end while true
    end
  end
end
