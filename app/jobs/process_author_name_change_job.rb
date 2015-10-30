class ProcessAuthorNameChangeJob < Struct.new(:author_old_name, :author_new_name, :author_id)

def queue_name
  'voting_lists'
end

def enqueue(job)
  #job.delayed_reference_id   = news_id
  #job.delayed_reference_type = 'news'
  # High priority job (the name change is dynamic on Menéame but here we have outdated information)
  job.priority = 0
  job.save!
end

def perform
  # TODO: This job will change the old name of the author for the new one
  Comment.where("body LIKE %?%", author_old_name)

  news_votes_items = Wagg.votes_for_news(news.id)
  if news_votes_items.size == (news.votes_count_positive + news.votes_count_negative)
    news_votes_items.each do |news_vote_item|
      vote_author = news_vote_item.author
      vote_timestamp = Time.at(news_vote_item.timestamp).to_datetime
      vote_weight = news_vote_item.weight
      Delayed::Job.enqueue(::ProcessVoteJob.new(vote_author, vote_timestamp, vote_weight, news, "News"))
    end
  else
    Rails.logger.error 'Inconsistent votes for news -> %{url}' % {url:news.url_internal}
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