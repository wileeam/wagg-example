class ProcessCommentJob < Struct.new(:comment_id, :comment_author, :comment_timestamps, :comment_body, :comment_vote_count,
                                     :comment_karma, :comment_news, :comment_news_index, :comment_votes)

  def queue_name
    'comments'
  end

  def enqueue(job)
    #job.delayed_reference_id   = comment_id
    #job.delayed_reference_type = 'comment'
    job.priority = 9
    job.save!
  end

  def perform
    ### Retrieve or create comment with provided data
    comment = Comment.find_or_initialize_by(id: comment_id) do |c|
      author = Author.find_or_update_by_name(comment_author)
      c.commenter_id = author.id
      c.timestamp_creation = comment_timestamps['creation']
      c.body = comment_body
      c.vote_count = comment_vote_count
      c.karma = comment_karma
      unless comment_timestamps['edition'].nil?
        c.timestamp_edition = comment_timestamps['edition']
      end
      c.save
    end

    ### Link comment with the news if it wasn't already
    unless comment.news_comments.exists?(:news => comment_news, :news_index => comment_news_index)
      comment.news_comments.create(:news => comment_news, :news_index => comment_news_index)
    end

    ### Comment's votes retrieval if available
    unless comment_votes.nil? || comment_votes.empty?
      comment_votes.each do |comment_vote|
        Delayed::Job.enqueue(::ProcessVoteJob.new(comment_vote['author'], comment_vote['timestamp'], comment_vote['weight'], comment, "Comment"))
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