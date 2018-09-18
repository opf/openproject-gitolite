class RepositoryGitExtrasController < ApplicationController

  before_action :find_project
  before_action :find_repository
  before_action :find_git_extra, only: [:edit, :update]

  def index
  end


  def show
  end


  def new
  end


  def create
  end

  
  def edit
  end

  
  def update
    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def destroy
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

    def repository_git_extras_allowed_params
      params.require(:repository_git_extra).permit(:git_daemon, :git_http)
    end
  
    def save_and_flash
      @git_extra.update_attributes(repository_git_extras_allowed_params)
      if @git_extra.update_attributes(git_daemon: params[:repository_git_extra][:git_daemon], git_http: params[:repository_git_extra][:git_http])
        flash[:notice] = 'Repository options saved'
      else
        flash[:error] = @git_extra.errors.full_messages.to_sentence
      end
    end

  def find_git_extra
    @git_extra = @repository.extra
  end

end
