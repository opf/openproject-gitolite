module OpenProject::Gitolite
  module Commands
    extend Commands::Base
    extend Commands::Git
    extend Commands::Gitolite
    extend Commands::Ssh
    extend Commands::Sudo
  end
end
