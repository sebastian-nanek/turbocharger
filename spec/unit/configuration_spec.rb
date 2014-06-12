require 'spec_helper'

describe Turbocharger::Configuration do
  let(:configuration_hash) do
    {
      "host" => "localhost",
      "port" => 42
    }
  end

  subject { described_class.new(configuration_hash) }

  describe '.new' do
    it 'memoizes config hash' do
      expect(subject.configuration).to eq({
        "host"        => "localhost",
        "port"        => 42,
        "retry_limit" => 60
      })
    end

    it 'merges configuration hash with defaults' do
      expect(configuration_hash).
        to receive(:merge).
        with(described_class.defaults)

      subject
    end
  end

  describe '.defaults' do
    its(:defaults) { { "retry_limit" => 60 } }
  end

  describe '.load_yaml' do
    let(:configuration_hash) { double("configuration_hash") }

    let(:filename) { double("filename") }

    it 'loads YAML from file provided as first parameter' do
      expect(YAML).to receive(:load_file).with(filename)

      described_class.load_yaml(filename)
    end

    context 'with loading file stubbed' do
      before do
        YAML.stub(:load_file).and_return(configuration_hash)
        configuration_hash.stub(:merge).and_return(configuration_hash)
      end

      it 'initialises configuration using data from yaml' do
        expect(described_class).to receive(:new).with(configuration_hash)

        described_class.load_yaml(filename)
      end

      it 'returns an instance of Turbocharger::Configuration' do
        loaded_configuration = described_class.load_yaml(filename)

        expect(loaded_configuration).to be_a_kind_of(described_class)
      end
    end
  end

  describe 'redis configuration options' do
    its(:host) { should eq(configuration_hash["host"]) }
    its(:port) { should eq(configuration_hash["port"]) }
    its(:retry_limit) { should eq(described_class.defaults["retry_limit"]) }
  end
end
