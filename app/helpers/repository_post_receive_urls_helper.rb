module RepositoryPostReceiveUrlsHelper

  # Port-receive Mode
  def post_receive_mode(prurl)
    if prurl.active==0
      'Inactive'
    elsif prurl.mode == :github
      'Github-style POST'
    else
      'Empty GET request'
    end
  end
  
end
