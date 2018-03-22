module OpenProject::Gitolite
  module Patches
    module MemberPatch

      def self.included(base)
        base.prepend InstanceMethods
      end

      module InstanceMethods
        private

        # Send the propper notification
        def save_notification(&block)
          # Previous rutine (perhaps this is not necessary)
          super(&block)

          # Sends the notification
          ::OpenProject::Notifications.send('member_updated', member: self)
        end

        def destroy_notification(&block)
          # Previous rutine (perhaps this is not necessary)
          super(&block)

          # Sends the notification
          ::OpenProject::Notifications.send('member_removed', member: self)
        end

      end
    end
  end
end

Member.send(:include, OpenProject::Gitolite::Patches::MemberPatch)
