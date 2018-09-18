module OpenProject::Gitolite
  module GitoliteParams
    module BaseParam

      private

        # Return a hash with global config parameters.
        #
        def get_git_config_params(namespace)
          OpenProject::Gitolite::Commands.sudo_get_git_global_params(namespace)
        end


        def set_git_config_param(namespace, key, value)
          OpenProject::Gitolite::Commands.sudo_set_git_global_param(namespace, key, value)
        end


        def unset_git_config_param(key)
          OpenProject::Gitolite::Commands.sudo_unset_git_global_param(key)
        end

    end
  end
end
