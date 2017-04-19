module OpenProject::Gitolite
  module Patches
    module UsersHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :user_settings_tabs, :git
        end
      end

      module InstanceMethods
        # Add a public_keys tab to the user administration page
        def user_settings_tabs_with_git(&block)
          tabs = user_settings_tabs_without_git(&block)
          tabs << { name: 'keys', partial: 'gitolite_public_keys/form', label: :label_public_keys }
          tabs
        end
      end
    end
  end
end

UsersHelper.send(:include, OpenProject::Gitolite::Patches::UsersHelperPatch)
