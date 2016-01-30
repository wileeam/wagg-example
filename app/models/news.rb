class News < ActiveRecord::Base

  belongs_to  :poster,        :foreign_key  => :poster_id, :class_name => Author

  has_many    :votes,         :as           => :votable

  has_many    :news_tags
  has_many    :tags,          :through      => :news_tags

  has_many    :news_comments
  has_many    :comments,      :through      => :news_comments

  validates_uniqueness_of     :id

  def vote_count
    self.votes_count_positive + self.votes_count_negative
  end

  def votes_count
    self.vote_count
  end

  def comment(index)
    self.comments.where(:news_comments => {:news_index => index})
  end

  def votes_positive
    self.votes.where('rate >= 0')
  end

  def votes_negative
    self.votes.where('rate < 0')
  end

  def closed?
    self.comments_closed? && self.votes_closed?
  end

  def open?
    !self.closed?
  end

  def complete?
    self.complete || (self.votes_complete? && self.comments_complete? && !self.karma.nil?)
  end

  def incomplete?
    !self.complete?
  end

  def faulty?
    self.faulty
  end

  def comments_complete?
    self.comments.count == self.comments_count && self.comments_count > 0
  end

  def comments_incomplete?
    !self.comments_complete?
  end

  def comments_votes_complete?
    sql = "SELECT `votes`.* FROM `votes`, `news_comments` WHERE `news_comments`.`news_id` = #{ActiveRecord::Base.sanitize(self.id)} AND `news_comments`.`comment_id` = `votes`.`votable_id`"
    self.comments.sum(:vote_count) == Vote.find_by_sql(sql).count
  end

  def comments_votes_incomplete?
    !self.comments_votes_complete?
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
    self.votes.count == (self.votes_count_negative + self.votes_count_positive)
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

  # TODO: test this method and add others like: first, last_closed, last_open
  # TODO: comments_closed? can be improved by checking the comments as well.
  # This gives us the last comment of each news (in the database)
  def last_comment
    self.comments.order(:timestamp_creation => :asc).last
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

    def closed(delta_time=0)
      query = "(status = 'published' AND timestamp_publication <= ?)" +
            " OR " +
            "((status = 'queued' OR status = 'discarded') AND timestamp_creation <= ?)"
      min_time = 30.days.ago + delta_time
      where(query, min_time, min_time)
    end

    def open(delta_time=0)
      query = "(status = 'published' AND timestamp_publication > ?)" +
          " OR " +
          "((status = 'queued' OR status = 'discarded') AND timestamp_creation > ?)"
      min_time = 30.days.ago + delta_time
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

    def unpublished
      where.not(:status => 'published')
    end

    def latest(time)
      where(:timestamp_creation => time.days.ago..Time.now)
    end

    def between(initial_time, final_time)
      where(:timestamp_creation => final_time..initial_time)
    end

    def complete
      where(:complete => TRUE)
    end

    def incomplete
      #where('complete IS NOT TRUE')
      where('complete = 0 OR complete IS NULL')
    end

    def faulty
      where(:faulty => TRUE)
    end

    def comments_complete
      where('news.comments_count = (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
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
      #where('(news.votes_count_negative + news.votes_count_positive) = (SELECT count(*) FROM votes WHERE votes.votable_id = news.id and votes.votable_type="News")')
      joins(:votes).group(:votable_id).having('news.votes_count_positive + news.votes_count_negative = count(*)')
    end

    def votes_incomplete
      #where('(news.votes_count_negative + news.votes_count_positive) != (SELECT count(*) FROM votes WHERE votes.votable_id = news.id and votes.votable_type="News")')
      news_list_positive_incomplete = self.votes_positive_incomplete
      news_list_negative_incomplete = self.votes_negative_incomplete

      # TODO sort result before return
      news_list_positive_incomplete.concat(news_list_negative_incomplete)
    end

    def votes_positive_complete
      joins(:votes).where('votes.rate >= 0').group(:votable_id).having('news.votes_count_positive = count(*)')
    end

    def votes_positive_incomplete
      joins(:votes).where('votes.rate >= 0').group(:votable_id).having('news.votes_count_positive != count(*)')
    end

    def votes_negative_complete
      joins(:votes).where('votes.rate < 0').group(:votable_id).having('news.votes_count_negative = count(*)')
    end

    def votes_negative_incomplete
      joins(:votes).where('votes.rate < 0').group(:votable_id).having('news.votes_count_negative != count(*)')
    end

  end
  extend Scopes

end
