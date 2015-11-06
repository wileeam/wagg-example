class UpdateController < ApplicationController

  # GET /update
  # GET /update.json
  def index

  end

  def news
    # Update news that were open while they were retrieved (if they are now closed of course)
    news_list = News.closed.incomplete.order(:timestamp_publication => ASC)
    news_list.each do |news|
      Rails.logger.info 'Completing meta-data for news -> %{url}' % {url:news.url_internal}
      Delayed::Job.enqueue(NewsProcessor::UpdateNewsJob.new(news.id))
    end

    # Update news with missing comments
    news_list = News.missing_comments.order(:timestamp_publication => ASC)
    news_list.each do |news|
      Rails.logger.info 'Completing comments for news -> %{url}' % {url:news.url_internal}
      Delayed::Job.enqueue(NewsProcessor::NewNewsJob.new(news.url_internal))
    end
  end

  def comment

  end

  def comments
    comments_list = Comment.incomplete.order(:timestamp_creation => ASC)
    comments_list.each do |comment|
      Rails.logger.info 'Completing meta-data for comment -> %{comment}' % {comment:comment.id}
      Delayed::Job.enqueue(CommentsProcessor::UpdateCommentJob.new(comment.id))
    end
  end

end
