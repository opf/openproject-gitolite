module OpenProject::Gitolite
  module Patches
    module MyControllerPatch
      def self.included(base)
        base.prepend InstanceMethods

        base.class_eval do
          helper :gitolite_public_keys
        end
      end

      module InstanceMethods
        def account(&block)
          # Previous routine
          super(&block)

          # Set public key values for view
          set_public_key_values
        end

        private

        # Add in values for viewing public keys:
        def set_public_key_values
          @gitolite_user_keys   = @user.gitolite_public_keys.order('title ASC, created_at ASC')
          @gitolite_deploy_keys = @user.gitolite_public_keys.order('title ASC, created_at ASC')
          @gitolite_public_keys = @gitolite_user_keys + @gitolite_deploy_keys
          @gitolite_public_key  = @gitolite_public_keys.detect { |x| x.id == params[:public_key_id].to_i }

          redirect_unless_key_exists?
        end

        def redirect_unless_key_exists?
          if @gitolite_public_key.nil?
            if params[:public_key_id]
              # public_key specified that doesn't belong to @user.  Kill off public_key_id and try again
              redirect_to public_key_id: nil, tab: nil
              return
            else
              @gitolite_public_key = GitolitePublicKey.new
            end
          end
        end
      end
    end
  end
end

MyController.send(:include, OpenProject::Gitolite::Patches::MyControllerPatch)
