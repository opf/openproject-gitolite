module OpenProject::Gitolite::GitoliteWrapper
  class PermissionBuilder
    def initialize(repository)
      @repository = repository
      @project = repository.project

      # Read permissions and eligbile users
      # from OpenProject project members
      prepare
    end

    # Select eligible users
    def prepare
      @users   = @project.member_principals
                         .references(:users)
                         .map(&:user).compact.uniq
      build_op_permissions
    end

    def build_op_permissions
      @rewind_users = @users.select { |user| user.allowed_to?(:manage_repository, @project) }
      @rewind_deploy_keys = GitolitePublicKey.find(@repository.repository_deployment_credentials.where(perm: 'RW+', active: 1).pluck(:gitolite_public_key_id))

      @write_users =
        @users.select { |user| user.allowed_to?(:commit_access, @project) } -
        @rewind_users

      @read_users =
        @users.select { |user| user.allowed_to?(:view_changesets, @project) } -
        @rewind_users -
        @write_users
      @read_deploy_keys = GitolitePublicKey.find(@repository.repository_deployment_credentials.where(perm: 'R', active: 1).pluck(:gitolite_public_key_id))

      @rewind = []
      @write  = []
      @read   = []
        
      @rewind_deploy          = []
      @read_deploy            = []
      @all_rewind_identifiers = []
      @all_read_identifiers   = []
    end

    def get_identifier(set)
      set.map(&:gitolite_identifier)
    end

    def get_deploy_identifier(set)
      set.map(&:identifier)
    end

    def gitweb_enabled?
      User.anonymous.allowed_to?(:browse_repository, @project) &&
        extra_given? &&
        @repository.extra[:git_http] != 0
    end

    def git_daemon_enabled?
      User.anonymous.allowed_to?(:view_changesets, @project) &&
        extra_given? &&
        @repository.extra[:git_daemon]
    end

    def extra_given?
      !@repository.extra.nil?
    end

    # Builds the set of permissions for all
    # users and deploy keys of the repository
    #
    def build_permissions!
      #Deployment keys will keep the permissions even with non active projects
      @rewind_deploy = get_deploy_identifier(@rewind_deploy_keys)
      @read_deploy   = get_deploy_identifier(@read_deploy_keys)

      if @project.active?
        @rewind = get_identifier(@rewind_users)
        @write  = get_identifier(@write_users)
        @read   = get_identifier(@read_users)
        active_project_gitolite_access
      else
        all_read = @rewind_users + @write_users + @read_users
        @read     = get_identifier(all_read)
        @read << 'REDMINE_CLOSED_PROJECT' if @read.empty? && @read_deploy.empty?
      end

      convert_to_gitolite_format
    end

    def active_project_gitolite_access
      @read << 'DUMMY_REDMINE_KEY' if @read.empty? && @write.empty? && @rewind.empty? && @rewind_deploy.empty? && @read_deploy.empty?
      @read << 'gitweb' if gitweb_enabled?
      @read << 'daemon' if git_daemon_enabled?
    end

    # Turn the internal hash into the gitolite
    # accepted format
    def convert_to_gitolite_format
      @all_rewind_identifiers = @rewind + @rewind_deploy
      @all_read_identifiers = @read + @read_deploy
      permissions = {}
      permissions['RW+'] = { '' => @all_rewind_identifiers.uniq.sort } unless @all_rewind_identifiers.empty?
      permissions['RW'] = { '' => @write.uniq.sort } unless @write.empty?
      permissions['R'] = { '' => @all_read_identifiers.uniq.sort } unless @all_read_identifiers.empty?

      [permissions]
    end
  end
end
