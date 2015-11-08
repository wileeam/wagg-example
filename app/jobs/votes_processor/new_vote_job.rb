module VotesProcessor
  #TODO: Rework parameters into one single parameter
  class NewVoteJob < Struct.new(:vote_author, :vote_timestamp, :vote_weight, :vote_votable, :vote_votable_type)

    def queue_name
      WaggExample::JOB_QUEUE['votes']
    end

    def enqueue(job)
      #job.delayed_reference_id   = vote_votable
      #job.delayed_reference_type = 'vote'
      job.priority = WaggExample::JOB_PRIORITY['votes']
      job.save!
    end

    def perform
      # TODO: Document the following (basically we try the database before hitting the site again)
      #       We get an extra query at the expense of not hitting the site if votes exists already
      author = Author.find_or_update_by_name(vote_author)

      unless Vote.exists?([author.id, vote_votable.id, vote_votable_type])
        author = Author.find_or_update_by_name(vote_author)
        vote = Vote.new(
            voter_id: author.id,
            timestamp: Time.at(vote_timestamp).to_datetime,
            weight: vote_weight
        )
        vote.votable = vote_votable
        unless Vote.exists?([author.id, vote_votable.id, vote_votable_type])
          vote.save
          vote_votable.votes << vote
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