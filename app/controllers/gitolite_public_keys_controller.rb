class GitolitePublicKeysController < ApplicationController
  include GitolitePublicKeysHelper

  before_action :require_admin
  before_action :find_gitolite_public_key, only: [:destroy]

  def create
    @user = User.find_by_id(gitolite_keys_allowed_params[:user_id])
    @gitolite_public_key = GitolitePublicKey.new(gitolite_keys_allowed_params)

    save_and_flash
    redirect_to url_for(controller: 'users', action: 'edit', id: gitolite_keys_allowed_params[:user_id], tab: 'keys')
  end

  def destroy
    if request.delete?

      if @gitolite_public_key.destroy
        flash[:notice] = l(:notice_public_key_deleted, title: view_context.keylabel(@gitolite_public_key)).html_safe
      end
      redirect_to :back
    end
  end

  private

  def gitolite_keys_allowed_params
    params.require(:gitolite_public_key).permit(:user_id, :title, :key, :key_type, :delete_when_unused)
  end
end
