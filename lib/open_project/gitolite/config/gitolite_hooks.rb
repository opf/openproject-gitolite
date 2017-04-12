module OpenProject::Gitolite
  module Config
    module GitoliteHooks
      extend self

      def gitolite_hooks_namespace
        'openprojectgitolite'
      end


      def gitolite_hooks_url
        [get_setting(:gitolite_hooks_url), '/githooks/post-receive/openproject'].join
      end


      def gitolite_hooks_debug
        get_setting(:gitolite_hooks_debug, true)
      end


      def gitolite_hooks_are_asynchronous
        get_setting(:gitolite_hooks_are_asynchronous, true)
      end


      def gitolite_overwrite_existing_hooks?
        get_setting(:gitolite_overwrite_existing_hooks, true)
      end


      def gitolite_local_code_dir
        @gitolite_local_code_dir ||= OpenProject::Gitolite::Commands.sudo_gitolite_query_rc('LOCAL_CODE')
      end


      def gitolite_hooks_dir
        if gitolite_version == 3
          File.join(gitolite_local_code_dir, 'hooks', 'common')
        else
          File.join(gitolite_home_dir, '.gitolite', 'hooks', 'common')
        end
      end


      def check_hooks_install!
        {
          hook_files:    OpenProject::Gitolite::GitoliteHooks.hooks_installed?,
          global_params: OpenProject::Gitolite::GitoliteParams::GlobalParams.new.installed?,
          mailer_params: OpenProject::Gitolite::GitoliteParams::MailerParams.new.installed?
        }
      end


      def install_hooks!
        {
          hook_files:    OpenProject::Gitolite::GitoliteHooks.install_hooks!,
          global_params: OpenProject::Gitolite::GitoliteParams::GlobalParams.new.install!,
          mailer_params: OpenProject::Gitolite::GitoliteParams::MailerParams.new.install!
        }
      end


      def update_hook_params!
        OpenProject::Gitolite::GitoliteParams::GlobalParams.new.install!
      end

    end
  end
end
