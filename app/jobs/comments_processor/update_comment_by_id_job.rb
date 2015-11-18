module CommentsProcessor
  class UpdateCommentByIdJob < Struct.new(:comment_id)

    def queue_name
      WaggExample::JOB_QUEUE['comments']
    end

    def enqueue(job)
      #job.delayed_reference_id   = comment_id
      #job.delayed_reference_type = 'comment'
      job.priority = WaggExample::JOB_PRIORITY['comments']
      job.save!
    end

    def perform
      comment_item = Wagg.comment(comment_id)
      CommentsProcessor::UpdateCommentJob.new(comment_item).perform
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