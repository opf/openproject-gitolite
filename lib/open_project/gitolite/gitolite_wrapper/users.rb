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
      #Updating info from gitolite
      #This resets and reloads the updated information from Gitolite
      logger.debug("Before reset and reload (Starting forced update of all SSH keys): #{@admin.ssh_keys.size} key(s) in Gitolite...")
      @admin.reset!
      @admin.reload!
      logger.debug("After reset and reload (Starting forced update of all SSH keys): #{@admin.ssh_keys.size} key(s) in Gitolite...")

      users = User.includes(:gitolite_public_keys).all.select { |u| u.gitolite_public_keys.any? }
      logger.info("Starting forced update of SSH keys for #{users.size} user(s).")
      #Deletes all SSH keys found in file system
      filesystem_repo_keys = @admin.ssh_keys
      if filesystem_repo_keys.size > 0
        logger.info("Found #{filesystem_repo_keys.size} SSH key(s) in the file system. Removing it(them)...")
        #Deletes all SSH keys from Gitolite
        @admin.transaction do
          filesystem_repo_keys.each_value do |filesystem_repo_key|
            repo_key_to_delete = filesystem_repo_key.first
            logger.info("Removing SSH key '#{repo_key_to_delete.owner}@#{repo_key_to_delete.location}' from Gitolite...")
            @admin.rm_key(repo_key_to_delete)
          end
          gitolite_admin_repo_commit("Forced update of SSH keys - Removing old SSH keys from file system.")
        end
      end

      #After deleting all keys from filesystem, the keys are still in memory
      #This resets and reloads the updated information from Gitolite
      logger.debug("Before reset and reload (After removing all SSH keys from file system): #{@admin.ssh_keys.size} key(s) in Gitolite...")
      @admin.reset!
      @admin.reload!
      logger.debug("After reset and reload (After removing all SSH keys from file system): #{@admin.ssh_keys.size} key(s) in Gitolite...")
      
      #Re-creates the ssh keys
      new_added_keys = 0
      @admin.transaction do
        users.each do |user|
          user.gitolite_public_keys.each do |key|
            #Forced update of fingerprint for consistency
            #Old version of ssh-keygen genereates MD5 hash while newer versions generate SHA256 hash by default
            #Just clearing the fingerprint and saving the key will update the record with the correct fingerprint
            logger.info("Updating fingerprint for SSH key '#{key.identifier}@#{key.title}'...")
            key.fingerprint = ""
            key.save

            logger.info("Adding SSH key '#{key.identifier}@#{key.title}' to Gitolite...")
            add_gitolite_key(key)
            new_added_keys = new_added_keys + 1
          end
        end
        gitolite_admin_repo_commit("Updated SSH keys for #{users.size} user(s)")
      end
      logger.info("Finished forced update of #{new_added_keys} SSH key(s) for #{users.size} user(s).")
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
