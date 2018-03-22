class CreateRepositoryDeploymentCredentials < ActiveRecord::Migration[4.2]

  def self.up
    create_table :repository_deployment_credentials do |t|
      t.references :repository
      t.references :gitolite_public_key
      t.references :user

      t.column :active, :integer, default: 1
      t.column :perm,   :string, null: false
    end

    add_index :repository_deployment_credentials, :repository_id
    #The name of the index in next line is too big, it produces an error 
    #add_index :repository_deployment_credentials, :gitolite_public_key_id

  end

  def self.down
    drop_table :repository_deployment_credentials

  end

end
