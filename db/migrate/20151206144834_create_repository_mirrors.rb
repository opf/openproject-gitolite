class CreateRepositoryMirrors < ActiveRecord::Migration[4.2]
  
  def self.up
    create_table :repository_mirrors do |t|
      t.references :repository

      t.column :active, :integer, :default => 1
      t.column :url, :string
      t.column :push_mode, :integer, :default => 0
      t.column :include_all_branches, :boolean, :default => false
      t.column :include_all_tags, :boolean, :default => false
      t.column :explicit_refspec, :string, :default => ""
      t.timestamps :null => false
    end
    
    add_index :repository_mirrors, :repository_id
  end

  def self.down
    drop_table :repository_mirrors
  end

end
