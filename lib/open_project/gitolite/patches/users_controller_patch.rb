module OpenProject::Gitolite
  module Patches
    module UsersControllerPatch
      include GitolitePublicKeysHelper

      def self.included(base)
        base.prepend InstanceMethods
      end

      module InstanceMethods
        def edit(&block)
          # Set public key values for view
          set_public_key_values

          # Previous routine
          super(&block)
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
