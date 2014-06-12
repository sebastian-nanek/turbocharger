require 'spec_helper'

describe 'limiting query rate' do
  subject { Turbocharger::Service.new(service_configuration, configuration) }

  let(:yaml_path) { File.expand_path('../../support/turbocharger.yml', __FILE__) }

  let(:configuration) do
    Turbocharger::Configuration.load_yaml(yaml_path)
  end

  let(:execution_block) do
    Proc.new do
      DummyService.call_something
    end
  end

  let(:service_configuration) do
    {
      name:       "dummy_service",
      limit:      3,
      period:     4,
      batch_time: 1
    }
  end

  before do
    subject.stub(:sleep) # we don't like waiting for specs...
    delete_dummy_service_keys
    Timecop.freeze(Time.at(timestamp))
  end

  after do
    delete_dummy_service_keys
    Timecop.return
  end

  context 'with bucket completely empty' do
    let(:timestamp) { 1386374420 }

    it 'does not sleep the thread' do
      expect(subject).not_to receive(:sleep)

      subject.with_rate_limited(&execution_block)
    end

    it 'executes the block' do
      expect(DummyService).to receive(:call_something)

      subject.with_rate_limited(&execution_block)
    end
  end

  context 'when the bucket is full' do

    before do
      3.times { |i| subject.with_rate_limited(&execution_block) }
    end

    context 'and can get empty before retry limit is reached' do
      let(:timestamp) { 1386374820 }

      it 'can call the block after 4 seconds' do
        Timecop.freeze(Time.at(timestamp + 4))

        expect(execution_block).to receive(:call)

        subject.with_rate_limited(&execution_block)
      end
    end

    context 'and cannot get empty before retry limit is reached' do
      let(:timestamp) { 1386374120 }

      it 'raises an error' do
        expect {
          subject.with_rate_limited(&execution_block)
        }.to raise_error(Turbocharger::RateTimeout,
          "Rate exceeded, could not perform another request within given retries limit.")
      end
    end
  end

  # required to properly and immediately clear the time cache
  def delete_dummy_service_keys
    client = Redis.new
    client.keys("dummy_service:*").each { |key| client.del(key) }
  end
end
