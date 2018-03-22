class RepositoryGitConfigKeysController < ApplicationController

  before_action :find_project
  before_action :find_repository
  before_action :find_git_config_key, only: [:edit, :update, :destroy]

  def index

  end


  def show

  end


  def new
    @git_config_key = RepositoryGitConfigKey.new(repository_git_config_keys_allowed_params)
  end


  def create
    @git_config_key = RepositoryGitConfigKey.new(repository_git_config_keys_allowed_params)

    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end


  def edit
    
  end


  def destroy
    if @git_config_key.destroy
      flash[:notice] = 'Git config key deleted'
      redirect_to controller: 'manage_git_repositories', action: 'index'
    end
  end

  private

    def find_project
      @project = Project.find(params[:project_id])
    end

    def find_repository
      @repository = @project.repository
      if @repository.nil?
        render_404
      end
    end

    def repository_git_config_keys_allowed_params
      params.require(:repository_git_config_key).permit(:repository_id, :key, :value)
    end

    def save_and_flash
      if @git_config_key.save
        flash[:notice] = 'Git config key saved'
      else
        flash[:error] = @git_config_key.errors.full_messages.to_sentence
      end
    end

    def find_git_config_key
      begin
        gckey = @repository.repository_git_config_keys.find(params[:git_config_key])
      rescue ActiveRecord::RecordNotFound => e
        render_404
      else
        @git_config_key = gckey
      end
    end
  
end
