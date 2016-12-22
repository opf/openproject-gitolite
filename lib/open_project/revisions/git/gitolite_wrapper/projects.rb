module OpenProject::Revisions::Git::GitoliteWrapper
  class Projects < Admin
    include RepositoriesHelper

    def update_projects
      @admin.transaction do
        perform_update(@object_id)
      end
    end

    def update_all_projects
      @admin.transaction do
        perform_update(Project)
      end
    end

    ##
    # Truncates the +openproject.conf+ file prior to synchronization
    # so that all configurations made from the plugin are reset.
    def clear_gitolite_config
      @admin.transaction do
        gitolite_admin_dir = OpenProject::Revisions::Git::Config.get_setting(:gitolite_admin_dir)
        config_file = OpenProject::Revisions::Git::GitoliteWrapper.gitolite_admin_settings[:config_file]
        config_file_full_pat = File.join(gitolite_admin_dir, 'conf', config_file)

        # Delete old config file to recreate it form scratch
        logger.info("#{@action} : Cleaning Gitolite configuration file '#{config_file}' ...")
        FileUtils.rm_f(config_file_full_pat)
        FileUtils.touch(config_file_full_pat)

        @admin.reload!
        gitolite_admin_repo_commit("Cleaning Gitolite configuration from '#{config_file}'")
      end
    end

    ##
    # Forces resynchronization with the gitolite config for all repositories
    # with a current configuration.
    def sync_with_gitolite
      @admin.transaction do
        #admin.truncate!
        #gitolite_admin_repo_commit("Truncated configuration")
        perform_update(@object_id)
      end
    end

    def move_repositories
      projects = Project.find_by_id(@object_id).self_and_descendants

      # Only take projects that have Git repos.
      gitolite_projects = filter_gitolite(projects)
      return if gitolite_projects.empty?

      @admin.transaction do
        handle_repositories_move(gitolite_projects)
      end
    end

    private

    ##
    # Find gitolite projects
    def filter_gitolite(projects)
      projects.includes(:repository)
              .where('repositories.type = ?', 'Repository::Gitolite')
              .references('repositories')
    end

    # Updates a set of projects by re-adding
    # them to gitolite.
    #
    def perform_update(projects)
      repos = filter_gitolite(projects)
      return unless repos.size > 0

      message = "Updated projects:\n"
      repos.each do |project|
        handle_repository_add(project.repository)
        message << " - #{project.identifier}\n"
      end

      gitolite_admin_repo_commit(message)
    end
  end
end
