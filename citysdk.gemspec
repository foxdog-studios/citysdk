# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'citysdk/version'

Gem::Specification.new do |spec|
  spec.name          = 'citysdk'
  spec.version       = CitySDK::VERSION
  spec.authors       = ['Lloyd Henning']
  spec.email         = ['lloyd.w.henning@gmail.com']
  spec.description   = %q{CitySDK core functionality}
  spec.summary       = %q{CitySDK core functionality}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday'
  spec.add_dependency 'rgeo-geojson'
  spec.add_dependency 'sequel'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end

