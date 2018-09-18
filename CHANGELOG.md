## 0.1.0 (unreleased)

Features:


  - Added a repositories listing on the config test page.
  - Showing the git clone URL in the repository sidebar

Changes:

  - **delayed_job can be disabled through the config and is disabled by default**
  - ** The relative git storage dir has been replaced with an absolute path setting for "Gitolite repositories base path" **
  - Repository::Git no longer store the url as a relative path from the
git home directory, but only the relative path below the base_path

Organizational Changes:

  - Major refactoring for rubocop compliance
  
### Breaking Changes:

** sudo requirement removed **

The Requirement for sudo from `openproject` to `git` user has been replaced with direct read/write access through gitolite.rc's `$UMASK` directive. When upgrading, follow these steps:

 1. The ``$UMASK`` directive within the `gitolite.rc` must be changed to `0007` for any subsequent updates to the repositories
 2. Any repository under `<git home>/repositories` directory permissions must be extended to `770`.
 3. The openproject user must be added to the git user group.