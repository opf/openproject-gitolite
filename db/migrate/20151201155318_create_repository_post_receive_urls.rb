class CreateRepositoryPostReceiveUrls < ActiveRecord::Migration[4.2]

  def self.up
    create_table :repository_post_receive_urls do |t|
      t.references :repository
      
      t.column :active, :integer, :default => 1
      t.column :url, :string
      t.column :mode, :string, :default => "github"
      t.timestamps :null => false
    end
	  
    add_index :repository_post_receive_urls, :repository_id
  end

  def self.down
    drop_table :repository_post_receive_urls
  end
end
