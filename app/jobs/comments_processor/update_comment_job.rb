module CommentsProcessor
  class UpdateCommentJob < Struct.new(:comment_id)

    def queue_name
      WaggExample::JOB_QUEUE['comments']
    end

    def enqueue(job)
      #job.delayed_reference_id   = comment_id
      #job.delayed_reference_type = 'comment'
      job.priority = WaggExample::JOB_PRIORITY['comments'] + 5
      job.save!
    end

    def perform
      news = Comment.find(comment_id)

      if !comment.nil? && comment.closed?
        comment_item = Wagg.comment(comment_id)

        # Update everything that is possible to have changed
        comment.body = comment_item.body
        comment.timestamp_creation = Time.at(comment_item.timestamps['creation']).to_datetime
        unless comment_item.timestamps['edition'].nil?
          comment.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
        end

        comment.vote_count = comment_item.votes_count
        comment.karma = comment_item.karma

        comment.save

        # Check the name of the author (if it changed, the check is just a query)
        # TODO

        ### Link comment with the news if it wasn't already
        comment_news = News.find_by(:url_internal => comment_item.news_url)
        comment_news_index = comment_item.news_index
        unless comment.news_comments.exists?(:news => comment_news, :news_index => comment_news_index)
          comment.news_comments.create(:news => comment_news, :news_index => comment_news_index)
        end

        # Check comment's votes
        # TODO
        ### Comment's votes retrieval if available
        #unless comment_votes.nil? || comment_votes.empty?
        #  comment_votes.each do |comment_vote|
        #    Delayed::Job.enqueue(::ProcessVoteJob.new(comment_vote['author'], comment_vote['timestamp'], comment_vote['weight'], comment, "Comment"))
        #  end
        #end

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