module VotesProcessor
  class NewsVotesJob < Struct.new(:news)

    def queue_name
      WaggExample::JOB_QUEUE['voting_lists']
    end

    def enqueue(job)
      #job.delayed_reference_id   = news_id
      #job.delayed_reference_type = 'news'
      job.priority = WaggExample::JOB_PRIORITY['voting_lists']
      job.save!
    end

    def perform
      news_votes_items = Wagg.votes_for_news(news.id)
      if news_votes_items.size == (news.votes_count_positive + news.votes_count_negative)
        news_votes_items.each do |news_vote_item|
          vote_author = news_vote_item.author
          vote_timestamp = news_vote_item.timestamp
          vote_weight = news_vote_item.weight
          vote_rate = news_vote_item.rate
          Delayed::Job.enqueue(VotesProcessor::NewVoteJob.new(vote_author, vote_timestamp, vote_weight, vote_rate, news, "News"))
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
end