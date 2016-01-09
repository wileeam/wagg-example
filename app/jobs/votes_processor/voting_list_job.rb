module VotesProcessor
  class VotingListJob < Struct.new(:item_id, :item_type)

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
      object = nil
      votes = nil

      case item_type
        when 'News'
          object = News.find(item_id)
          votes = Wagg.votes_for_news(item_id)
        when 'Comment'
          object = Comment.find(item_id)
          votes = Wagg.votes_for_comment(item_id)
        else
          # Not good...
      end

      if votes.size > (object.votes.count)
        votes.each do |vote|
          vote_author = Author.find_or_update_by_name(vote.author)
          unless Vote.exists?([vote_author.id, item_id, item_type])
            Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, vote.timestamp, vote.weight, vote.rate, item_id, item_type))
          end
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
end