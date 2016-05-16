module CommentsProcessor
  class CommentJob < Struct.new(:comment_item)

    def queue_name
      WaggExample::JOB_QUEUE['comments']
    end

    def enqueue(job)
      job.priority = WaggExample::JOB_PRIORITY['comments']
      job.save!
    end

    def perform

      comment = Comment.find_or_initialize_by(:id => comment_item.id)

      # If we have marked the comment as complete and/or faulty in database, we don't need to even check beyond
      # TODO Could I use the 'complete?' method in combination or this one to include the 'complete' flag instead?
      if !comment.nil? && (comment.complete && !comment.faulty.nil? && !comment.faulty?)
        return
      end

      # Retrieve the author of the comment from database or site
      begin
        comment_author = Author.find_or_update_by_name(comment_item.author)
      rescue ActiveRecord::RecordNotFound => e
        # Author has changed its name some time between comment's retrieval and comment's parsing
        # Solution: Retrieve comment again for new author's name
        # If this fails here then we need to do a manual check
        # TODO I wonder that given that I have all data in the item by the enqueing time...
        #      why don't I just create the Comment object directly?
        comment_author = Author.find_or_update_by_name(Wagg.comment(comment_item.id).author)
      end

      #comment.id = comment_item.id
      comment.commenter_id = comment_author.id
      comment.body = comment_item.body
      comment.timestamp_creation = Time.at(comment_item.timestamps['creation']).to_datetime
      unless comment_item.timestamps['edition'].nil?
        comment.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
      end

      unless comment_item.voting_open?
        comment.vote_count = comment_item.votes_count
        comment.karma = comment_item.karma
      end

      # Persist comment object because it will be needed as foreign key
      comment.save

      # Link comment with the news if it wasn't already
      # TODO: Cleanup URLs of the website's main address...
      comment_news = News.find_by(:url_internal => comment_item.news_url)
      comment_news_index = comment_item.news_index
      unless comment.news_comments.exists?(:news => comment_news, :news_index => comment_news_index)
        comment.news_comments.create(:news => comment_news, :news_index => comment_news_index)
      end

      # Check comment' votes and update
      # Due to performance reasons:
      #  - Votes are retrieved after voting period of comment is over (and votes are still available)
      #  - Negative weights in comments' votes is preserved, reason to avoid repeating the parsing all the time
      #if comment_item.voting_closed? && comment_item.votes_available?
      if comment_item.votes_available?
        if !comment_item.votes_count.nil? && comment_item.votes_count != comment.votes.count
          Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(comment_item.id, 'Comment'))
          #VotesProcessor::VotingListJob.new(comment_item.id, 'Comment').perform
        elsif comment_item.votes_count.nil? && !Author.find_by(:name => comment_item.author).disabled? && comment_item.votes.size != comment.votes.count
          #TODO This is redundant as I have already parsed the votes...
          Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(comment_item.id, 'Comment'))
          #VotesProcessor::VotingListJob.new(comment_item.id, 'Comment').perform
          comment.vote_count = comment_item.votes.size
          comment.karma = comment_item.votes.inject(0){ |sum, comment_vote| sum + comment_vote.weight }
          comment.save
        end
      end

      # Check consistency if possible (but mark complete only if successful)
      if comment_item.voting_closed?
          unless (comment_item.votes_count.nil? && !Author.find_by(:name => comment_item.author).disabled? && comment_item.votes_available? && comment_item.votes.size != comment.votes.count) ||
              (!comment_item.votes_count.nil? && comment_item.votes_count != comment.votes.count)
            comment.faulty = FALSE
            comment.complete = TRUE
            comment.save
          end
      end

    end

  end
end