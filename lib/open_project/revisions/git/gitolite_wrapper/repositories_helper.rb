require 'pathname'
module OpenProject::Revisions::Git::GitoliteWrapper
  module RepositoriesHelper
    def handle_repository_add(repository)
      repo_name = repository.gitolite_repository_name

      if @gitolite_config.repos[repo_name]
        logger.warn("#{@action} : repository '#{repo_name}' already exists in Gitolite configuration, overriding")
        @gitolite_config.rm_repo(repo_name)
      end

      # Create new repo object
      repo_conf = Gitolite::Config::Repo.new(repo_name)
      set_repo_config_keys(repo_conf, repository)

      builder = OpenProject::Revisions::Git::GitoliteWrapper::PermissionBuilder.new repository
      repo_conf.permissions = builder.build_permissions!
      @gitolite_config.add_repo(repo_conf)
    end

    #
    # Sets the git config-keys for the given repo configuration
    #
    def set_repo_config_keys(repo_conf, repository)
      # Set post-receive hook params
      repo_conf.set_git_config('openprojectgitolite.projectid', repository.project.identifier.to_s)
      repo_conf.set_git_config('openprojectgitolite.repositorykey', repository.extra[:key].to_s)
      repo_conf.set_git_config('http.uploadpack', (User.anonymous.allowed_to?(:view_changesets, repository.project) ||
        repository.smart_http_enabled?))
      repo_conf.set_git_config('http.receivepack', (repository.smart_http_enabled?))

      # Set Git config keys
      repository.repository_git_config_keys.each do |config_entry|
        repo_conf.set_git_config(config_entry.key, config_entry.value)
      end
    end

    # Delete the reposistory from gitolite-admin (and commit)
    # and yield (e.g., for deletion / moving to trash before commit)
    #
    def handle_repository_delete(repos)
      @admin.transaction do
        repos.each do |repo|
          if @gitolite_config.repos[repo[:name]]

            # Delete from in-memory gitolite
            @gitolite_config.rm_repo(repo[:name])

            # Commit changes
            gitolite_admin_repo_commit(repo[:name])

            # Delete physical repo
            clean_repo_dir(repo[:relative_path])
          else
            logger.warn("#{@action} : '#{repo[:name]}' does not exist in Gitolite")
          end
        end
      end
    end

    # Move a list of git repositories to their new location
    #
    # The old repository location is expected to be available from its url.
    # Upon moving the project (e.g., to a subproject),
    # the repository's url will still reflect its old location.
    def handle_repositories_move(projects_list)
      # We'll need the repository root directory.
      gitolite_repos_root = OpenProject::Revisions::Git::GitoliteWrapper.gitolite_global_storage_path
      projects_list.each do |project|
        # Old name is the <path> section of above, thus extract it from url.
        # But remove the '.git' part.
        old_repository_name = File.basename(project.repository.url, '.git')
        old_repository_path = [File.join(gitolite_repos_root, old_repository_name), '.git'].join

        # Actually move the repository
        do_move_repository(project.repository, old_repository_path, old_repository_name)

        gitolite_admin_repo_commit("#{@action} : #{project.identifier}")
      end
    end

    # Move a repository in gitolite-admin from its old entry to a new one
    #
    # This involves the following steps:
    # 1. Remove the old entry (+old_name+)
    # 2. Move the physical repository on filesystem.
    # 3. Add the repository using +repo.gitolite_repository_name+
    #
    def do_move_repository(repo, old_path, old_name)
      new_name  = repo.repository_identifier
      new_path  = repo.managed_repository_path

      logger.info("#{@action} : Moving '#{old_name}' -> '#{new_name}'")
      logger.debug("-- On filesystem, this means '#{old_path}' -> '#{new_path}'")

      # Remove old config entry
      @gitolite_config.rm_repo(old_name)

      # Move the repo on filesystem
      move_physical_repo(old_path, new_path)

      # Add the repo as new
      repo.url = new_path
      repo.root_url = new_path
      repo.save
      handle_repository_add(repo)
    end

    def move_physical_repo(old_path, new_path)
      if old_path == new_path
        logger.warn("#{@action} : old repository and new repository are identical '#{old_path}' .. why move?")
        return
      end

      # If the new path exists, some old project wasn't correctly cleaned.
      if File.directory?(new_path)
        logger.warn("#{@action} : New location '#{new_path}' was non-empty. Cleaning first.")
        clean_repo_dir([File.basename(new_path, '.git'), '.git'].join)
      end

      # Old repository has never been created by gitolite
      # => No need to move anything on the disk
      if !File.directory?(old_path)
        logger.info("#{@action} : Old location '#{old_path}' was never created. Skipping disk movement.")
        return
      end

      # Otherwise, move the old repo
      FileUtils.mv(old_path, new_path, force: true)

      # Clean up the old path
      clean_repo_dir([File.basename(old_path, '.git'), '.git'].join)
    end

    # Removes the repository path and all parent repositories that are empty
    #
    # (i.e., if moving foo/bar/repo.git to foo/repo.git, foo/bar remains and is possibly abandoned)
    # This moves up from the lowermost point, and deletes all empty directories.
    def clean_repo_dir(path)
      repo_root = OpenProject::Revisions::Git::GitoliteWrapper.gitolite_global_storage_path
      full_path = File.join(repo_root, path)

      Dir.chdir(repo_root) do
        # If no repository was created, break early
        break unless File.directory?(full_path)

        # Delete the repository project itself.
        logger.info("Deleting obsolete repository #{full_path}")
        OpenProject::Revisions::Git::Commands.sudo_rm_rf(full_path) #To prevent error while deleting repos that use SmartHTTP (still need to find why error is produced)
        #FileUtils.remove_dir(path)

        # Traverse all parent directories within repositories,
        # searching for empty project directories.
        parent = Pathname.new(full_path).parent

        loop do
          # Stop deletion upon finding a non-empty parent repository
          break unless parent.children(false).empty?

          # Stop if we're in the project root
          break if parent == repo_root

          logger.info("#{@action} : Cleaning repository parent #{parent} ... ")
          FileUtils.rmdir(parent)

          parent = parent.parent
        end
      end
    end
  end
end
