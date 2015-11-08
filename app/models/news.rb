class News < ActiveRecord::Base

  belongs_to  :poster,        :foreign_key  => :poster_id#inverse_of: :authors

  has_many    :votes,         :as           => :votable#inverse_of: :news

  has_many    :news_tags
  has_many    :tags,          :through      => :news_tags

  has_many    :news_comments
  has_many    :comments,      :through      => :news_comments

  validates_uniqueness_of     :id

  def closed?
    self.timestamp_publication <= 30.days.ago
  end

  def open?
    !self.closed?
  end

  def complete?
    !self.karma.nil?
  end

  def incomplete?
    !self.complete?
  end

  module Scopes
    def open
      where(:timestamp_publication => 30.days.ago..Time.now)
    end

    def closed
      where.not(:timestamp_publication => 30.days.ago..Time.now)
    end

    def last(time)
      where(:timestamp_publication => time.days.ago..Time.now)
    end

    def incomplete
      where(:karma => nil)
    end

    def missing_comments
      where('comments_count != (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
    end
  end
  extend Scopes

end
