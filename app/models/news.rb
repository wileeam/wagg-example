class News < ActiveRecord::Base
  has_many    :votes,         :as           => :votable#inverse_of: :news

  belongs_to  :poster,        :foreign_key  => :poster_id#inverse_of: :authors

  has_many    :news_tags
  has_many    :tags,          :through      => :news_tags

  has_many    :news_comments
  has_many    :comments,      :through      => :news_comments

  validates_uniqueness_of     :id

  def closed?
    30.days.ago >= self.timestamp_publication
  end

  def open?
    !self.closed?
  end

end
