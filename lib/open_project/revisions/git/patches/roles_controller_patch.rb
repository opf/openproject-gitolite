module OpenProject::Revisions::Git
  module Patches
    module RolesControllerPatch

      def self.included(base)
        base.class_eval do
          include InstanceMethods

          alias_method_chain :notify_changed_roles,   :revisions_git
        end
      end

      module InstanceMethods

        private

        # Send the propper notification
        def notify_changed_roles_with_revisions_git(action, changed_role)
          # Previous rutine (perhaps this is not necessary)
          notify_changed_roles_without_revisions_git(action, changed_role)

          # Sends the notification
          OpenProject::Notifications.send('roles_changed', action: action, role: changed_role)
        end

      end
    end
  end
end

RolesController.send(:include, OpenProject::Revisions::Git::Patches::RolesControllerPatch)
