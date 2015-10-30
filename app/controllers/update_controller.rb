class UpdateController < ApplicationController

  # GET /update
  # GET /update.json
  def index

  end

  def news
    # Update news that were open while they were retrieved (if they are now closed of course)
    news_list = News.where(:karma => nil)
    news_list.each do |news|
      Rails.logger.info 'Completing meta-data for news -> %{url}' % {url:news.url_internal}
      Delayed::Job.enqueue(::ProcessNewsJob.new(news.url_internal))
    end

    # Update news with missing comments
    news_list = News.where('comments_count != (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
    news_list.each do |news|
      Rails.logger.info 'Completing comments for news -> %{url}' % {url:news.url_internal}
      Delayed::Job.enqueue(::ProcessNewsJob.new(news.url_internal))
    end
  end

  def comment

  end

  def comments
    comments_list = Comment.where(:karma => nil)
    comments_list.each do |comment|
      Rails.logger.info 'Completing meta-data for comment -> %{comment}' % {comment:comment.id}
      Delayed::Job.enqueue(::ProcessCommentByIdJob.new(comment.id))
    end
  end

end
