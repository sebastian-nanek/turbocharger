# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'turbocharger/version'

Gem::Specification.new do |spec|
  spec.name          = "turbocharger"
  spec.version       = Turbocharger::VERSION
  spec.authors       = ["Sebastian Nanek"]
  spec.email         = ["snanek@gmail.com"]
  spec.description   = %q{Use external APIs at full speed.}
  spec.summary       = %q{Use external APIs at full speed.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "timecop"

  spec.add_runtime_dependency "redis"
end
