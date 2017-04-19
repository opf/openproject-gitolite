require_dependency 'open_project/scm/adapters'
require 'uri'
module OpenProject
  module Scm
    module Adapters
      class Gitolite < Git

        def checkout_url(repository, checkout_base_url, path)
          ssh_url(repository.repository_identifier).to_s
        end

        def self.git_command
          config[:client_command] || 'git'
        end

        def self.scm_version_from_command_line
          stdout, _ = Open3.capture3(git_command, '--version', '--no-color')
          stdout.chomp
        end

        private

        def ssh_url(git_path)
          URI::Generic.build(
            scheme: 'ssh',
            userinfo: Setting.plugin_openproject_gitolite[:gitolite_user],
            host: Setting.plugin_openproject_gitolite[:ssh_server_domain],
            path: "/#{git_path}"
          )
        end

        def git_url(git_path)
          URI::HTTP.build(
            scheme: 'git',
            host: Setting.plugin_openproject_gitolite[:ssh_server_domain],
            path: "/#{git_path}"
          )
        end

        def https_url(git_path)
          URI::HTTP.build(
            scheme: 'https',
            host: Setting.plugin_openproject_gitolite[:https_server_domain],
            path: "/#{git_path}"
          )
        end

        def available_urls(repository)
          hash = available_url_hash(repository)

          hash.delete :ssh if User.current.anonymous?
          hash.delete :https unless repository.extra.present? && repository.extra[:git_http]
          hash.delete :git unless repository.extra.present? && repository.extra[:git_daemon]

          hash
        end

        def available_url_hash(repository)
          commiter = User.current.allowed_to?(:commit_access, repository.project)

          {
            ssh: {
              url: ssh_url(repository.repository_identifier),
              command: ssh_clone_command,
              commiter: commiter
            },
            https: {
              url: https_url(repository.repository_identifier),
              command: https_url,
              commiter: commiter
            },
            git: {
              url: git_url(repository.repository_identifier),
              command: git_clone_command,
              commiter: false,
            }
          }
        end
      end
    end
  end
end
