module AuthorsProcessor
  class UpdateAuthorNameJob < Struct.new(:author_old_name, :author_new_name, :author_id)

    def queue_name
      JOB_QUEUE['authors']
    end

    def enqueue(job)
      #job.delayed_reference_id   = news_id
      #job.delayed_reference_type = 'news'
      # High priority job (the name change is dynamic on Menéame but here we have outdated information)
      job.priority = JOB_PRIORITY['authors']
      job.save!
    end

    def perform
      # TODO: This job will change the old name of the author for the new one
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