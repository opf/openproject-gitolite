class ManageGitRepositoriesController < ApplicationController

  before_action :find_project_by_project_id, :only => [:index]
  
  before_action :authorize, :only => :index

  before_action :require_login
  before_action :find_repository
  before_action :set_my_keys
  before_action :find_credentials
  before_action :find_post_receive_urls
  before_action :find_mirrors
  before_action :find_git_config_keys
  before_action :find_git_extra
  
  menu_item :manage_git_repositories, only: [:index]

  def index

    render layout: false if request.xhr?
  end


  private

  def set_my_keys
    @user = User.current
    @gitolite_deploy_keys = @user.gitolite_public_keys.deploy_key.order('title ASC, created_at ASC')
    
    @disabled_deployment_keys = @repository.repository_deployment_credentials.map(&:gitolite_public_key)
    
    @other_deployment_keys = []
    # Admin can use other's deploy keys as well
    @other_deployment_keys = other_deployment_keys if User.current.admin?

  end

  def find_repository
    @repository = @project.repository
    if @repository.nil?
      render_404
    end
  end
  
  def find_credentials
    @repository_deployment_credentials = @repository.repository_deployment_credentials.all
  end
  
  def other_deployment_keys
    users_allowed_to_create_public_deployment_ssh_keys.map { |user| user.gitolite_public_keys.deploy_key.order('title ASC') }.flatten
  end

  def users_allowed_to_create_public_deployment_ssh_keys
    @project.users.select { |user| user != User.current && user.allowed_to?(:create_repository_deployment_credentials, @project) }
  end

  def find_post_receive_urls
    @repository_post_receive_urls = @repository.repository_post_receive_urls.all
  end
  
  def find_mirrors
    @repository_mirrors = @repository.repository_mirrors.all
  end
  
  def find_git_config_keys
    @repository_git_config_keys = @repository.repository_git_config_keys.all
  end
  
  def find_git_extra
    @git_extra = @repository.extra
  end
end
