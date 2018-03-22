class RepositoryPostReceiveUrlsController < ApplicationController

  before_action :find_project
  before_action :find_repository
  before_action :find_post_receive_url, only: [:edit, :update, :destroy]

  def index
  end


  def show
  end


  def new
    @post_receive_url = RepositoryPostReceiveUrl.new(repository_post_receive_urls_allowed_params)
  end


  def create
    @post_receive_url = RepositoryPostReceiveUrl.new(repository_post_receive_urls_allowed_params)

    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def edit
    
  end

  
  def update
    if @post_receive_url.active?
      @post_receive_url.active = 0
    else
      @post_receive_url.active = 1
    end
    
    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def destroy
    if @post_receive_url.destroy
      flash[:notice] = 'Post receive URL deleted'
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

    def repository_post_receive_urls_allowed_params
      params.require(:repository_post_receive_url).permit(:repository_id, :active, :url, :mode)
    end
  
    def save_and_flash
      if @post_receive_url.save
        flash[:notice] = 'Repository post receive URL saved'
      else
        flash[:error] = @post_receive_url.errors.full_messages.to_sentence
      end
    end

  def find_post_receive_url
    begin
      prurl = @repository.repository_post_receive_urls.find(params[:post_receive_url])
    rescue ActiveRecord::RecordNotFound => e
      render_404
    else
      @post_receive_url = prurl
    end
  end

end
