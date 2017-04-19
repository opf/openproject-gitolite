require 'socket'
module OpenProject::Gitolite
  GITHUB_ISSUE = 'https://github.com/oliverguenther/openproject-gitolite/issues'

  class Engine < ::Rails::Engine
    engine_name :openproject_gitolite

    def self.default_hostname
      Socket.gethostname || 'localhost'
    rescue
      nil
    end

    def self.settings
      {
        partial: 'settings/openproject-gitolite',
        default:
        {

          # Gitolite SSH Config
          gitolite_user:                         'git',
          gitolite_server_host:                  default_hostname,
          gitolite_server_port:                  '22',
          gitolite_ssh_private_key:              File.join(Dir.home, '.ssh', 'id_rsa').to_s,
          gitolite_ssh_public_key:               File.join(Dir.home, '.ssh', 'id_rsa.pub').to_s,

          # Gitolite Storage Config
          # deprecated
          gitolite_global_storage_dir:           'repositories',
          # Full path
          gitolite_global_storage_path:          '/home/git/repositories',
          gitolite_redmine_storage_dir:          '',
          gitolite_recycle_bin_dir:              'recycle_bin/',
          gitolite_local_code_dir:               '.gitolite/',
          gitolite_lib_dir:                      'bin/lib/',

          # Gitolite Config File
          gitolite_admin_dir:                    File.join(Dir.home, 'gitolite-admin'),
          gitolite_config_file:                  'gitolite.conf',
          gitolite_identifier_prefix:            'openproject_',
          gitolite_identifier_strip_user_id:     false,

          # Gitolite Global Config
          gitolite_temp_dir:                     File.join(Dir.home, 'tmp', 'openproject_revisions_git').to_s,
          gitolite_recycle_bin_expiration_time:  24.0,
          gitolite_log_level:                    'info',
          gitolite_log_split:                    false,
          git_config_username:                   'OpenProject Revisions(Git)',
          git_config_email:                      'openproject@example.net',
          gitolite_scripts_dir:                  File.join(Dir.home, 'bin'),
          gitolite_timeout:                      10,
          gitolite_resync_all:                   false,

          # Gitolite Hooks Config
          gitolite_overwrite_existing_hooks:     true,
          gitolite_hooks_are_asynchronous:       false,
          gitolite_hooks_debug:                  false,
          gitolite_hooks_url:                    'http://localhost:3000',

          # Gitolite Cache Config
          gitolite_cache_max_time:               '86400',
          gitolite_cache_max_size:               '16',
          gitolite_cache_max_elements:           '2000',
          gitolite_cache_adapter:                'database',


          # Gitolite Access Config
          ssh_server_domain:                     default_hostname,
          http_server_domain:                    default_hostname,
          https_server_domain:                   default_hostname,
          http_server_subdir:                    '',
          show_repositories_url:                 true,
          gitolite_daemon_by_default:            false,
          gitolite_http_by_default:              1,

          # Redmine Config
          redmine_has_rw_access_on_all_repos:    true,
          all_projects_use_git:                  false,
          init_repositories_on_create:           false,
          delete_git_repositories:               true,

          # This params work together!
          # When hierarchical_organisation = true unique_repo_identifier MUST be false
          # When hierarchical_organisation = false unique_repo_identifier MUST be true
          hierarchical_organisation:             true,
          unique_repo_identifier:                false,

          # Download Revision Config
          download_revision_enabled:             true,

          # Git Mailing List Config
          gitolite_notify_by_default:            false,
          gitolite_notify_global_prefix:         '[OPENPROJECT]',
          gitolite_notify_global_sender_address: 'openproject@example.net',
          gitolite_notify_global_include:        [],
          gitolite_notify_global_exclude:        [],

          # Sidekiq Config
          gitolite_use_sidekiq:                  false,

          # Delayed jobs
          use_delayed_jobs:                      false,
        }
      }
    end

    include OpenProject::Plugins::ActsAsOpEngine

    register(
      'openproject-gitolite',
      author_url: 'https://github.com/opf/openproject-gitolite',
      requires_openproject: '>= 6.0.0',
      settings: settings
    ) do
      project_module :repository do
        permission :view_manage_gitolite_repositories, manage_git_repositories: [:index, :show]

        permission :create_public_user_ssh_keys,       my: :account
        permission :create_public_deployment_ssh_keys, my: :account

        permission :create_repository_deployment_credentials, repository_deployment_credentials: [:new, :create]
        permission :view_repository_deployment_credentials,   repository_deployment_credentials: [:index, :show]
        permission :edit_repository_deployment_credentials,   repository_deployment_credentials: [:edit, :update, :destroy]

        permission :create_repository_post_receive_urls, repository_post_receive_urls: [:new, :create]
        permission :view_repository_post_receive_urls,   repository_post_receive_urls: [:index, :show]
        permission :edit_repository_post_receive_urls,   repository_post_receive_urls: [:edit, :update, :destroy]

        permission :create_repository_mirrors, repository_mirrors: [:new, :create]
        permission :view_repository_mirrors,   repository_mirrors: [:index, :show]
        permission :edit_repository_mirrors,   repository_mirrors: [:edit, :update, :destroy]
        permission :push_repository_mirrors,   repository_mirrors: [:push]

        permission :create_repository_git_config_keys, repository_git_config_keys: [:new, :create]
        permission :view_repository_git_config_keys,   repository_git_config_keys: [:index, :show]
        permission :edit_repository_git_config_keys,   repository_git_config_keys: [:edit, :update, :destroy]

      end

      # Public Keys under user account
      menu(
        :my_menu,
        :public_keys,
        { controller: 'my_public_keys', action: 'index' },
        html: { class: 'icon2 icon-folder-locked' },
        caption: :label_public_keys,
        if: Proc.new { |authorized = false| authorized = true if User.current.admin?
                                            User.current.projects_by_role.each_key do |role|
                                                 authorized = true if role.allowed_to?(:create_public_user_ssh_keys) || role.allowed_to?(:create_public_deployment_ssh_keys)
                                            end
                       authorized }
      )

      # Manage Gitolite repository under Project|Repository
      menu(
        :project_menu,
        :manage_git_repositories,
        { controller: 'manage_git_repositories', action: 'index' },
        caption: 'Manage Gitolite repository',
        param: :project_id,
        parent: :repository,
        if: Proc.new { |p| (p.repository && p.repository.is_a?(Repository::Gitolite)) && (User.current.admin? || User.current.allowed_to?(:view_manage_gitolite_repositories, p)) },
        html: { class: 'icon2 icon-locked-folder' }
      )


    end

    config.to_prepare do
      [
        :user, :setting, :settings_controller,
        :users_controller, :my_controller,
        :users_helper, :roles_controller, :member
      ].each do |sym|
        require_dependency "open_project/gitolite/patches/#{sym}_patch"
      end

      require_dependency 'open_project/gitolite/load_gitolite_hooks'
      require_dependency 'open_project/gitolite/git_hosting'
      require_dependency 'open_project/gitolite/grack/auth'
      require_dependency 'open_project/gitolite/grack/server'
    end

    initializer 'gitolite.scm_vendor' do
      require 'open_project/scm/manager'
      OpenProject::Scm::Manager.add :gitolite
    end

    initializer 'gitolite.configuration' do
      config = Setting.repository_checkout_data.presence || {}
      Setting.repository_checkout_data = config.merge('gitolite' => { 'enabled' => 1 })
    end

    initializer 'gitolite.precompile_assets' do
      Rails.application.config.assets.precompile += %w(gitolite/gitolite.css)
    end

    initializer 'gitolite.notification_listeners' do
      %i(member_updated
         member_removed
         roles_changed
         project_deletion_imminent
         project_updated).each do |sym|
        ::OpenProject::Notifications.subscribe(sym.to_s, &NotificationHandlers.method(sym))
      end
    end
  end
end
