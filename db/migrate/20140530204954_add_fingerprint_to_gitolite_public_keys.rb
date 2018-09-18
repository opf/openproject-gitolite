class AddFingerprintToGitolitePublicKeys < ActiveRecord::Migration[4.2]
  def self.up
    add_column :gitolite_public_keys, :fingerprint, :string, null: true
    add_index :gitolite_public_keys, :fingerprint

    # in case we migrated existing public keys before
    GitolitePublicKey.all.each do |key|
      key.send :set_fingerprint

      if key.fingerprint
        key.update_column :fingerprint, key.fingerprint
      else
        Rails.logger.warn "Failed to migrate invalid key #{key.id}"
        key.delete
      end
    end

    change_column_null :gitolite_public_keys, :fingerprint, false
  end

  def self.down
    remove_index :gitolite_public_keys, :fingerprint
    remove_column :gitolite_public_keys, :fingerprint
  end
end
