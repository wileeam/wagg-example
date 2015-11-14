module VotesProcessor
  class CommentVotesJob < Struct.new(:comment)

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
      comment_votes_items = Wagg.votes_for_comment(comment.id)
      if comment_votes_items.size == (comment.vote_count)
        comment_votes_items.each do |comment_vote_item|
          vote_author = comment_vote_item.author
          vote_timestamp = comment_vote_item.timestamp
          vote_weight = comment_vote_item.weight
          Delayed::Job.enqueue(VotesProcessor::NewVoteJob.new(vote_author, vote_timestamp, vote_weight, comment, "Comment"))
        end
      else
        Rails.logger.error 'Inconsistent votes for comment -> %{id}' % {id:comment.id}
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