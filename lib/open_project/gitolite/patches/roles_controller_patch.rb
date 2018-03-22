module OpenProject::Gitolite
  module Patches
    module RolesControllerPatch

      def self.included(base)
        base.prepend InstanceMethods
      end

      module InstanceMethods
        private

        # Send the propper notification
        def notify_changed_roles(action, changed_role)
          # Previous rutine (perhaps this is not necessary)
          super(action, changed_role)

          # Sends the notification
          OpenProject::Notifications.send('roles_changed', action: action, role: changed_role)
        end

      end
    end
  end
end

RolesController.send(:include, OpenProject::Gitolite::Patches::RolesControllerPatch)
