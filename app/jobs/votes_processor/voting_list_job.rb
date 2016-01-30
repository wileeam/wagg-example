module VotesProcessor
  class VotingListJob < Struct.new(:item_id, :item_type)

    def queue_name
      WaggExample::JOB_QUEUE['voting_lists']
    end

    def enqueue(job)
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
          # TODO Log? Exception?
      end

      if votes.size > object.votes.count
        votes.each do |vote|
          vote_author = Author.find_or_update_by_name(vote.author)
          if Vote.exists?([vote_author.id, item_id, item_type])
            # Special case for comments until all comments have been checked for erroneous non-negative weights
            if item_type == 'Comment'
              vote_object = Vote.find([vote_author.id, item_id, item_type])
              vote_object.rate = vote.rate
              if vote.rate < 0 && vote_object.weight != vote.weight && vote_object.weight.nil?
                vote_object.weight = vote.weight
              end
              vote_object.save
            end
          else
            Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, vote.timestamp, vote.weight, vote.rate, item_id, item_type))
            #Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.id, vote.timestamp, vote.weight, vote.rate, item_id, item_type))
          end
        end
      elsif votes.size < object.votes.count
        case item_type
          when 'News'
            object_item = Wagg.news(object.url_internal)
            votes_count = object_item.votes_count['positive'] + object_item.votes_count['negative']
          when 'Comment'
            object_item = Wagg.comment(object.id)
            votes_count = object_item.votes_count
          else
            # Not good...
            # TODO Log? Exception?
        end

        if votes_count < object.votes.count
          votes_list = Array.new
          votes.each do |vote|
            vote_author = Author.find_or_update_by_name(vote.author)
            if Vote.exists?([vote_author.id, item_id, item_type])
              votes_list.push(Vote.find([vote_author.id, item_id, item_type]))
            else
              Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, vote.timestamp, vote.weight, vote.rate, item_id, item_type))
              #Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.id, vote.timestamp, vote.weight, vote.rate, item_id, item_type))
            end
          end

          votes_deletable_list = object.votes - votes_list
          votes_deletable_list.each do |vote_deletable|
            vote_deletable.destroy
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