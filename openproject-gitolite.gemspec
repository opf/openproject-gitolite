# encoding: UTF-8
$:.push File.expand_path('../lib', __FILE__)

require 'open_project/gitolite/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'openproject-gitolite'
  s.version     = OpenProject::Gitolite::VERSION
  s.authors     = 'OpenProject GmbH'
  s.email       = 'info@openproject.com'
  s.homepage    = 'https://www.github.com/opf/openproject-gitolite'
  s.summary     = 'Gitolite integration for OpenProject'
  s.description = 'This plugin allows straightforward management of Gitolite within OpenProject.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*'] + %w(README.md)

  s.add_dependency 'rails', '>= 5.0'
  s.add_dependency 'gitolite-rugged'
  s.add_dependency 'net-ssh'
end
