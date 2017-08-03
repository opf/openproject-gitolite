class GitolitePublicKey < ActiveRecord::Base

  KEY_TYPE_USER = 0
  KEY_TYPE_DEPLOY = 1

  DEPLOY_PSEUDO_USER = 'deploy_key'

  belongs_to :user
  has_many   :repository_deployment_credentials, dependent: :destroy

  scope :user_key,   -> { where key_type: KEY_TYPE_USER }
  scope :deploy_key, -> { where key_type: KEY_TYPE_DEPLOY }

  validates_presence_of :title, :identifier, :key, :key_type
  validates_inclusion_of :key_type, in: [KEY_TYPE_USER, KEY_TYPE_DEPLOY]

  validates_uniqueness_of :title,      scope: :user_id

  validates_format_of :title, with: /\A[a-z0-9_\-]*\z/i

  validate :has_not_been_changed?
  validate :key_correctness
  validate :key_uniqueness

  before_validation :set_fingerprint
  before_validation :set_identifier
  before_validation :strip_whitespace
  before_validation :remove_control_characters

  after_commit ->(obj) { obj.add_ssh_key },     on: :create
  after_commit ->(obj) { obj.destroy_ssh_key }, on: :destroy

  def self.by_user(user)
    where('user_id = ?', user.id)
  end

  def self.valid_title_from(title)
    title.underscore.gsub(/[^0-9a-zA-Z\-_]/, '_')
  end

  # Returns the path to this key under the gitolite keydir
  # resolves to <user.gitolite_identifier>/<title>/<identifier>.pub
  #
  # The root folder for this user is the user's identifier
  # for logical grouping of their keys, which are organized
  # by their title in subfolders.
  #
  # This is due to the new gitolite multi-keys organization
  # using folders. See http://gitolite.com/gitolite/users.html
  def key_path
    File.join(user.gitolite_identifier, title, identifier)
  end

  def to_s
    title
  end

  # Returns the unique identifier for this key based on the key_type
  #
  # For user public keys, this simply is the user's gitolite_identifier.
  # For deployment keys, this is a combination of the user's gitolite_identifier, the key's fingerprint and current time.
  def set_identifier
    time_tag = "#{Time.now.to_s}".gsub(/[^0-9]/,'')[0,14]
    fingerprint_tag = "#{fingerprint}".gsub(/[^0-9a-zA-Z]/,'')[-6,6]
    self.identifier ||=
      begin
        case key_type
        when KEY_TYPE_USER
          user.gitolite_identifier
          #"#{user.gitolite_identifier}_#{fingerprint_tag}_#{time_tag}"
        when KEY_TYPE_DEPLOY
          "#{user.gitolite_identifier}_#{fingerprint_tag}_#{time_tag}_#{DEPLOY_PSEUDO_USER}"
        end
      end
  end

  # Key type checking functions
  def user_key?
    key_type == KEY_TYPE_USER
  end

  def deploy_key?
    key_type == KEY_TYPE_DEPLOY
  end

  protected

  def add_ssh_key
    OpenProject::Gitolite::GitoliteWrapper.update(:add_ssh_key, self)
  end

  def destroy_ssh_key
    OpenProject::Gitolite::GitoliteWrapper.logger.info("User '#{User.current.login}' has deleted a SSH key")

    repo_key = {
      title: title, key: key,
      location: title, owner: identifier,
      identifier: identifier
    }

    OpenProject::Gitolite::GitoliteWrapper.update(:delete_ssh_key, repo_key)
  end

  private

  def set_fingerprint
    Tempfile.create('gitolite_publickey') do |f|
      f.write(key)
      f.close
      # This will throw if exitcode != 0
      output, = OpenProject::Gitolite::GitoliteWrapper.capture_out('ssh-keygen', '-lf',
                                                                        f.path)
      if output
        self.fingerprint = output.split[1]
      end
    end
  rescue => e
    Rails.logger.error("Could not validate SSH public key: #{e.message}")
  ensure
    if !fingerprint
      errors.add(:key, l(:error_key_corrupted))
    end
  end

  # Strip leading and trailing whitespace
  def strip_whitespace
    self.title = title.strip

    # Don't mess with existing keys (since cannot change key text anyway)
    if new_record?
      self.key = key.strip
    end
  end

  # Remove control characters from key
  def remove_control_characters
    # Don't mess with existing keys (since cannot change key text anyway)
    return if !new_record?

    # First -- let the first control char or space stand (to divide key type from key)
    # Really, this is catching a special case in which there is a \n between type and key.
    # Most common case turns first space back into space....
    self.key = key.sub(/[ \r\n\t]/, ' ')

    # Next, if comment divided from key by control char, let that one stand as well
    # We can only tell this if there is an "=" in the key. So, won't help 1/3 times.
    self.key = key.sub(/=[ \r\n\t]/, '= ')

    # Delete any remaining control characters....
    self.key = key.gsub(/[\a\r\n\t]/, '').strip
  end

  def has_not_been_changed?
    unless new_record?
      has_errors = false

      %w(identifier key user_id key_type).each do |attribute|
        method = "#{attribute}_changed?"
        if send(method)
          errors.add(attribute, 'may not be changed')
          has_errors = true
        end
      end

      return has_errors
    end
  end

  def key_correctness
    # Test correctness of fingerprint from output
    # and general ssh-(r|d|ecd)sa <key> <id> structure
    (fingerprint =~ /^(\w{2}:?)+$/i) &&
      (key.match(/^(\S+)\s+(\S+)/))
  end

  def key_uniqueness
    return if !new_record?

    existing = GitolitePublicKey.find_by_fingerprint(fingerprint)
    if existing
      determine_duplicate_error(existing)
      false
    else
      true
    end
  end

  # Determine the reason of a duplicate error
  # and print it to the user.
  # Avoids display the username of the existing fingerprint
  # unless current user is admin
  def determine_duplicate_error(existing)
    if existing.user == User.current
      errors.add(:key, l(:error_key_in_use_by_you, name: existing.title))
    elsif User.current.admin?
      errors.add(:key, l(:error_key_in_use_by_other, login: existing.user.login, name: existing.title))
    else
      errors.add(:key, l(:error_key_in_use_by_someone))
    end
  end
end
