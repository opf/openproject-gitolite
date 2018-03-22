class MyPublicKeysController < ApplicationController
  include GitolitePublicKeysHelper

  layout 'my'
  menu_item :public_keys

  before_action :require_login
  before_action :set_my_keys, only: [:index]
  before_action :find_gitolite_public_key, only: [:destroy]

  def create
    @gitolite_public_key = GitolitePublicKey.new(gitolite_keys_allowed_params.merge(user: User.current))
    save_and_flash
    redirect_to action: 'index'
  end

  def destroy
    if request.delete?
      if @gitolite_public_key.destroy
        flash[:notice] = l(:notice_public_key_deleted, title: view_context.keylabel(@gitolite_public_key)).html_safe
      end
      redirect_to action: 'index'

    end
  end

  private

  def set_my_keys
    @user = User.current
    set_user_keys
  end

  def gitolite_keys_allowed_params
    params.require(:gitolite_public_key).permit(:title, :key, :key_type, :delete_when_unused)
  end
end
