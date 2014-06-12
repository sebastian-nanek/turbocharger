require 'spec_helper'

describe Turbocharger::RedisBackend do
  let(:backend_class) { Redis }
  let(:service) do
    double(Turbocharger::Service, {
      name:       'facebook',
      limit:      600,
      period:     600,
      batch_time: 1,
      config:     turbocharger_config
    })
  end

  let(:turbocharger_config) do
    double(Turbocharger::Configuration, configuration_data)
  end

  let(:configuration_data) do
    {
      host: "localhost",
      port: 42
    }
  end

  describe '.new' do
    let(:backend_configuration) { double("backend_configuration") }
    let(:backend_connection)    { double("backend_connection") }
    let(:configuration) do
      double(Turbocharger::Configuration, configuration_data)
    end

    subject { described_class.new(service) }

    before do
      Turbocharger.stub(configuration: configuration)
      backend_class.stub(:new).and_return(backend_connection)
    end

    its(:name)       { 'facebook' }
    its(:limit)      { 600 }
    its(:period)     { 600 }
    its(:batch_time) { 1 }
    its(:config)     { configuration }

    it 'initialises an instance of connection' do
      expect(backend_class).to receive(:new).with(configuration_data)

      subject
    end

    it 'memoizes the connection' do
      connection = subject.instance_variable_get("@connection")

      expect(connection).to eq(backend_connection)
    end
  end

  describe '#log_event' do
    subject { described_class.new(service) }

    let(:connection) { double(Redis).as_null_object }
    let(:timestamp)  { 1386374400 }
    let(:timebucket) { (1386374400 / 600).floor }
    let(:timeoffset) { timestamp % 600 }

    before do
      subject.instance_variable_set("@connection", connection)
    end

    it 'stores the event in valid bucket' do
      expect(connection).
        to receive(:hincrby).
        with("facebook:#{timebucket}", timeoffset, 1)

      subject.log_event(timestamp)
    end

    context 'when given bucket did not exist before' do
      before do
        connection.stub(:exists).and_return(false)
      end

      it 'marks newly created key to be expired' do
        expect(connection).
          to receive(:expire).
          with("facebook:#{timebucket}", 1200)

        subject.log_event(timestamp)
      end
    end
  end

  describe '#allow_event?' do
    subject { described_class.new(service) }

    let(:connection)          { double(Redis).as_null_object }
    let(:timestamp)           { 1386374420 }
    let(:timebucket)          { (timestamp / 600.0).floor }
    let(:timeoffset)          { timestamp % 600.0 }
    let(:current_bucket_key)  { "facebook:#{timebucket}" }
    let(:previous_bucket_key) { "facebook:#{timebucket - 1}" }

    before do
      subject.instance_variable_set("@connection", connection)
    end

    it 'gets all keys from current bucket' do
      expect(connection).
        to receive(:hvals).
        with(current_bucket_key)

      subject.allow_event?(timestamp)
    end

    it 'gets all pairs from previous bucket' do
      expect(connection).
        to receive(:hgetall).
        with(previous_bucket_key)

      subject.allow_event?(timestamp)
    end

    it 'takes from previous bucket only events that happened after boundary time' do
      connection.stub(:hvals).and_return(["100"])
      connection.stub(:hgetall).and_return({
        1  => 100,
        2  => 500,
        21 => 2
      })

      expect(subject.allow_event?(timestamp)).to be_true
    end

    it 'sums events from current and previous bucket' do
      connection.stub(:hvals).and_return(["500"])
      connection.stub(:hgetall).and_return({
        21 => 200
        })

      expect(subject.allow_event?(timestamp)).to be_false
    end

    it 'returns the result of comparison between events count and limit' do
      expect(subject.allow_event?(timestamp)).to be_true
    end
  end

  # testing private method because it makes public interface specs clearer
  describe 'private methods' do
    subject { described_class.new(service) }

    describe '#redis_configuration' do
      it 'provides valid Redis configurattion' do
        expected_configuration = {
          host: "localhost",
          port: 42
        }

        expect(subject.send(:redis_configuration)).
          to eq(expected_configuration)
      end
    end

    context 'with time explicitly set' do
      let(:timestamp) { Time.new(2013, 12, 7, 0, 0).to_i }

      describe '#service_key' do
        let(:service_name)  { 'dummybook' }

        it 'builds key in format service:bucket_time' do
          expect(subject.send(:service_key, service_name, timestamp)).
            to eq("dummybook:2310618")
        end
      end

      describe '#batch_id' do
        it 'returns floor of timestamp divided by (period times batch time)' do
          expect(subject.send(:batch_id, timestamp)).
            to eq(2310618)
        end
      end
    end
  end
end
