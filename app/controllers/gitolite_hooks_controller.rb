require 'json'
require 'net/http'
require 'net/https'
require 'uri'

include ActionView::Helpers::TextHelper

class GitoliteHooksController < ApplicationController

  layout nil
  
  skip_before_filter :verify_authenticity_token, :check_if_login_required, :except => :test
  before_filter  :find_project_and_repository

  def post_receive
    if not @repository.extra.validate_encoded_time(params[:clear_time], params[:encoded_time])
      render(:text => "The hook key provided is not valid. Please let your server admin know about it")
      return
    end

    self.response.headers["Content-Type"] = "text/plain;"
    self.response.headers['Last-Modified'] = Time.now.ctime.to_s
    self.response.headers['Cache-Control'] = 'no-cache'
    self.response.status = 200
    self.response_body = Enumerator.new do |body|

      # Fetch commits from the repository
      GitHosting.logger.debug "Fetching changesets for #{@project.name}'s repository"
      body << "Fetching changesets for #{@project.name}'s repository ... "
      begin
        @repository.fetch_changesets
      rescue Redmine::Scm::Adapters::CommandFailed => e
        GitHosting.logger.error "scm: error during fetching changesets: #{e.message}"
      end
      body << "Done\n"

      payloads = []
      if @repository.repository_mirrors.has_explicit_refspec.any? or @repository.repository_post_receive_urls.any?
        payloads = post_receive_payloads(params[:refs])
      end

      # Push to each repository mirror
      @repository.repository_mirrors.where(active: 1).order(active: :desc, created_at: :asc).each {|mirror|
        if mirror.needs_push payloads
          GitHosting.logger.debug "Pushing changes to #{mirror.url} ... "
          body << "Pushing changes to mirror #{mirror.url} ... "

          (mirror_err, mirror_message) = mirror.push

          result = mirror_err ? "Failed!\n" + mirror_message : "Done\n"
          body << result
        end
      } if @repository.repository_mirrors.any?

      # Post to each post-receive URL
      @repository.repository_post_receive_urls.where(active: 1).order(active: :desc, created_at: :asc).each {|prurl|
        if prurl.mode == :github
          msg = "Sending #{pluralize(payloads.length,'notification')} to #{prurl.url} ... "
        else
          msg = "Notifying #{prurl.url} ... "
        end
        body << msg

        uri = URI(prurl.url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')

        errmsg = nil
        payloads.each {|payload|
          begin
            if prurl.mode == :github
              request = Net::HTTP::Post.new(uri.request_uri)
              request.set_form_data({"payload" => payload.to_json})
            else
              request = Net::HTTP::Get.new(uri.request_uri)
            end
            res = http.start {|openhttp| openhttp.request request}
            errmsg = "Return code: #{res.code} (#{res.message})." if !res.is_a?(Net::HTTPSuccess)
          rescue => e
            errmsg = "Exception: #{e.message}"
          end
          break if errmsg || prurl.mode != :github
        }
        if errmsg
          body << "[failure] done\n"
          GitHosting.logger.error "[ #{msg}Failed!\n  #{errmsg} ]"
        else
          body << "[success] done\n"
          GitHosting.logger.info "[ #{msg}Succeeded! ]"
        end
      } if @repository.repository_post_receive_urls.any?

    end
  end

  protected

  # Returns an array of GitHub post-receive hook style hashes
  # http://help.github.com/post-receive-hooks/
  def post_receive_payloads(refs)
    payloads = []
    refs.each do |ref|
      oldhead, newhead, refname = ref.split(',')

      # Only pay attention to branch updates
      next if not refname.match(/refs\/heads\//)
      branch = refname.gsub('refs/heads/', '')

      if newhead.match(/^0{40}$/)
        # Deleting a branch
        GitHosting.logger.debug "Deleting branch \"#{branch}\""
        next
      elsif oldhead.match(/^0{40}$/)
        # Creating a branch
        GitHosting.logger.debug "Creating branch \"#{branch}\""
        range = newhead
      else
        range = "#{oldhead}..#{newhead}"
      end

      # Grab the repository path
      gitolite_repos_root = OpenProject::Gitolite::GitoliteWrapper.gitolite_global_storage_path
      repo_path = @repository.url
      revisions_in_range = %x[#{GitHosting.git_exec} --git-dir='#{repo_path}' rev-list --reverse #{range}]
      #GitHosting.logger.debug "Revisions in Range: #{revisions.split().join(' ')}"

      commits = []
      revisions_in_range.split().each do |rev|
        revision = @repository.find_changeset_by_name(rev.strip)
        commit = {
                  :id => revision.revision,
                  :url => url_for(:controller => "repositories", :action => "revision",
                                  :id => @project, :rev => rev, :only_path => false,
                                  :host => Setting['host_name'], :protocol => Setting['protocol']
                                 ),
                  :author => {
                              :name => revision.committer.gsub(/^([^<]+)\s+.*$/, '\1'),
                              :email => revision.committer.gsub(/^.*<([^>]+)>.*$/, '\1')
                              },
                  :message => revision.comments,
                  :timestamp => revision.committed_on,
                  :added => [],
                  :modified => [],
                  :removed => []
        }
        revision.changes.each do |change|
          if change.action == "M"
            commit[:modified] << change.path
          elsif change.action == "A"
            commit[:added] << change.path
          elsif change.action == "D"
            commit[:removed] << change.path
          end
        end
        commits << commit
      end

      payloads << {
                   :before => oldhead,
                   :after => newhead,
                   :ref => refname,
                   :commits => commits,
                   :repository => {
                                   :description => @project.description,
                                   :fork => false,
                                   :forks => 0,
                                   :homepage => "Field removed from project settings",
                                   :name => @project.identifier,
                                   :open_issues => count_open_work_packages,
                                   :owner => {
                                              :name => Setting["app_title"],
                                              :email => Setting["mail_from"]
                                   },
                                   :private => !@project.is_public,
                                   :url => url_for(:controller => "repositories", :action => "show",
                                                   :id => @project, :only_path => false,
                                                   :host => Setting["host_name"], :protocol => Setting["protocol"]
                                                  ),
                                   :watchers => 0
                   }
      }
    end
    payloads
  end

  # Locate that actual repository that is in use here.
  # Notice that an empty "repositoryid" is assumed to refer to the default repo for a project
  def find_project_and_repository
    @project = Project.find_by_identifier(params[:projectid])
    if @project.nil?
      render(:text => "#{l(:label_project_not_found)} #{params[:projectid]}") if @project.nil?
      return
    end
    @repository = @project.repository  # Only repository if redmine < 1.4
    if @repository.nil?
      render_404
    end
  end

  private

  def count_open_work_packages
    open_wps = 0;
    if @project.work_packages.any?
      @project.work_packages.each do |wp|
        if !wp.closed?
          open_wps = open_wps + 1
        end
      end
    end
    open_wps
  end

end
