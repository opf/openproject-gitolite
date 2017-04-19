module OpenProject::Gitolite::GitoliteWrapper
  class Users < Admin
    def add_ssh_key
      key = @object_id
      logger.info("Adding SSH key for user '#{key.user.login}'")
      @admin.transaction do
        add_gitolite_key(key)
        gitolite_admin_repo_commit("#{key.title} for #{key.user.login}")
      end
    end

    def delete_ssh_key
      key = @object_id
      logger.info("Deleting SSH key #{key[:identifier]}")
      @admin.transaction do
        remove_gitolite_key(key)
        gitolite_admin_repo_commit("#{key[:title]}")
      end
    end

    def update_all_ssh_keys_forced
      users = User.includes(:gitolite_public_keys).all.select { |u| u.gitolite_public_keys.any? }
      logger.info("Starting forced update of SSH keys for #{users.size} users.")
      #Deletes directory with all keys (it does not work, directory is deleted after keys are re-created)
      #@admin.transaction do
      #  ssh_keys_dir = File.join(Setting.plugin_openproject_gitolite[:gitolite_admin_dir], @admin.relative_key_dir)
      #  logger.info("Deleting directory with SSH keys: #{ssh_keys_dir}")
      #  FileUtils.remove_dir(ssh_keys_dir)
      #  gitolite_admin_repo_commit("Deleted all SSH keys for #{users.size} users")
      #end
      #Re-creates the ssh keys
      @admin.transaction do
        users.each do |user|
          user.gitolite_public_keys.each do |key|
            add_gitolite_key(key)
          end
        end
        gitolite_admin_repo_commit("Updated SSH keys for #{users.size} users")
      end
      logger.info("Finished forced update of SSH keys for #{users.size} users.")
    end

    private

    def add_gitolite_key(key)
      repo_keys = @admin.ssh_keys[key.identifier]
      repo_key = repo_keys.select { |k| k.location == key.title && k.owner == key.identifier }.first
      if repo_key
        logger.info("#{@action} : SSH key '#{key.identifier}@#{key.title}' exists, removing first ...")
        @admin.rm_key(repo_key)
      end

      save_key(key)
    end

    def save_key(key)
      parts = key.key.split
      repo_key = Gitolite::SSHKey.new(parts[0], parts[1], parts[2], key.identifier, key.title)
      @admin.add_key(repo_key)
    end

    def remove_gitolite_key(key)
      repo_keys = @admin.ssh_keys[key[:owner]]
      repo_key = repo_keys.select { |k| k.location == key[:location] && k.owner == key[:owner] }.first

      if repo_key
        @admin.rm_key(repo_key)
      else
        logger.info("#{@action} : SSH key '#{key[:owner]}@#{key[:location]}' does not exits in Gitolite, exit !")
        false
      end
    end
  end
end
