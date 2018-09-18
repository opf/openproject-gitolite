module OpenProject::Gitolite::GitoliteWrapper
  class Repositories < Admin
    include OpenProject::Gitolite::GitoliteWrapper::RepositoriesHelper

    def add_repository
      repository = @object_id
      @admin.transaction do
        handle_repository_add(repository)

        gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
      end
    end

    def update_repository
      # We override the repository in gitolite anyway
      add_repository
    end

    # Delete the given repositories.
    #
    # As the project/repo model may be deleted already,
    # receives an array of repo name and path.
    #
    # Performs two steps
    # 1. Delete the reposistory from gitolite-admin (and commit)
    # 2. Delete the physical repository
    # (and all empty parent directories within the repository storage)
    def delete_repositories
      handle_repository_delete(@object_id)
    end
  end
end
