class RepositoryMirrorsController < ApplicationController

  before_action :find_project
  before_action :find_repository
  before_action :find_mirror, only: [:edit, :update, :destroy, :push]

  def index
  end


  def show
  end


  def new
    @mirror = RepositoryMirror.new(repository_mirrors_allowed_params)
  end


  def create
    @mirror = RepositoryMirror.new(repository_mirrors_allowed_params)

    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def edit
    
  end

  
  def update
    if @mirror.active?
      @mirror.active = 0
    else
      @mirror.active = 1
    end
    
    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def destroy
    if @mirror.destroy
      flash[:notice] = 'Mirror deleted'
      redirect_to controller: 'manage_git_repositories', action: 'index'
    end
  end

  
  def push
    #flash[:notice] = 'Repository mirror pushed'
    (@push_failed,@shellout) = @mirror.push
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

    def repository_mirrors_allowed_params
      params.require(:repository_mirror).permit(:repository_id, :active, :url, :push_mode, :include_all_branches, :include_all_tags, :explicit_refspec)
    end
  
    def save_and_flash
      if @mirror.save
        flash[:notice] = 'Repository mirror saved'
      else
        flash[:error] = @mirror.errors.full_messages.to_sentence
      end
    end

  def find_mirror
    begin
      mirror = @repository.repository_mirrors.find(params[:mirror])
    rescue ActiveRecord::RecordNotFound => e
      render_404
    else
      @mirror = mirror
    end
  end

end
