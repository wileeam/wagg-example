class ProcessVoteJob < Struct.new(:vote_author, :vote_timestamp, :vote_weight, :vote_votable, :vote_votable_type)

  def queue_name
    'votes'
  end

  def enqueue(job)
    #job.delayed_reference_id   = vote_votable
    #job.delayed_reference_type = 'vote'
    job.priority = 1
    job.save!
  end

  def perform
    author = Author.find_or_update_by_name(vote_author)
    unless Vote.exists?([author.id, vote_votable.id, vote_votable_type])
      vote = Vote.new(
          voter_id: author.id,
          timestamp: vote_timestamp,
          weight: vote_weight
      )
      vote.votable = vote_votable
      vote.save
      vote_votable.votes << vote
      #vote_votable.save
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