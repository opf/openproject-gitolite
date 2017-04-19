module OpenProject
  module Gitolite
    extend self

    def logger
      @logger ||= OpenProject::Gitolite::Logger.init_logs!('OpenProjectRevisionsGit', logfile, loglevel)
    end

    def logfile
      Rails.root.join('log', 'git_hosting.log')
    end

    def loglevel
      case OpenProject::Gitolite::Config.gitolite_log_level
      when 'debug' then
        Logger::DEBUG
      when 'info' then
        Logger::INFO
      when 'warn' then
        Logger::WARN
      when 'error' then
        Logger::ERROR
      else
        Logger::INFO
      end
    end

    require 'open_project/gitolite/engine'
  end
end
