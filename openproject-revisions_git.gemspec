# encoding: UTF-8
$:.push File.expand_path('../lib', __FILE__)

require 'open_project/revisions/git/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'openproject-revisions_git'
  s.version     = OpenProject::Revisions::Git::VERSION
  s.authors     = 'Oliver Günther'
  s.email       = 'mail@oliverguenther.de'
  s.homepage    = 'https://www.github.com/oliverguenther/openproject-revisions_git'
  s.summary     = 'Revisions/Git'
  s.description = 'This plugin allows straightforward management of Gitolite within OpenProject.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*'] + %w(README.md)

  s.add_dependency 'rails', '>= 4.0', '< 5'
  s.add_dependency 'gitolite-rugged'
  s.add_dependency 'gitlab-grack'
  #s.add_dependency 'net-ssh'
end
