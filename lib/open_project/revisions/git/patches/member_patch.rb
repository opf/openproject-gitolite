module OpenProject::Revisions::Git
  module Patches
    module MemberPatch

      def self.included(base)
        base.class_eval do
          include InstanceMethods

          alias_method_chain :save_notification,   :revisions_git
          alias_method_chain :destroy_notification,   :revisions_git
        end
      end

      module InstanceMethods

        private

        # Send the propper notification
        def save_notification_with_revisions_git(&block)
          # Previous rutine (perhaps this is not necessary)
          save_notification_without_revisions_git(&block)

          # Sends the notification
          ::OpenProject::Notifications.send('member_updated', member: self)
        end

        def destroy_notification_with_revisions_git(&block)
          # Previous rutine (perhaps this is not necessary)
          destroy_notification_without_revisions_git(&block)

          # Sends the notification
          ::OpenProject::Notifications.send('member_removed', member: self)
        end

      end
    end
  end
end

Member.send(:include, OpenProject::Revisions::Git::Patches::MemberPatch)
