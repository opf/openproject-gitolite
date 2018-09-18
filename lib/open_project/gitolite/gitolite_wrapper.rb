require 'gitolite'

module OpenProject::Gitolite
  module GitoliteWrapper
    def self.logger
      Rails.logger
    end

    def logger
      self.class.logger
    end

    def self.gitolite_user
      Setting.plugin_openproject_gitolite[:gitolite_user]
    end

    def self.gitolite_url
      [gitolite_user, '@localhost'].join
    end

    def self.gitolite_version
      logger.debug('Gitolite updating version')
      out, err, _ = ssh_capture('info')
      return 3 if out.include?('running gitolite3')
      return 2 if out =~ /gitolite[ -]v?2./
    rescue => e
      logger.error("Couldn't retrieve gitolite version through SSH: #{e.message}")
      nil
    end

    # Returns a rails cache identifier with the key as its last part
    def self.cache_key(key)
      ['/openproject/gitolite', key].join
    end

    def self.openproject_user
      `whoami`.chomp.strip
    end

    def self.http_server_domain
      Setting.plugin_openproject_gitolite[:http_server_domain]
    end

    def self.https_server_domain
      Setting.plugin_openproject_gitolite[:https_server_domain]
    end

    def self.gitolite_server_port
      Setting.plugin_openproject_gitolite[:gitolite_server_port]
    end

    def self.ssh_server_domain
      Setting.plugin_openproject_gitolite[:ssh_server_domain]
    end

    def self.gitolite_ssh_private_key
      Setting.plugin_openproject_gitolite[:gitolite_ssh_private_key]
    end

    def self.gitolite_ssh_public_key
      Setting.plugin_openproject_gitolite[:gitolite_ssh_public_key]
    end

    def self.git_config_username
      Setting.plugin_openproject_gitolite[:git_config_username]
    end

    def self.git_config_email
      Setting.plugin_openproject_gitolite[:git_config_email]
    end

    def self.true?(setting)
      [true, 'true', '1'].include?(Setting.plugin_openproject_gitolite[setting])
    end

    def self.gitolite_commit_author
      "#{git_config_username} <#{git_config_email}>"
    end

    def self.gitolite_admin_settings
      {
        git_user: gitolite_user,
        host: ssh_server_domain,

        author_name: git_config_username,
        author_email: git_config_email,

        public_key: gitolite_ssh_public_key,
        private_key: gitolite_ssh_private_key,

        key_subdir: 'openproject',
        config_file: 'openproject.conf'
      }
    end

    ##########################
    #                        #
    #    Git Repos Accessor  #
    #                        #
    ##########################

    def self.gitolite_global_storage_path
      Setting.plugin_openproject_gitolite[:gitolite_global_storage_path]
    end

    def self.capture_out(command, *params)
      Open3.capture3(command, *params)
    rescue => e
      error_msg = "Exception occured executing `#{command} #{params.join(' ')}`: #{e.message}"
      logger.error(error_msg)
      raise ::OpenProject::Scm::Exceptions::CommandFailed.new(command, error_msg)
    end

    # Executes the given command and a list of parameters on the shell
    # and returns the result.
    #
    # If the operation throws an exception or the operation yields a non-zero exit code
    # we rethrow a +ScmError+ with a meaningful error message.
    def self.ssh_capture(*params)
      output, err, code = capture_out('ssh', *ssh_shell_params.concat(params))
      if code != 0
        error_msg = "Non-zero exit code #{code} for `ssh #{params.join(' ')}`"
        logger.error(error_msg)
        logger.debug("Error output is #{err}")
        raise ::OpenProject::Scm::Exceptions::CommandFailed.new('ssh', error_msg)
      end

      output
    end

    # Returns the ssh prefix arguments for all ssh_* commands
    #
    # These are as follows:
    # * (-T) Never request tty
    # * (-i <gitolite_ssh_private_key>) Use the SSH keys given in Settings
    # * (-p <gitolite_server_port>) Use port from settings
    # * (-o BatchMode=yes) Never ask for a password
    # * <gitolite_user>@localhost (see +gitolite_url+)
    def self.ssh_shell_params
      [
        '-T', '-o', 'BatchMode=yes', gitolite_url, '-p',
        gitolite_server_port, '-i', gitolite_ssh_private_key
      ]
    end

    ##########################
    #                        #
    #   Gitolite Accessor    #
    #                        #
    ##########################

    def self.admin
      admin_dir = Setting.plugin_openproject_gitolite[:gitolite_admin_dir]
      logger.info("Acessing gitolite-admin.git at '#{admin_dir}'")
      Gitolite::GitoliteAdmin.new(admin_dir, gitolite_admin_settings)
    end

    WRAPPERS = [
      GitoliteWrapper::Admin, GitoliteWrapper::Repositories,
      GitoliteWrapper::Users, GitoliteWrapper::Projects
    ]

    # Update the Gitolite Repository
    #
    # action: An API action defined in one of the gitolite/* classes.
    def self.update(action, object, options = {})
      WRAPPERS.each do |wrappermod|
        if wrappermod.method_defined?(action)
          wrapper = wrappermod.new(action, object, options)

          if true?(:use_delayed_jobs)
            logger.info("Queueing delayed job '#{action}'")
            wrapper.delay.run
          else
            wrapper.run
          end
          return wrapper
        end
      end

      raise "No available Wrapper for action '#{action}' found."
    end

    ##########################
    #                        #
    #  Config Tests / Setup  #
    #                        #
    ##########################

    # Returns the gitolite welcome/info banner, containing its version.
    #
    # Upon error, returns the shell error code instead.
    def self.gitolite_banner
      ssh_capture('info')
    rescue => e
      errstr = "Error while getting Gitolite banner: #{e.message}"
      logger.error(errstr)
      errstr
    end

    def self.git_repositories
      Dir.chdir(gitolite_global_storage_path) do
        { repos: Dir.glob('**/*.git') }
      end
    rescue => e
      errstr = "Error while getting Gitolite repositories: #{e.message}"
      logger.error(errstr)
      { error: errstr }
    end
  end
end
