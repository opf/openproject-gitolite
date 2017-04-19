module OpenProject::Gitolite::GitoliteWrapper
  class Admin
    attr_reader :admin

    def initialize(action, object_id, options = {})
      @object_id      = object_id
      @action         = action
      @options        = options

      logger.info("Creating gitolite action for '#{@action}'")
    end

    def run
      # Created here to avoid serialization of these heavy objects
      # before delayed_job.
      @admin = OpenProject::Gitolite::GitoliteWrapper.admin
      @gitolite_config = @admin.config

      send(@action)
    end

    def logger
      Rails.logger
    end

    def gitolite_admin_repo_commit(message = '')
      logger.info("#{@action} : commiting to Gitolite...")
      @admin.save("#{@action} : #{message}")
    rescue => e
      logger.error { "#{e.message}" }
    end
  end
end
