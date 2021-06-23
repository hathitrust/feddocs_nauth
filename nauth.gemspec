# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nauth/version'

Gem::Specification.new do |spec|
  spec.name          = 'nauth'
  spec.version       = Nauth::VERSION
  spec.authors       = ['Josh Steverman']
  spec.email         = ['jstever@umich.edu']
  spec.summary       = 'Processing of Name Authority records.'
  spec.description   = ''
  spec.homepage      = ''

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_dependency 'dotenv'
end
