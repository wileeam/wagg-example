module CommentsProcessor
  class CommentJob < Struct.new(:comment_item)

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
      comment = Comment.find_by(:id => comment_item.id)

      # Note that Wagg.Comment object has a more accurate knowledge on retrieval time

      if comment.nil? # New comment
        # Create comment object (after checking that id doesn't really exist in database)
        comment = Comment.find_or_initialize_by(:id => comment_item.id) do |c|
          begin
            author = Author.find_or_update_by_name(comment_item.author)
          rescue ActiveRecord::RecordNotFound => e
            # Author has changed its name some time between comment's retrieval and comment's parsing
            # Solution: Retrieve comment again for new author's name
            # If this fails here then we need to do a manual check
            author = Author.find_or_update_by_name(Wagg.comment(comment_item.id).author)
          end
          c.commenter_id = author.id
          c.body = comment_item.body
          c.timestamp_creation = Time.at(comment_item.timestamps['creation']).to_datetime
          unless comment_item.timestamps['edition'].nil?
            c.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
          end
        end
      else # Update comment (comment variable will contain some data from database)
        # Update comment object
        comment.body = comment_item.body
        unless comment_item.timestamps['edition'].nil?
          comment.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
        end
      end

      unless comment_item.voting_open?
        comment.vote_count = comment_item.votes_count
        comment.karma = comment_item.karma
      end

      comment.save

      # Link comment with the news if it wasn't already
      comment_news = News.find_by(:url_internal => comment_item.news_url)
      comment_news_index = comment_item.news_index
      unless comment.news_comments.exists?(:news => comment_news, :news_index => comment_news_index)
        comment.news_comments.create(:news => comment_news, :news_index => comment_news_index)
      end

      # Check comment' votes and update
      # Due to performance reasons:
      #  - Votes are retrieved after voting period of comment is over (and votes are still available)
      #  - Negative weights in comments' votes is preserved, reason to avoid repeating the parsing all the time
      if comment_item.voting_closed? && comment_item.votes_available? &&
          ((!comment_item.votes_count.nil? && comment_item.votes_count != comment.votes.count) || (comment_item.votes_count.nil? && comment_item.votes.size != comment.votes.count))
        comment_item.votes.each do |comment_vote|
          vote_author = Author.find_or_update_by_name(comment_vote.author)
          # We overwrite the rate and weight of the vote if they changed due to a previous bug... sorry...
          begin
            vote = Vote.find([vote_author.id, comment.id, 'Comment'])
          rescue ActiveRecord::RecordNotFound => e
            Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, comment_vote.timestamp, comment_vote.weight, comment_vote.rate, comment.id, "Comment"))
          else
            vote.rate = comment_vote.rate
            vote.weight = comment_vote.weight
            vote.save
          end
        end

        if (comment_item.votes_count.nil? || comment_item.karma.nil?) && comment_item.votes.size > 0
          comment.vote_count = Comment.find(comment_item.id).votes.count
          comment.karma = Comment.find(comment_item.id).votes.sum(:weight)
        end

      end

    end

    def before(job)
      #TODO
    end

    def after(job)
      #TODO
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