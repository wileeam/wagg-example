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

end
