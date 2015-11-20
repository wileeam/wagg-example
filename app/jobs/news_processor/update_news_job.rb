module NewsProcessor
  class UpdateNewsJob < Struct.new(:news_id)

    def queue_name
      WaggExample::JOB_QUEUE['news']
    end

    def enqueue(job)
      #job.delayed_reference_id   = news_id
      #job.delayed_reference_type = 'news'
      job.priority = WaggExample::JOB_PRIORITY['news']
      job.save!
    end

    def perform
      news = News.find_by(:id => news_id)

      if news.nil?
        # TODO: Recover and create a new entry with this id for news. Possible?
        error = "Couldn't find News record with id='%{id}'" %{id: news_id}
        raise ActiveRecord::RecordNotFound, error
      elsif news.closed?
        # TODO Maybe checking the 'updated_at' field can minimize unnecessary parsing
        # Retrieve the news from the site
        news_item = Wagg.news(news.url_internal)

        # Update everything that is possible to have changed
        news.title = news_item.title
        news.description = news_item.description
        news.category = news_item.category
        news.status = news_item.status
        if news.tags.count != news_item.tags.size || !(news.tags.pluck(:name) - news_item.tags).empty?
          news.tags.clear
          news_item.tags.each do |t|
            tag = Tag.find_or_create_by(:name => t)
            news.tags << tag
          end
        end

        news.url_external = news_item.urls['external']

        news.clicks = news_item.clicks
        news.karma = news_item.karma
        news.votes_count_anonymous = news_item.votes_count['anonymous']
        news.votes_count_negative = news_item.votes_count['negative']
        news.votes_count_positive = news_item.votes_count['positive']
        news.comments_count = news_item.comments_count

        news.save

        # Check the name of the author (if it changed, the check is just a query)
        # TODO What if the author doesnt exist (this is impossible unless there is inconsistent data (eg kmkm user))
        news_author = Author.find_by(:id => news_item.author['id'])
        news_author.name = news_item.author['name']
        news_author.save

        # Check comments and ONLY update if needed
        if news_item.comments_available? && !news_item.comments.empty?
          news_item.comments.each do |_, news_comment|
            comment = Comment.find_by(:id => news_comment.id)
            if comment.nil?
              Delayed::Job.enqueue(CommentsProcessor::NewCommentJob.new(news_comment))
            elsif !comment.complete?
              Delayed::Job.enqueue(CommentsProcessor::UpdateCommentJob.new(news_comment))
            end
          end
        end

        # Check news' votes and update (votes are added when news is closed)
        if news_item.votes_available?
          news_item.votes.each do |news_vote|
            vote_author = Author.find_or_update_by_name(news_vote.author)
            unless Vote.exists?([vote_author.id, news.id, 'News'])
              Delayed::Job.enqueue(VotesProcessor::NewVoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news, "News"))
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