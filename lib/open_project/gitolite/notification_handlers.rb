require 'open_project/gitolite/gitolite_wrapper'
module OpenProject::Gitolite
  module NotificationHandlers
    class << self
      def member_updated(payload)
        project = payload[:member].project
        update_membership(project) if accepts?(project)
      end

      def member_removed(payload)
        project = payload[:member].project
        update_membership(project) if accepts?(project)
      end

      def project_deletion_imminent(payload)
        project = payload[:project]

        return unless accepts?(project)

        GitoliteWrapper.logger.info("Delete repositories of project '#{project}'. Resynchronizing Gitolite.")
        # Remember all projects with git repositories we have to delete later on.
        # Reverse the list to remove the lowermost repo first.
        destroy_repos = flatten_project_git_repos(project).reverse

        GitoliteWrapper.update(:delete_repositories, destroy_repos)
      end

      def project_updated(payload)
        project = payload[:project]

        return unless accepts?(project)

        if project_url_changed?(project.repository)
          GitoliteWrapper.logger.info("Move repositories of project '#{project}'. Resynchronizing Gitolite.")
          GitoliteWrapper.update(:move_repositories, project.id)
        else
          update_repo_daemon project
        end
      end

      def roles_changed(payload)
        GitoliteWrapper.logger.info("Roles were changed. Resynchronizing Gitolite.")
        GitoliteWrapper.update(:clear_gitolite_config, Project)
        GitoliteWrapper.update(:sync_with_gitolite, Project)
      end

      private

      ##
      # Detect whether the repository URL is different now that the project has been changed.
      # For example, this is the case when the project identifier is changed.
      def project_url_changed?(repository)
        repository.url != repository.managed_repository_path || repository.url != repository.root_url
      end

      def update_repo_daemon(project)
        # Adjust daemon status
        # Go through all gitolite repos and disable Git daemon if necessary
        if !project.is_public
          project.repository.extra[:git_daemon] = false
          project.repository.extra.save
        end
        GitoliteWrapper.logger.info(
          "Set Git daemon for repositories of project : '#{project}'"
        )
        GitoliteWrapper.update(:update_repository, project.repository)
      end

      # Given a list of projects, returns a list of Git repos
      # of all subprojects with two keys:
      # name, path of the repository
      def flatten_project_git_repos(project)
        projects =
          project.self_and_descendants
          .uniq
          .select { |p| p.repository.is_a?(Repository::Gitolite) }

        projects.map do |p|
          { name: p.repository.gitolite_repository_name,
            absolute_path: p.repository.managed_repository_path,
            relative_path: p.repository.repository_identifier
          }
        end
      end

      def update_membership(project)
        GitoliteWrapper.logger.info(
          "Membership changes on project '#{project.identifier}', update!"
        )
        GitoliteWrapper.update(:update_repository, project.repository)
      end

      def accepts?(project)
        project.present? && project.repository.is_a?(Repository::Gitolite)
      end
    end
  end
end
