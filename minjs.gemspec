# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'minjs/version'

Gem::Specification.new do |spec|
  spec.name          = "minjs"
  spec.version       = Minjs::VERSION
  spec.authors       = ["Issei Numata"]
  spec.email         = ["issei@heart-s.com"]

#  if spec.respond_to?(:metadata)
#    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
#  end

  spec.summary       = %q{JavaScript compressor in pure Ruby}
  spec.description   = %q{Minjs is a JavaScript compressor written in pure Ruby}
  spec.homepage      = "https://github.com/i10a/minjs"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_dependency 'sprockets', '~> 3.0.0'
  spec.add_dependency 'tilt', '~> 1.4.0'
end
