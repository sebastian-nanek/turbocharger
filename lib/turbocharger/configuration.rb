require 'yaml'

module Turbocharger
  class Configuration
    attr_reader :configuration

    def initialize(configuration_hash)
      @configuration = configuration_hash.merge(self.class.defaults)
    end

    def host
      configuration["host"]
    end

    def port
      configuration["port"]
    end

    def retry_limit
      configuration["retry_limit"]
    end

    def self.load_yaml(filename)
      configuration_data = YAML.load_file(filename) || {}

      new(configuration_data)
    end

    def self.defaults
      {
        "retry_limit" => 60
      }
    end
  end
end
