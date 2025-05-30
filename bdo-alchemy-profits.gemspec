# frozen_string_literal: true

require_relative 'lib/version'

Gem::Specification.new do |spec|
  spec.name = 'bdoap'
  spec.version = BDOAP::VERSION
  spec.date = '2025-04-21'
  spec.summary = 'this is a tool used to aggregate price and profit data for black desert alchemists.'
  spec.description = 'this script allows you to find alchemy recipes from bdocodex.com, compare them with live central market prices, and use that information to determine what alchemy recipes are currently profitable.'

  spec.authors = ['jpegzilla']
  spec.email = 'eris@jpegzilla.com'

  spec.homepage = 'https://github.com/jpegzilla/bdo-alchemy-profits'
  spec.license = 'MIT'


  spec.required_ruby_version = ">= 3.1.0"
  spec.files = Dir['{lib,bin}/**/**']
  spec.require_paths = ['lib']
  spec.executables << 'bdoap'
end
