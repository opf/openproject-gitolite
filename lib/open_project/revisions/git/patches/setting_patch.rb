require 'fileutils'

module OpenProject::Revisions::Git
  module Patches
    module SettingPatch
      def self.included(base)
        base.class_eval do
          include InstanceMethods

          before_save :validate_settings
          after_commit :restore_revisions_git_values
          after_commit :fix_projects_without_settings
          after_commit :resync_all_ssh_keys
        end
      end

      module InstanceMethods
        private

        begin
          @@old_valuehash = Setting.plugin_openproject_revisions_git.clone
        rescue
          @@old_valuehash = {}
        end

        @@resync_projects = false
        @@configure_projects = false
        @@resync_ssh_keys = false
        @@delete_trash_repo = []

        def validate_settings
          # Only validate settings for our plugin
          return unless name == 'plugin_openproject_revisions_git'

          valuehash = value

          # Validate partials
          validate_server_names valuehash
          validate_gitolite_settings valuehash
          validate_git_config valuehash

          # Prepare any resync after sync
          prepare_resyncs valuehash

          # Prepare any configuration of settings
          prepare_configurations valuehash

          # Prepare any resync of ssh keys
          prepare_resync_all_ssh_keys valuehash

          # Save back results
          self.value = valuehash
        end

        def validate_server_names(valuehash)
          # Server domain should not include any path components. Also, ports should be numeric.
          [:https_server_domain, :ssh_server_domain, :http_server_domain].each do |setting|
            if valuehash[setting] && !valuehash[setting].empty?
              valuehash[setting] = valuehash[setting].lstrip.rstrip.split('/').first
            else
              valuehash[setting] = @@old_valuehash[setting]
            end
          end
        end

        def validate_gitolite_settings(valuehash)
          # Normalize paths, should be relative and end in '/'
          valuehash[:gitolite_global_storage_path] = File.join(valuehash[:gitolite_global_storage_path], '')

          # Validate ssh port > 0 and < 65537 (and exclude non-numbers)
          port = valuehash[:gitolite_server_port]
          if !port.to_i.between?(1, 65537)
            valuehash[:gitolite_server_port] = @@old_valuehash[:gitolite_server_port]
          end
        end

        def validate_git_config(valuehash)
          # Validate git author address
          if valuehash[:git_config_email].blank?
            valuehash[:git_config_email] = Setting.mail_from.to_s.strip.downcase
          elsif !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(valuehash[:git_config_email])
            valuehash[:git_config_email] = @@old_valuehash[:git_config_email]
          end
        end

        def prepare_resyncs(valuehash)
          ## Rest force update requests
          @@resync_projects = valuehash[:gitolite_resync_all_projects] == 'true'
          valuehash[:gitolite_resync_all_projects] = 'false'
        end

        def prepare_configurations(valuehash)
          ## Rest configuration requests
          @@configure_projects = valuehash[:gitolite_configure_projects] == 'true'
          valuehash[:gitolite_configure_projects] = 'false'
        end

        def prepare_resync_all_ssh_keys(valuehash)
          ## Rest configuration requests
          @@resync_ssh_keys = valuehash[:gitolite_resync_all_ssh_keys] == 'true'
          valuehash[:gitolite_resync_all_ssh_keys] = 'false'
        end

        def restore_revisions_git_values
          # Only perform after-actions on settings for our plugin
          if name == 'plugin_openproject_revisions_git'
            valuehash = value

            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_projects == true
              resync_projects
              @@resync_projects = false
            end

            @@old_valuehash = valuehash.clone
          end
        end

        def fix_projects_without_settings
          # Only perform after-actions on settings for our plugin
          if name == 'plugin_openproject_revisions_git'
            valuehash = value
        
            ## A configuration of projects without proper settings has been asked within the interface, fix projects
            if @@configure_projects == true
              fix_project_settings
              @@configure_projects = false
            end
        
            @@old_valuehash = valuehash.clone
          end
        end

        def resync_projects
          # Need to update everyone!
          projects = Project.active.includes(:repository).all
          if projects.length > 0
            OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
              "Forced resync of all projects (#{projects.length})..."
            )
            OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
          end
        end

        def fix_project_settings
          # Need to fix some projects!
          projects = Project.active.includes(:repository).all
          total_project_fixed = 0
          if projects.length > 0
            OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
              "Forced configuration of projects. Analyzing #{projects.length} project(s) with Git repositories..."
            )

            projects.each do |project|
              next unless project.repository.is_a?(Repository::Gitolite)
    
              if project.repository.extra.nil?
                total_project_fixed += 1
                OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Project #{project.name} not configured properly, generating configuration..." )
                project.repository.build_extra
                project.repository.extra.set_values_for_existing_repo
                project.repository.save
              end
              
            end
            OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
              "Forced configuration of projects finished. A total of #{total_project_fixed} project(s) with errors were found and fixed."
            )
            
            
          end
        end

        def resync_all_ssh_keys
          # Need to update everyone!
          OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_ssh_keys_forced, GitolitePublicKey.all.length)
        end

      end
    end
  end
end

Setting.send(:include, OpenProject::Revisions::Git::Patches::SettingPatch)
