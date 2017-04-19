
require Rails.root.join('db', 'migrate', 'migration_utils', 'migration_squasher').to_s
require Rails.root.join('db', 'migrate', 'migration_utils', 'setting_renamer').to_s
require 'open_project/plugins/migration_mapping'
# This migration aggregates the migrations detailed in MIGRATION_FILES
class AggregatedGitHostingMigrations < ActiveRecord::Migration
  MIGRATION_FILES = <<-MIGRATIONS
    20091119162426_set_mirror_role_permissions.rb
    20091119162427_create_gitolite_public_keys.rb
    20091119162428_create_git_caches.rb
    20110726000000_extend_changesets_notified_cia.rb
    20110807000000_create_repository_mirrors.rb
    20110813000000_create_git_repository_extras.rb
    20110817000000_move_notified_cia_to_git_cia_notifications.rb
    20111119170948_add_indexes_to_gitolite_public_key.rb
    20120521000000_create_repository_post_receive_urls.rb
    20120521000010_set_post_receive_url_role_permissions.rb
    20120522000000_add_post_receive_url_modes.rb
    20120710204007_add_repository_mirror_fields.rb
    20120803043256_create_deployment_credentials.rb
    20120904060609_update_multi_repo_per_project.rb
    20130909195727_create_repository_git_notifications.rb
    20130909195828_rename_table_git_repository_extras.rb
    20130909195929_rename_table_deployment_credentials.rb
    20130910195930_add_columns_to_repository_git_extra.rb
    20130910195931_add_columns_to_repository_git_notification.rb
    20140305053200_remove_notify_cia.rb
    20140305083200_add_default_branch_to_repository_git_extra.rb
    20140306002300_create_repository_git_config_keys.rb
    20140327015700_create_github_issues.rb
    20140327015701_create_github_comments.rb
    20140417004100_enforce_models_constraints.rb
  MIGRATIONS

  OLD_PLUGIN_NAME = 'redmine_revisions_git'

  def up
    migration_names = OpenProject::Plugins::MigrationMapping.migration_files_to_migration_names(
      MIGRATION_FILES, OLD_PLUGIN_NAME
    )
    Migration::MigrationSquasher.squash(migration_names) do
      create_public_keys_schema
      create_repository_git_extras
      create_repository_config_keys

      Migration::SettingRenamer.rename(OLD_PLUGIN_NAME, 'plugin_openproject_gitolite')
    end
  end

  def create_repository_config_keys
    create_table :repository_git_config_keys do |t|
      t.references :repository, null: false
      t.column :key,   :string, null: false
      t.column :value, :string, null: false
    end
  end

  def create_repository_git_extras
    create_table :repository_git_extras do |t|
      t.references :repository, null: false
      t.column :git_daemon, :boolean, default: true
      t.column :git_http,   :boolean, default: true
      t.column :git_notify, :boolean, default: false
      t.column :default_branch, :string, null: false
      t.column :key, :string, null: false
    end
  end

  def create_public_keys_schema
    create_table :gitolite_public_keys do |t|
      t.column :title, :string, null: false
      t.column :identifier, :string, null: false
      t.column :key, :text, null: false
      t.column :key_type, :integer, null: false, default: GitolitePublicKey::KEY_TYPE_USER
      t.column :delete_when_unused, :boolean, default: true
      t.references :user, null: false
      t.timestamps
    end

    add_index :gitolite_public_keys, :user_id
    add_index :gitolite_public_keys, :identifier
  end

  def down
    drop_table :gitolite_public_keys
    drop_table :repository_git_extras
    drop_table :repository_git_config_keys
  end
end
