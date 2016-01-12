module VotesProcessor
  class VoteJob < Struct.new(:vote_author, :vote_timestamp, :vote_weight, :vote_rate, :vote_votable_id, :vote_votable_type)

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

      unless Vote.exists?([author.id, vote_votable_id, vote_votable_type])
        author = Author.find_or_update_by_name(vote_author)
        vote = Vote.new(
            voter_id: author.id,
            timestamp: Time.at(vote_timestamp).to_datetime,
            rate: vote_rate
        )
        #TODO: If vote_type=NEWS and retrieval_timestamp not within 24 hours and weight < 0 then weight is not valid
        # abs(vote_timestamp - now) > 20.hours => weight not valid
        # abs(vote_timestamp - now) <= 20.hours => weight may be valid
        #  03:00 < vote_timestamp < 00:00 and 03 < now < 00:00 => weight is valid
        #  00:00 < vote_timestamp < 03:00 and 00 < now < 03:00 => weight is valid
        #  mismatch of any of the two above => weight not valid
        #if vote_weight < 0 && vote_votable_type == 'News' &&
        #  vote.weight = nil
        #else
          vote.weight = vote_weight
        #end
        vote.votable_id = vote_votable_id
        vote.votable_type = vote_votable_type

        vote.save unless Vote.exists?([author.id, vote_votable_id, vote_votable_type])
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