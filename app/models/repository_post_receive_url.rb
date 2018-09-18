require 'uri'

class RepositoryPostReceiveUrl < ActiveRecord::Base
  belongs_to :repository

  scope :active,   -> { where active: true }
  scope :inactive, -> { where active: false }

  validates_presence_of :repository_id

  validates_format_of :url, with: URI::regexp(%w(http https)), allow_blank: false
  validates_uniqueness_of :url, scope: [:repository_id]

  validates_associated :repository

  validates_inclusion_of :mode, in: [:github, :get]

  before_validation :strip_whitespace

  def to_s
    "#{repository.project.identifier}-#{url}"
  end

  def mode
    read_attribute(:mode).to_sym rescue nil
  end

  def mode=(value)
    write_attribute(:mode, (value.to_sym && value.to_sym.to_s))
  rescue
    nil
  end

  private

  # Strip leading and trailing whitespace
  def strip_whitespace
    self.url = url.strip
  end
end
