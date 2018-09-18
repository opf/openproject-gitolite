class ChangeGitHttpTypeToInt < ActiveRecord::Migration[4.2]

  def self.up
    # Allows the configuration of a repository for SmartHTTP: None, HTTP, HTTPS and Both
    add_column :repository_git_extras, :git_http_temp, :integer, default: 1, after: :git_daemon
    RepositoryGitExtra.reset_column_information
    RepositoryGitExtra.all.each do |p|
      if p.git_http == true
        git_http_temp = 1
      else
        git_http_temp = 0
      end
      say 'Update!'
      p.update_column(:git_http_temp, git_http_temp)
    end
    remove_column :repository_git_extras, :git_http
    rename_column :repository_git_extras, :git_http_temp, :git_http
  end
  
  def self.down
    add_column :repository_git_extras, :git_http_temp, :boolean, default: true, after: :git_daemon
    RepositoryGitExtra.reset_column_information
    RepositoryGitExtra.all.each do |p|
      if p.git_http > 0
        git_http_temp = true
      else
        git_http_temp = false
      end
      say 'Update!'
      p.update_column(:git_http_temp, git_http_temp)
    end
    remove_column :repository_git_extras, :git_http
    rename_column :repository_git_extras, :git_http_temp, :git_http
  end

end