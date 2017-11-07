# OpenProject gitolite Plugin
[![Code Climate](https://codeclimate.com/github/oliverguenther/openproject-gitolite/badges/gpa.svg)](https://codeclimate.com/github/oliverguenther/openproject-gitolite)
[![Dependency Status](https://gemnasium.com/oliverguenther/openproject-gitolite.svg)](https://gemnasium.com/oliverguenther/openproject-gitolite)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/oliverguenther/openproject-gitolite?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This plugin aims to provide extensive features for managing Git repositories within [OpenProject](http://www.openproject.org).
Forked from [jbox-web's version](https://jbox-web.github.io/redmine_git_hosting/) of the long-lived and often-forked redmine-git_hosting plugin (formerly redmine-gitosis).

As OpenProject has diverted quite a bit in terms of project management (e.g., Redmine allows multiple repositories per project), some features have been removed in the fork.

**Disclaimer**: This fork is still in progress. While some things work, it is by no means stable - Features may change anytime.

## Overview

* Depends on **Gitolite (v2/v3)**
* Acts as a **wrapper to the gitolite-admin** to feed Gitolite with SSH keys, repository information
* Employs **libgit2/rugged** through [gitolite-rugged](https://github.com/oliverguenther/gitolite-rugged).
* Employs **grack** through [gitlab-grack](https://github.com/jbox-web/grack.git).

## Features

**SSH Public-Key Management (Gitolite)**

✓ Multiple keys per user

**Gitolite Repository Management**

✓ Managing repositories with Gitolite upon creation, update/deletion (async w/ delayed_jobs)

✓ Members/Roles access written to Gitolite

✓ SSH-based access (through Gitolite)

✓ Post-Receive Hooks

✓ Repository Mirrors

✓ Deployment Credentials

✓ Git Config Keys

✓ Git Smart-HTTP (access through HTTP/HTTPS in OpenProject)

**Planned/Forked, but non-functional/non-tested features**

* Initialize Repositories with Readme

**Stripped/Changed features from jbox-web's version**

* Sidekiq (OpenProject uses delayed_jobs instead)
* SELinux (unfamiliar, can't provide a good fork)
* GitHub features (Issues), should be separate plugin
* Git access cache (belongs in the core)
* Repository Recycle bin after deletion (Just use your filesystem backups)
* Notifications/Mailing lists

## Installation

#### 0. (Preliminary) [Setup Gitolite v2/v3](http://gitolite.com/gitolite/install.html)

I'm assuming you have some basic knowledge of Gitolite and:

* **have built libgit2/rugged WITH SSH Transport support** (see https://github.com/libgit2/rugged/issues/299). This requires ``libssh2-dev`` to be installed on your system.
* are in possession of a SSH key pair set up for use with Gitolite.
* have successfully cloned the gitolite-admin.git repository from the user running OpenProject as follows:
```
git clone git@localhost:gitolite-admin /home/openproject/gitolite-admin.git
```


You must now add a few manual changes to the Gitolite setup for this plugin to work. **These changes are crucial**:

**0.a. Add include 'openproject.conf'** to Gitolite

OpenProject uses a separate Gitolite config file to declare repositories. This allows you to define your own stuff in ``<gitolite-admin.git>/conf/gitolite.conf`` and allows OpenProject to override its own configuration at all times.

Thus, you need to add the following line to ``conf/gitolite.conf`` under the gitolite-admin.git repository:

    include 'openproject.conf'
    
The ``openproject.conf`` is created and updated from this plugin and contains all projects with Git repositories later defined within OpenProject. Thus, the ``<gitolite-admin.git>/conf/`` folder will contain two files:

* ``gitolite.conf``: If you want to manually add projects outside the scope of OpenProject to Gitolite, define them here.
* ``openproject.conf``: Contains all projects defined from OpenProject, is generated automatically. (*Non-existent until this plugin creates it*)

**0.b. Change .gitolite.rc configuration**

We need to adjust a few things in the ``<git home>/.gitolite.rc`` configuration file.

OpenProject identifies project identifiers in Gitolite through Git config keys, thus you need to alter the .gitolite.rc (In the git user's $HOME) to allow that:

  a. As the git user, open $HOME/.gitolite.rc
  
  b. Change the configuration ``GIT_CONFIG_KEYS`` to ``'.*',``

  c. Change the configuration for ``UMASK`` to ``0007,`` to add group rwx permissions

  d. Change local code directory ``LOCAL_CODE`` to ``"$ENV{HOME}/local"`` in Gitolite 3

  e. Save the changes

**0.c. Change Gitolite .profile file**

As the git user, add this in ``<git home>/.profile``

    # set PATH so it includes user private bin if it exists
    if [ -d "$HOME/bin" ] ; then
      PATH="$PATH:$HOME/bin"
    fi

**0.d. Configure sudo**

As root create the file ``/etc/sudoers.d/openproject`` and put this content in it:

    Defaults:openproject !requiretty
    openproject ALL=(git) NOPASSWD:ALL

where ``openproject`` is the user running OpenProject and ``git`` the user running Gitolite. Then chmod the file:

    chmod 440 /etc/sudoers.d/openproject

**0.e. Install Ruby interpreter for post-receive hooks**

Our post-receive hook is triggered after each commit and is used to fetch changesets in OpenProject. As it is written in Ruby, you need to install Ruby on your server. Note that this does not conflict with RVM. Ruby 1.9.3 at least is required for the hooks as well as Ruby germ ``json``.

    sudo apt-get install ruby

#### 1. Gemfile.plugins

Add a Gemfile.plugins to your OpenProject root with the following contents:

    gem 'gitlab-grack', git: 'https://github.com/jbox-web/grack.git', require: 'grack', branch: 'fix_gemfile'
    gem 'redcarpet', '> 3.3.2'
    gem "openproject-gitolite", git: "https://github.com/opf/openproject-gitolite.git", branch: "release/7.3"

#### 2. Gitolite access rights

Ensure the user running OpenProject can read and write to the Gitolite repositories directory.
This is required for two reasons:

 1. Read the Git tree for browsing the repository
 2. Remove deleted repositories (Gitolite doesn't remove them)


We have already changed the configuration file ``gitolite.rc`` to set future permissions on repositories to 0770.
To set the permissions of the existing repositories folder:

    chmod -R 770 <git home>/repositories

Next, add OpenProject to the ``git`` group (assuming your Gitolite user is ``git`` and your OpenProject user is ``openproject``) to allow OpenProject to access the repositories.

    addgroup openproject git

Make sure you can access the repositories from openproject:

    su - openproject 
    ls -l <git home>/repositories

#### 3. Gitolite access

Make sure you can ssh into Gitolite from the openproject user. If you run the following command, the output below (or similar for Gitolite 2) should appear. **If it does not, this is a Gitolite configuration error.**

    openproject$ ssh -i <gitolite-admin SSH key> git@localhost info
    hello openproject, this is git@dev running gitolite3 v3.x-x on git x.x.x
        R W  gitolite-admin
        R W  testing


#### 4. Configuration of OpenProject

**4.a. OpenProject gzip/deflate (OpenProject 7.x)**

We need to adjust ``Rack::Deflater`` in the ``<openproject home>/config/application.rb`` configuration file to prevent conflicts with SmartHTTP. Change the following lines (85-92):

    config.middleware.insert_before Rack::ETag,
                                    Rack::Deflater,
                                    if: lambda { |_env, _code, headers, _body|
                                      # Firefox fails to properly decode gzip attachments
                                      # We thus avoid deflating if sending gzip already.
                                      content_type = headers['Content-Type']
                                      content_type != 'application/x-gzip'
                                    }

with

    config.middleware.insert_before Rack::ETag,
                                    Rack::Deflater,
                                    if: lambda { |_env, _code, headers, _body|
                                      # Firefox fails to properly decode gzip attachments
                                      # We thus avoid deflating if sending gzip already.
                                      content_type = headers['Content-Type']
                                      truncated_content_type = content_type.to_s.empty? ? '' : content_type.truncate(18, omission: '')
                                      content_type != 'application/x-gzip' && truncated_content_type != 'application/x-git-'
                                    }

then restart the OpenProject server:

    touch ~/openproject/tmp/restart.txt

**4.b. Plugin settings**

Run OpenProject, go to **Administration > Plugins > gitolite** (click on configure)

Alter you configuration for Gitolite (Gitolite path, gitolite-admin.git path, etc.) accordingly and click save. Do not forget to go through all tabs of the configuration.

Install Gitolite hooks (click on 'Install hooks !' on tab Hooks), required by Post-receive URLs and Repository mirrors. They will be installed in the path indicated by 'Gitolite non-core hooks directory' on tab Storage (``local/`` in Gitolite 3 as previously configured indicted in ``.gitolite.rc``).

Set the proper permissions per role to gain access to the different features provided by gitolite.

#### 5. Using delayed_job

This plugin optionally allows to use delayed_jobs to run interactions with ``gitolite-admin.git`` asynchronously.
If you activate that feature in the setting (c.f., 'Use delayed_job'): Start the worker using this command (change ``RAILS_ENV``, if necessary) :

```
RAILS_ENV=production script/delayed_job start
```

[See the documentation of delayed_job for further options](https://github.com/collectiveidea/delayed_job#running-jobs).

#### 6. Config Test

Check that the output on the tab 'Config Test' looks good.
Note that many of the settings are not yet functional, and some values on Config Test are thus irrelevant.


## Basic Usage

#### Enabling Gitolite repositories

1. Log in as admin, go to **Administration > System settings > Repositories**.
2. Enable SCM Gitolite and disable Git (to manage all repositories through Gitolite).
3. Configure Checkout instructions for Gitolite.

#### Managing public SSH keys

1. Log in, go to My account (top right).
2. Select 'Public keys' in the menu on the left.
3. Add/Manage your public keys using the form.

#### Creating a Gitolite repository

1. Create project.
2. Go to repositories settings and select Gitolite + click create. This should automatically create the corresponding entry in the Gitolite configuration. A new submenu item will be displayed on the left to manage the Gitolite repository.
3. Use Members to add a member to the project. If that user has a public key on record, the corresponding access rights will be written to Gitolite.

#### Managing Gitolite repositories

1. Select 'Manage Gitolite repository' in the menu on the left, under 'Repository'.
2. Add/manage deployment credentials.
3. Add/manage post-receive URLs.
4. Add/manage repository mirrors.
5. Add/Manage Git config keys.

## Copyrights & License
OpenProject gitolite is completely free and open source and released under the [MIT License](https://github.com/opf/openproject-gitolite/blob/dev/LICENSE).

Copyright (c) 2014 Oliver Günther (mail@oliverguenther.de)

This plugin bases on the [Redmine Git Hosting plugin by Nicolas Rodriguez](https://github.com/jbox-web/redmine_git_hosting)

Copyright (c) 2013-2014 Nicolas Rodriguez (nrodriguez@jbox-web.com), JBox Web (http://www.jbox-web.com)

Copyright (c) 2011-2013 John Kubiatowicz (kubitron@cs.berkeley.edu)

Copyright (c) 2010-2011 Eric Bishop (ericpaulbishop@gmail.com)

Copyright (c) 2009-2010 Jan Schulz-Hofen, Rocket Rentals GmbH (http://www.rocket-rentals.de)
