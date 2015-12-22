class Comment < ActiveRecord::Base
  belongs_to  :commenter,   :foreign_key  => :commenter_id, :class_name => Author

  has_many  :votes,         :as           => :votable

  has_many  :news_comments
  has_many  :news,          :through      => :news_comments

  validates_uniqueness_of   :id

  def closed?
    self.votes_closed?
  end

  def open?
    !self.closed?
  end

  # TODO Find a better way to assess this (we consider downvoted comments and those from deleted users nil too here)
  def complete?
    !self.incomplete?
  end

  def incomplete?
    self.commenter.disabled? || self.karma.nil?
  end

  def votes_closed?
    self.timestamp_creation <= 30.days.ago
  end

  def votes_open?
    !self.votes_closed?
  end

  def commenter_disabled?
    self.commenter.disabled?
  end

  #Deprecate
  def votes_available?
    self.vote_count == 0 || self.votes.count > 0
  end

  #Deprecate
  def votes_consistent?
    self.votes_available? && self.votes.count == self.vote_count
  end

  module Scopes
    def open
      where(:timestamp_creation => 30.days.ago..Time.now)
    end

    def closed
      where.not(:timestamp_creation => 30.days.ago..Time.now)
    end

    def last(time)
      where(:timestamp_creation => time..Time.now)
    end

    def incomplete
      where(:karma => nil, :vote_count => nil)
    end
  end
  extend Scopes

end
