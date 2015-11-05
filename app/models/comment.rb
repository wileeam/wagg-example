class Comment < ActiveRecord::Base
  belongs_to  :commenter, foreign_key: :commenter_id#, inverse_of: :authors

  has_many  :votes,         :as      => :votable

  has_many  :news_comments
  has_many  :news,        :through => :news_comments

  validates_uniqueness_of     :id

  def closed?
    30.days.ago >= self.timestamp_creation
  end

  def open?
    !self.closed?
  end

  def votes_available?
    self.vote_count == 0 || self.votes.count > 0
  end

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
      where(:karma => nil)
    end
  end
  extend Scopes


end
