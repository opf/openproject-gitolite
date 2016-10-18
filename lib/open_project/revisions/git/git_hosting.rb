require 'net/ssh'
require 'tempfile'
require 'tmpdir'
require 'stringio'

module GitHosting
  TEMP_DATA_DIR = "/tmp/redmine_git_hosting" # In case settings not migrated (normally from settings)
  SCRIPT_DIR = ""                            # In case settings not migrated (normally from settings)
  SCRIPT_PARENT = "bin"

  # Used to register errors when pulling and pushing the conf file
  class GitHostingException < StandardError
  end

  @@logger = nil
  def self.logger
    @@logger ||= MyLogger.new
  end

  @@web_user = nil
  def self.web_user
    if @@web_user.nil?
      @@web_user = (%x[whoami]).chomp.strip
    end
    return @@web_user
  end

  def self.web_user=(setuser)
    @@web_user = setuser
  end

  def self.git_user
    Setting.plugin_openproject_revisions_git['gitolite_user']
  end

  @@mirror_pubkey = nil
  def self.mirror_push_public_key
    if @@mirror_pubkey.nil?

      %x[cat '#{Setting.plugin_openproject_revisions_git['gitolite_ssh_private_key']}' | #{GitHosting.git_user_runner} 'cat > ~/.ssh/gitolite_admin_id_rsa ' ]
      %x[cat '#{Setting.plugin_openproject_revisions_git['gitolite_ssh_public_key']}' | #{GitHosting.git_user_runner} 'cat > ~/.ssh/gitolite_admin_id_rsa.pub ' ]
      %x[ #{GitHosting.git_user_runner} 'chmod 600 ~/.ssh/gitolite_admin_id_rsa' ]
      %x[ #{GitHosting.git_user_runner} 'chmod 644 ~/.ssh/gitolite_admin_id_rsa.pub' ]

      pubk =    ( %x[cat '#{Setting.plugin_openproject_revisions_git['gitolite_ssh_public_key']}' ]  ).chomp.strip
      git_user_dir = ( %x[ #{GitHosting.git_user_runner} "cd ~ ; pwd" ] ).chomp.strip
      %x[ #{GitHosting.git_user_runner} 'echo "#{pubk}"  > ~/.ssh/gitolite_admin_id_rsa.pub ' ]
      %x[ echo '#!/bin/sh' | #{GitHosting.git_user_runner} 'cat > ~/.ssh/run_gitolite_admin_ssh']
      %x[ echo 'exec ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i #{git_user_dir}/.ssh/gitolite_admin_id_rsa        "$@"' | #{GitHosting.git_user_runner} "cat >> ~/.ssh/run_gitolite_admin_ssh"  ]
      %x[ #{GitHosting.git_user_runner} 'chmod 644 ~/.ssh/gitolite_admin_id_rsa.pub' ]
      %x[ #{GitHosting.git_user_runner} 'chmod 600 ~/.ssh/gitolite_admin_id_rsa']
      %x[ #{GitHosting.git_user_runner} 'chmod 700 ~/.ssh/run_gitolite_admin_ssh']

      @@mirror_pubkey = pubk.split(/[\t ]+/)[0].to_s + " " + pubk.split(/[\t ]+/)[1].to_s

    end
    @@mirror_pubkey
  end

  @@git_hosting_tmp_dir = nil
  @@previous_git_tmp_dir = nil
  def self.get_tmp_dir
    tmp_dir = (Setting.plugin_openproject_revisions_git['gitTempDataDir'] || TEMP_DATA_DIR)
    if (@@previous_git_tmp_dir != tmp_dir)
      @@previous_git_tmp_dir = tmp_dir
      @@git_hosting_tmp_dir = File.join(tmp_dir,git_user) + "/"
    end
    if !File.directory?(@@git_hosting_tmp_dir)
      %x[mkdir -p "#{@@git_hosting_tmp_dir}"]
      %x[chmod 700 "#{@@git_hosting_tmp_dir}"]
      %x[chown #{web_user} "#{@@git_hosting_tmp_dir}"]
    end
    return @@git_hosting_tmp_dir
  end

  @@git_hosting_bin_dir = nil
  @@previous_git_script_dir = nil
  def self.get_bin_dir
    script_dir = Setting.plugin_openproject_revisions_git['gitScriptDir'] || SCRIPT_DIR
    if @@previous_git_script_dir != script_dir
      @@previous_git_script_dir = script_dir
      @@git_bin_dir_writeable = nil

      # Directory for binaries includes 'SCRIPT_PARENT' at the end.
      # Further, absolute path adds additional 'git_user' component for multi-gitolite installations.
      if script_dir[0,1] == "/"
        @@git_hosting_bin_dir = File.join(script_dir, git_user, SCRIPT_PARENT) + "/"
      else
        @@git_hosting_bin_dir = File.join(Gem.loaded_specs['openproject-revisions_git'].full_gem_path.to_s, script_dir, SCRIPT_PARENT).to_s+"/"
      end
    end
    if !File.directory?(@@git_hosting_bin_dir)
      logger.info "Creating bin directory: #{@@git_hosting_bin_dir}, Owner #{web_user}"
      %x[mkdir -p "#{@@git_hosting_bin_dir}"]
      %x[chmod 750 "#{@@git_hosting_bin_dir}"]
      %x[chown #{web_user} "#{@@git_hosting_bin_dir}"]

      if !File.directory?(@@git_hosting_bin_dir)
        logger.error "Cannot create bin directory: #{@@git_hosting_bin_dir}"
      end
    end
    return @@git_hosting_bin_dir
  end

  @@git_bin_dir_writeable = nil
  def self.bin_dir_writeable?(*option)
    @@git_bin_dir_writeable = nil if option.length > 0 && option[0] == :reset
    if @@git_bin_dir_writeable == nil
      mybindir = get_bin_dir
      mytestfile = "#{mybindir}/writecheck"
      if (!File.directory?(mybindir))
      @@git_bin_dir_writeable = false
      else
        %x[touch "#{mytestfile}"]
        if (!File.exists?("#{mytestfile}"))
          @@git_bin_dir_writeable = false
        else
            %x[rm "#{mytestfile}"]
          @@git_bin_dir_writeable = true
        end
      end
    end
    @@git_bin_dir_writeable
  end

  def self.git_exec_path
    return File.join(get_bin_dir, "run_git_as_git_user")
  end

  def self.gitolite_ssh_path
    return File.join(get_bin_dir, "gitolite_admin_ssh")
  end
  def self.git_user_runner_path
    return File.join(get_bin_dir, "run_as_git_user")
  end

  def self.git_exec
    if !File.exists?(git_exec_path())
      update_git_exec
    end
    return git_exec_path()
  end
  def self.gitolite_ssh
    if !File.exists?(gitolite_ssh_path())
      update_git_exec
    end
    return gitolite_ssh_path()
  end
  def self.git_user_runner
    if !File.exists?(git_user_runner_path())
      update_git_exec
    end
    return git_user_runner_path()
  end


  def self.update_git_exec
    logger.info "Setting up #{get_bin_dir}"
    gitolite_key=Setting.plugin_openproject_revisions_git['gitolite_ssh_private_key']

    File.open(gitolite_ssh_path(), "w") do |f|
      f.puts "#!/bin/sh"
      f.puts "exec ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i #{gitolite_key} \"$@\""
    end if !File.exists?(gitolite_ssh_path())

    ##############################################################################################################################
    # So... older versions of sudo are completely different than newer versions of sudo
    # Try running sudo -i [user] 'ls -l' on sudo > 1.7.4 and you get an error that command 'ls -l' doesn't exist
    # do it on version < 1.7.3 and it runs just fine.  Different levels of escaping are necessary depending on which
    # version of sudo you are using... which just completely CRAZY, but I don't know how to avoid it
    #
    # Note: I don't know whether the switch is at 1.7.3 or 1.7.4, the switch is between ubuntu 10.10 which uses 1.7.2
    # and ubuntu 11.04 which uses 1.7.4.  I have tested that the latest 1.8.1p2 seems to have identical behavior to 1.7.4
    ##############################################################################################################################
    sudo_version_str=%x[ sudo -V 2>&1 | head -n1 | sed 's/^.* //g' | sed 's/[a-z].*$//g' ]
    split_version = sudo_version_str.split(/\./)
    sudo_version = 100*100*(split_version[0].to_i) + 100*(split_version[1].to_i) + split_version[2].to_i
    sudo_version_switch = (100*100*1) + (100 * 7) + 3

    File.open(git_exec_path(), "w") do |f|
      f.puts '#!/bin/sh'
      f.puts "if [ \"\$(whoami)\" = \"#{git_user}\" ] ; then"
      f.puts '    cmd=$(printf "\\"%s\\" " "$@")'
      f.puts '    cd ~'
      f.puts '    eval "git $cmd"'
      f.puts "else"
      if sudo_version < sudo_version_switch
        f.puts '    cmd=$(printf "\\\\\\"%s\\\\\\" " "$@")'
        f.puts "    sudo -u #{git_user} -i eval \"git $cmd\""
      else
        f.puts '    cmd=$(printf "\\"%s\\" " "$@")'
        f.puts "    sudo -u #{git_user} -i eval \"git $cmd\""
      end
      f.puts 'fi'
    end if !File.exists?(git_exec_path())

    # use perl script for git_user_runner so we can
    # escape output more easily
    File.open(git_user_runner_path(), "w") do |f|
      f.puts '#!/usr/bin/perl'
      f.puts ''
      f.puts 'my $command = join(" ", @ARGV);'
      f.puts ''
      f.puts 'my $user = `whoami`;'
      f.puts 'chomp $user;'
      f.puts 'if ($user eq "' + git_user + '")'
      f.puts '{'
      f.puts '    exec("cd ~ ; $command");'
      f.puts '}'
      f.puts 'else'
      f.puts '{'
      f.puts '    $command =~ s/\\\\/\\\\\\\\/g;'
      # Previous line turns \; => \\;
      # If old sudo, turn \\; => "\\;" to protect ';' from loss as command separator during eval
      if sudo_version < sudo_version_switch
        f.puts '    $command =~ s/(\\\\\\\\;)/"$1"/g;'
        f.puts "    $command =~ s/'/\\\\\\\\'/g;"
      end
      f.puts '    $command =~ s/"/\\\\"/g;'
      f.puts '    exec("sudo -u ' + git_user + ' -i eval \"$command\"");'
      f.puts '}'
    end if !File.exists?(git_user_runner_path())

    File.chmod(0550, git_exec_path())
    File.chmod(0550, gitolite_ssh_path())
    File.chmod(0550, git_user_runner_path())
    %x[chown #{web_user} -R "#{get_bin_dir}"]
  end

  class MyLogger
    # Prefix to error messages
    ERROR_PREFIX = "***> "

    # For errors, add our prefix to all messages
    def error(*progname, &block)
      if block_given?
      Rails.logger.error(*progname) { "#{ERROR_PREFIX}#{yield}".gsub(/\n/,"\n#{ERROR_PREFIX}") }
      else
      Rails.logger.error "#{ERROR_PREFIX}#{progname}".gsub(/\n/,"\n#{ERROR_PREFIX}")
      end
    end

    # Handle everything else with base object
    def method_missing(m, *args, &block)
      Rails.logger.send m, *args, &block
    end
  end
end
