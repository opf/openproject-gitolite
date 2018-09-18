module GitolitePublicKeysHelper
  def keylabel(key)
    if key.user == User.current
      "'#{key.title}'"
    else
      "'#{key.user.login}@#{key.title}'"
    end
  end

  def keylabel_text(key)
    if key.user == User.current
      "#{key.title}"
    else
      "#{key.user.login}@#{key.title}"
    end
  end

  def set_user_keys
    @gitolite_user_keys   = @user.gitolite_public_keys.user_key.order('title ASC, created_at ASC')
    @gitolite_deploy_keys = @user.gitolite_public_keys.deploy_key.order('title ASC, created_at ASC')
  end

  def find_gitolite_public_key
    key = GitolitePublicKey.find_by_id(params[:id])
    if key && (User.current == key.user || User.current.admin?)
      @gitolite_public_key = key
    elsif key
      render_403
    else
      render_404
    end
  end

  def save_and_flash
    if @gitolite_public_key.save
      flash[:notice] = l(:notice_public_key_created, title: view_context.keylabel(@gitolite_public_key)).html_safe
    else
      flash[:error] = @gitolite_public_key.errors.full_messages.to_sentence
    end
  end

  def can_create_public_user_ssh_keys_for_some_project(theuser = User.current)
    theuser.projects_by_role.each_key do |role|
      return true if role.allowed_to?(:create_public_user_ssh_keys)
    end
    false
  end

  def can_create_public_deployment_ssh_keys_for_some_project(theuser = User.current)
    theuser.projects_by_role.each_key do |role|
      return true if role.allowed_to?(:create_public_deployment_ssh_keys)
    end
    false
  end
end
