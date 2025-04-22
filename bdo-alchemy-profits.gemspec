# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'bdoap'
  s.license = 'MIT',
  s.version = '0.0.1'
  s.date = '2025-04-21'
  s.summary = 'this is a tool used to aggregate price and profit data for black desert alchemists.'
  s.description = 'this script allows you to find alchemy recipes from bdocodex.com, compare them with live central market prices, and use that information to determine what alchemy recipes are currently profitable.'

  s.authors = ['jpegzilla']
  s.email = 'eris@jpegzilla.com'

  s.homepage = 'https://github.com/jpegzilla/bdo-alchemy-profits'
  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = s.homepage


  s.required_ruby_version = ">= 3.1.0"
  s.bindir = 'bin'
  s.files = Dir['{lib}/**/*.rb', 'bin/*', 'LICENSE', '*.md']
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 2.6"
  s.add_development_dependency "rake", "~> 13.2"
end
