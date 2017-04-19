module OpenProject::Gitolite
  module Patches
    module UsersControllerPatch
      include GitolitePublicKeysHelper

      def self.included(base)
        base.class_eval do
          include InstanceMethods

          alias_method_chain :edit,   :revisions_git
        end
      end

      module InstanceMethods
        def edit_with_revisions_git(&block)
          # Set public key values for view
          set_public_key_values

          # Previous routine
          edit_without_revisions_git(&block)
        end

        private

        # Add in values for viewing public keys:
        def set_public_key_values
          set_user_keys
        end
      end
    end
  end
end

UsersController.send(:include, OpenProject::Gitolite::Patches::UsersControllerPatch)
