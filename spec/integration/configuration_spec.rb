require 'spec_helper'

describe 'loading configuration from file' do
  let(:filename) { File.expand_path('../../support/turbocharger.yml', __FILE__) }

  subject { Turbocharger::Configuration.load_yaml(filename) }

  it "loads configuration from YAML file and merges it with defaults" do
    expected_configuration = {
      "host"        => "localhost",
      "port"        => 6379,
      "retry_limit" => 60
    }

    expect(subject.configuration).to eq(expected_configuration)
  end
end
