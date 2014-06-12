class DummyService
  def self.call_something
    puts "called_at #{DateTime.now}" if ENV["DEBUG_TURBOCHARGER_GEM"]
  end
end
