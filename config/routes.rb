OpenProject::Application.routes.draw do
  # User's own public key management
  scope '/my' do
    resources :public_keys, controller: 'my_public_keys', except: [:edit, :show, :update]
  end

  resources :public_keys, controller: 'gitolite_public_keys', except: [:edit, :show, :update]

  # Gitolite repository management
  scope 'projects/:project_id' do
    resources :manage_git_repository, controller: 'manage_git_repositories', only: :index

    resources :repository_git_extras, controller: 'repository_git_extras'
    resources :repository_deployment_credentials, controller: 'repository_deployment_credentials'
    resources :repository_post_receive_urls, controller: 'repository_post_receive_urls'
    get 'repository_mirrors/push', :to => 'repository_mirrors#push', as: 'push_repository_mirror'
    resources :repository_mirrors, controller: 'repository_mirrors'
    resources :repository_git_config_keys, controller: 'repository_git_config_keys'
  end

  # Gitolite hooks
  get 'settings/plugin/:id/install_gitolite_hooks', to: 'settings#install_gitolite_hooks', as: 'install_gitolite_hooks'
  post 'githooks/post-receive/:type/:projectid' => 'gitolite_hooks#post_receive'

  # Enable SmartHTTP Grack support
  mount Grack::Bundle.new({}), at: '/gitolite/', constraints: lambda { |request| /[-\/\w\.]+\.git\//.match(request.path_info) }, via: [:get, :post]

  # Handle non existing paths (still not sure if this will help)
  #match '/gitolite/' => redirect('/404'), via: [:get, :post]
  #match '/gitolite/*paths' => redirect('/404'), via: [:get, :post]
end
