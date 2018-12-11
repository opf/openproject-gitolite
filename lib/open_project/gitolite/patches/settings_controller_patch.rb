module OpenProject::Gitolite
  module Patches
    module SettingsControllerPatch
      def self.included(base)
        base.class_eval do

          include InstanceMethods

          helper :gitolite_plugin_settings
        end
      end
      
      module InstanceMethods
        def install_gitolite_hooks
          @plugin = Redmine::Plugin.find(params[:id])
          return render_404 unless @plugin.id == :openproject_gitolite
          @gitolite_checks = OpenProject::Gitolite::Config.install_hooks!
        end
      end
      
    end
  end
end

SettingsController.send(:include, OpenProject::Gitolite::Patches::SettingsControllerPatch)
