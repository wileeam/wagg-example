module CommentsProcessor
  class UpdateCommentJob < Struct.new(:comment_item)

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
      comment = Comment.find(comment_item.id)

      if comment.nil?
        # TODO: Recover and create a new entry with this id for comment. Possible?
        error = "Couldn't find Comment record with id='%{id}'" %{id: comment_item.id}
        raise ActiveRecord::RecordNotFound, error
      elsif comment.closed?
        # Update everything that is possible to have changed
        comment.body = comment_item.body
        unless comment_item.timestamps['edition'].nil?
          comment.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
        end

        comment.vote_count = comment_item.votes_count
        comment.karma = comment_item.karma

        comment.save

        # Check the name of the author (if it changed, the check is just a query)
        comment_author = Author.find_or_update_by_name(comment_item.author)
        comment_author.name = comment_item.author
        comment_author.save

        ### Link comment with the news if it wasn't already
        comment_news = News.find_by(:url_internal => comment_item.news_url)
        comment_news_index = comment_item.news_index
        unless comment.news_comments.exists?(:news => comment_news, :news_index => comment_news_index)
          comment.news_comments.create(:news => comment_news, :news_index => comment_news_index)
        end

        # Check comment' votes and update (votes are added when comment is closed)
        if comment_item.votes_available?
          comment_item.votes.each do |comment_vote|
            vote_author = Author.find_or_update_by_name(comment_vote.author)
            unless Vote.exists?([vote_author.id, comment.id, 'Comment'])
              Delayed::Job.enqueue(VotesProcessor::NewVoteJob.new(vote_author.name, comment_vote.timestamp, comment_vote.weight, comment, "Comment"))
            end
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