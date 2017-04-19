require_dependency 'open_project/scm/adapters/gitolite'
require_dependency 'repository/git'

class Repository::Gitolite < Repository::Git
  has_one :extra, foreign_key: 'repository_id', class_name: 'RepositoryGitExtra', dependent: :destroy
  accepts_nested_attributes_for :extra

  has_many :repository_deployment_credentials, dependent: :destroy, foreign_key: 'repository_id'
  has_many :repository_post_receive_urls, dependent: :destroy, foreign_key: 'repository_id'
  has_many :repository_mirrors, dependent: :destroy, foreign_key: 'repository_id'
  has_many :repository_git_config_keys, dependent: :destroy, foreign_key: 'repository_id'

  # Parse a path of the form <proj1>/<proj2>/<proj3>/<projekt>.git and return the specified
  # project identifier.
  #
  # Example: project1/subproject1/myproject.git => 'myproject'
  def self.find_by_path(path)
    identifier = File.basename(path, '.*')
    if (project = Project.find_by(identifier: identifier))
      project.repository
    end
  end

  def self.requires_checkout_base_url?
    false
  end

  def self.supported_types
    types = []
    types << managed_type if manageable?

    types
  end

  def self.managed_root
    OpenProject::Gitolite::GitoliteWrapper.gitolite_global_storage_path
  end

  def self.permitted_params(params)
    super(params).merge(params.permit(extra_attributes: :git_daemon))
  end

  def self.scm_adapter_class
    ::OpenProject::Scm::Adapters::Gitolite
  end

  def configure(scm_type, args)
    super(scm_type, args)

    # Build default extra unless set
    if self.extra.nil?
      self.extra = ::RepositoryGitExtra.new
    end
  end

  def managed_repo_created
    # Doing nothing here, as Gitolite will create the bare repository
  end

  # Returns the hierarchical repository path
  # e.g., "foo/bar.git"
  def repository_identifier
    "#{gitolite_repository_name}.git"
  end

  # Returns the repository name
  #
  # e.g., Project Foo, Subproject Bar => 'foo/bar'
  def gitolite_repository_name
    if (parent_path = get_full_parent_path).empty?
      project.identifier
    else
      File.join(parent_path, project.identifier)
    end
  end

  # Expands the parent path of this repository
  def get_full_parent_path
    parent_parts = []
    p = project
    while p.parent
      parent_id = p.parent.identifier.to_s
      parent_parts.unshift(parent_id)
      p = p.parent
    end

    File.join(*parent_parts)
  end

  def self.authorization_policy
    ::Scm::GitAuthorizationPolicy
  end

  def smart_http_enabled?
    extra[:git_http] != 0
  end

  def https_access_enabled?
    extra[:git_http] == 1 || extra[:git_http] == 2
  end

  def http_access_enabled?
    extra[:git_http] == 3 || extra[:git_http] == 2
  end

  def only_https_access_enabled?
    extra[:git_http] == 1
  end

  def only_http_access_enabled?
    extra[:git_http] == 3
  end

  def pushable_via_http?
    https_access_enabled? || http_access_enabled?
  end

  protected

  ##
  # Create local managed repository request when the built instance
  # is managed by OpenProject
  def create_managed_repository
    OpenProject::Gitolite::GitoliteWrapper.update(:add_repository, self)
  rescue => e
    Rails.logger.error("Error while adding repository #{repository_identifier}: #{e.message}")
    raise OpenProject::Scm::Exceptions::RepositoryBuildError.new(
      I18n.t('repositories.gitolite.cannot_add_repository')
    )
  end

  ##
  # Destroy local managed repository request when the built instance
  # is managed by OpenProject
  def delete_managed_repository
    OpenProject::Gitolite::GitoliteWrapper.logger.info("User '#{User.current.login}'
      has removed repository '#{repository_identifier}'")

    repository_data = {
      name: gitolite_repository_name,
      absolute_path: managed_repository_path,
      relative_path: repository_identifier
    }
    OpenProject::Gitolite::GitoliteWrapper.update(:delete_repositories, [repository_data])
  end
end
