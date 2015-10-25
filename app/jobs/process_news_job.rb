class ProcessNewsJob < Struct.new(:news_id, :news_author, :news_title, :news_description, :news_urls, :news_timestamps,
                                  :news_category, :news_tags, :news_metadata, :news_votes, :news_comments)

  def queue_name
    'news'
  end

  def enqueue(job)
    #job.delayed_reference_id   = news_id
    #job.delayed_reference_type = 'news'
    job.priority = 10
    job.save!
  end

  def perform
    ### Retrieve or create comment with provided data
    news = News.find_or_initialize_by(id: news_id) do |n|
      author = Author.find_or_update_by_name(news_author)
      n.poster_id = author.id
      n.title = news_title
      n.description = news_description
      n.url_internal = news_urls['internal']
      n.url_external = news_urls['external']
      n.timestamp_creation = news_timestamps['creation']
      n.timestamp_publication = news_timestamps['publication']
      n.category = news_category
      news_tags.each do |t|
        tag = Tag.find_or_initialize_by(name: t)
        tag.save
        n.tags << tag
      end
    end

    ### Add metadata if available
    unless news_metadata.nil?
      news.clicks = news_metadata['clicks']
      news.karma = news_metadata['karma']
      news.votes_count_anonymous = news_metadata['votes_count']['anonymous']
      news.votes_count_negative = news_metadata['votes_count']['negative']
      news.votes_count_positive = news_metadata['votes_count']['positive']
      news.comments_count = news_metadata['comments_count']
    end

    ### News's votes retrieval if available
    unless news_votes.nil? || news_votes.empty?
      news_votes.each do |news_vote|
        Delayed::Job.enqueue(::ProcessVoteJob.new(news_vote['author'], news_vote['timestamp'], news_vote['weight'], news, "News"))
      end
    end

    #### Comment's retrieval if available
    unless news_comments.nil? || news_comments.empty?
      news_comments.each do |news_comment|
        Delayed::Job.enqueue(::ProcessCommentJob.new(news_comment['id'], news_comment['author'], news_comment['timestamps'],
                                                     news_comment['body'], news_comment['vote_count'], news_comment['karma'],
                                                     news, news_comment['index'], news_comment['votes']))
      end
    end
  end

  def before(job)
    #record_stat 'vote_job/start'
  end

  def after(job)
    #record_stat 'vote_job/after'
  end

  def success(job)
    #record_stat 'vote_job/success'
  end

  def error(job, exception)
    #record_stat 'vote_job/exception'
  end

  def failure(job)
    #record_stat 'vote_job/failure'
  end

end