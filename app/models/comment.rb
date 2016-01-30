class Comment < ActiveRecord::Base
  belongs_to  :commenter,   :foreign_key  => :commenter_id, :class_name => Author

  has_many    :votes,         :as           => :votable

  has_many    :news_comments
  has_many    :news,          :through      => :news_comments
  #has_one     :news_comments
  #has_one     :news,        :through      => :news_comments

  validates_uniqueness_of   :id

  def votes_count
    self.vote_count
  end

  def news_index
    self.news_comments.first.news_index
  end

  def votes_positive
    self.votes.where('rate >= 0')
  end

  def votes_negative
    self.votes.where('rate < 0')
  end

  def closed?
    self.votes_closed?
  end

  def open?
    !self.closed?
  end

  def complete?
    self.commenter.disabled? || self.votes_complete? && !self.karma.nil?
  end

  def incomplete?
    !self.complete?
  end

  def faulty?
    self.faulty
  end

  def votes_closed?
    self.timestamp_creation <= 30.days.ago
  end

  def votes_open?
    !self.votes_closed?
  end

  def votes_complete?
    # self.vote_count == 0 is included in the second clause as database's count return zero if nothing is found
    self.votes_closed? && self.votes.count == self.vote_count
  end

  def votes_incomplete?
    !self.votes_complete?
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
    def open(delta_time=0)
      min_time = 30.days.ago + delta_time
      where('comments.timestamp_creation > ?', min_time)
    end

    def closed(delta_time=0)
      min_time = 30.days.ago + delta_time
      where('comments.timestamp_creation <= ?', min_time)
    end

    def last(time)
      where(:timestamp_creation => time..Time.now)
    end

    def complete
      where(:complete => TRUE)
    end

    def incomplete
      #where('complete IS NOT TRUE')
      where('comments.complete = 0 OR comments.complete IS NULL')
    end

    def faulty
      where(:faulty => TRUE)
    end

    def votes_complete
      where('comments.vote_count = (SELECT count(*) FROM votes WHERE votes.votable_id = comments.id and votes.votable_type="Comment")')
    end

    def votes_incomplete
      where('comments.vote_count != (SELECT count(*) FROM votes WHERE votes.votable_id = comments.id and votes.votable_type="Comment")')
    end

  end
  extend Scopes

end
