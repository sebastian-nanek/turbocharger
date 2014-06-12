require 'spec_helper'

describe Turbocharger::Service do
  subject { described_class.new(service_hash, configuration) }

  let(:service_hash) do
    {
      name:       'facebook',
      limit:      600,
      period:     600,
      batch_time: 1
    }
  end

  let(:connection_configuration) { double('dummy configuration') }

  let(:configuration) do
    double(Turbocharger::Configuration,
      configuration: connection_configuration).
      as_null_object
  end

  describe '.new' do
    describe 'freshly initialised instance variables (attr readers)' do
      its(:name)       { should eq 'facebook' }
      its(:limit)      { should eq 600 }
      its(:period)     { should eq 600 }
      its(:batch_time) { should eq 1 }
      its(:config)     { should eq configuration }
      its(:client)     { should be_an_instance_of(Turbocharger::RedisBackend) }
    end
  end

  describe '#with_rate_limited' do
    let(:client) { double("dummy backend client") }
    let(:code_block) { lambda {} }

    before do
      subject.stub(:client).and_return(client)
    end

    context 'service immediately available' do
      let(:expected_timestamp) { Time.now.to_i }

      before do
        client.stub(:allow_event?).and_return(true)
        client.stub(:log_event).and_return(true)
      end

      it 'logs an event on service with current timestamp' do
        expect(client).to receive(:log_event).with(expected_timestamp)

        subject.with_rate_limited(&code_block)
      end

      it 'checks if event is allowed' do
        expect(client).to receive(:allow_event?).with(expected_timestamp)

        subject.with_rate_limited(&code_block)
      end

      it 'yields the block' do
        expect(code_block).to receive(:call)

        subject.with_rate_limited(&code_block)
      end

      it 'returns the result of block' do
        result = subject.with_rate_limited { 42 }

        expect(result).to eq(42)
      end
    end

    context 'waiting for green light from backend' do
      before do
        client.stub(:allow_event?).and_return do
          # to simulate that first check failed
          if defined? @already_called
            true
          else
            @already_called = true
            false
          end
        end
        client.stub(:log_event).and_return(true)
        subject.config.stub(:retry_limit).and_return(2)
        subject.stub(:sleep) # to disable waiting for Kernel in tests
      end

      it 'logs event' do
        expect(client).to receive(:log_event)

        subject.with_rate_limited(&code_block)
      end

      it 'waits one second before logging' do
        expect(subject).to receive(:sleep).with(service_hash[:batch_time])

        subject.with_rate_limited(&code_block)
      end

      it 'calls the block' do
        expect(code_block).to receive(:call)

        subject.with_rate_limited(&code_block)
      end
    end

    context 'retries limit reached' do
      before do
        client.stub(:allow_event?).and_return(false)
        subject.config.stub(:retry_limit).and_return(1)
        subject.stub(:sleep) # to disable waiting for Kernel in tests
      end

      it 'raises an Exception' do
        expect {
          subject.with_rate_limited(&code_block)
        }.to raise_exception(
          Turbocharger::RateTimeout,
          "Rate exceeded, could not perform another request within given retries limit.")
      end
    end
  end
end
