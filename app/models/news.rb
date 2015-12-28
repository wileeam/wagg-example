class News < ActiveRecord::Base

  belongs_to  :poster,        :foreign_key  => :poster_id, :class_name => Author

  has_many    :votes,         :as           => :votable

  has_many    :news_tags
  has_many    :tags,          :through      => :news_tags

  has_many    :news_comments
  has_many    :comments,      :through      => :news_comments

  validates_uniqueness_of     :id

  def votes_positive
    self.votes.where('? >= 0', :rate)
  end

  def votes_negative
    self.votes.where('? < 0', :rate)
  end

  def closed?
    self.comments_closed? && self.votes_closed?
  end

  def open?
    !self.closed?
  end

  def complete?
    self.votes_complete? && self.comments_complete? && !self.karma.nil?
  end

  def incomplete?
    !self.complete?
  end

  def comments_complete?
    res = FALSE

    if self.comments_closed? && self.comments.count == self.comments_count && self.comments_count > 0
      sql = "SELECT `votes`.* FROM `votes`, `news_comments` WHERE `news_comments`.`news_id` = #{ActiveRecord::Base.sanitize(self.id)} AND `news_comments`.`comment_id` = `votes`.`votable_id`"
      res = self.comments.sum(:vote_count) == Vote.find_by_sql(sql).count
    end

    res
  end

  def comments_incomplete?
    !self.comments_complete?
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

  def votes_complete?
    self.votes_closed? && self.votes.count == (self.votes_count_negative + self.votes_count_positive)
  end

  def votes_incomplete?
    !self.votes_complete?
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
    def comments_closed
      query = "(status = 'published' AND timestamp_publication <= ?)" +
              " OR " +
              "(status = 'queued' AND timestamp_creation <= ?)" +
              " OR " +
              "(status = 'discarded' AND timestamp_creation <= ?)"
      where(query, 30.days.ago, 10.days.ago, 2.days.ago)
    end

    def votes_closed
      query = "(status = 'published' AND timestamp_publication <= ?)" +
          " OR " +
          "((status = 'queued' OR status = 'discarded') AND timestamp_creation <= ?)"
      min_time = 30.days.ago
      where(query, min_time, min_time)
    end

    def closed
      query = "(status = 'published' AND timestamp_publication <= ?)" +
            " OR " +
            "((status = 'queued' OR status = 'discarded') AND timestamp_creation <= ?)"
      min_time = 30.days.ago
      where(query, min_time, min_time)
    end

    def open
      query = "(status = 'published' AND timestamp_publication > ?)" +
          " OR " +
          "((status = 'queued' OR status = 'discarded') AND timestamp_creation > ?)"
      min_time = 30.days.ago
      where(query, min_time, min_time)
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

    def latest(time)
      where(:timestamp_creation => time.days.ago..Time.now)
    end

    def complete
      where(:complete => TRUE)
    end

    def incomplete
      where(:complete => FALSE)
    end

    def comments_complete
      where('news.comments_count == (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
    end

    def comments_incomplete
      where('news.comments_count != (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
    end

    def comments_votes_complete
      joins(:news_comments, :comments).merge(Comment.votes_complete).distinct
    end

    def comments_votes_incomplete
      joins(:news_comments, :comments).merge(Comment.votes_incomplete).distinct
    end

    def votes_complete
      where('(news.votes_count_negative + news.votes_count_positive) == (SELECT count(*) FROM votes WHERE votes.votable_id = news.id and votes.votable_type="News")')
    end

    def votes_incomplete
      where('(news.votes_count_negative + news.votes_count_positive) != (SELECT count(*) FROM votes WHERE votes.votable_id = news.id and votes.votable_type="News")')
    end

  end
  extend Scopes

end
