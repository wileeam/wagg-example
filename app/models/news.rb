class News < ActiveRecord::Base

  belongs_to  :poster,        :foreign_key  => :poster_id#inverse_of: :authors

  has_many    :votes,         :as           => :votable#inverse_of: :news

  has_many    :news_tags
  has_many    :tags,          :through      => :news_tags

  has_many    :news_comments
  has_many    :comments,      :through      => :news_comments

  validates_uniqueness_of     :id

  def closed?
    self.comments_closed? && self.votes_closed?
  end

  def open?
    !self.closed?
  end

  def complete?
    # TODO include data about comments to return true...
    !self.karma.nil?
  end

  def incomplete?
    !self.complete?
  end

  def comments_closed?
    case self.status
      when 'published'
        self.timestamp_publication <= 30.days.ago
      when 'queued'
        self.timestamp_creation <= 10.days.ago
      when 'discarded'
        self.timestamp_creation <= 2.days.ago
      else
        raise error
    end
  end

  def comments_open?
    !self.comments_closed?
  end

  def votes_closed?
    case self.status
      when 'published'
        self.timestamp_publication <= 30.days.ago
      when 'queued'
      when 'discarded'
        self.timestamp_creation <= 30.days.ago
      else
        raise error
    end
  end

  def votes_open?
    !self.votes_closed?
  end
  
  module Scopes
    def open
      where(:timestamp_publication => 30.days.ago..Time.now)
    end

    def closed
      where.not(:timestamp_publication => 30.days.ago..Time.now)
    end

    def published
      where(:status => 'published')
    end

    def queued
      where(:status => 'queued')
    end

    def discarded
      where(:status => 'discarded')
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
