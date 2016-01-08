module NewsProcessor
  class NewsJob < Struct.new(:news_url)

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
      news = News.find_by(:url_internal => news_url)

      # If we have marked the news as complete and/or faulty in database, we don't need to even check beyond
      # TODO Could I use the 'complete?' method in combination or this one to include the 'complete' flag instead?
      if !news.nil? && (news.complete) #|| news.faulty)
        return
      end

      # Note that Wagg.News object has a more accurate knowledge on retrieval time
      # TODO Maybe checking the 'updated_at' field can minimize unnecessary parsing
      # Retrieve the news from the site
      news_item = Wagg.news(news_url)

      if news.nil? # New news
        # Create news object (after checking that id doesn't really exist in database)
        news = News.find_or_initialize_by(:id => news_item.id) do |n|
          author = Author.find_or_update_by_name(news_item.author['name'])
          n.poster_id = author.id
          n.title = news_item.title
          n.description = news_item.description
          n.url_internal = news_item.urls['internal']
          n.url_external = news_item.urls['external']
          n.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
          n.category = news_item.category
          news_item.tags.each do |t|
            tag = Tag.find_or_create_by(:name => t)
            n.tags << tag
          end
        end
      else # Update news (news variable will contain some data from database)
        # TODO Check for comments and votes here (also each comment recursively)
        # Update everything that is possible to have changed
        news.title = news_item.title
        news.description = news_item.description
        news.category = news_item.category
        if news.tags.count != news_item.tags.size || !(news.tags.pluck(:name) - news_item.tags).empty?
          news.tags.clear
          news_item.tags.each do |t|
            tag = Tag.find_or_create_by(:name => t)
            news.tags << tag
          end
        end
        news.url_external = news_item.urls['external']
      end

      news.status = news_item.status
      if news_item.status == 'published'
        news.timestamp_publication = Time.at(news_item.timestamps['publication']).to_datetime
      else # news_item.status == 'queued' || news_item.status == 'discarded'
        news.timestamp_publication = nil # news_item.timestamps['publication'] == nil
      end

      # News voting metadata (and voting data) retrieval if available
      unless news_item.voting_open?
        news.clicks = news_item.clicks
        news.karma = news_item.karma
        news.votes_count_anonymous = news_item.votes_count['anonymous']
        news.votes_count_negative = news_item.votes_count['negative']
        news.votes_count_positive = news_item.votes_count['positive']
      end

      # News commenting metadata (and commenting data) retrieval if available
      unless news_item.commenting_open?
        news.comments_count = news_item.comments_count
      end

      # Persist news object as it will be needed as foreign key
      news.save

      # Votes retrieval if available
      if news_item.votes_available? && ((news_item.votes_count["positive"] != news.votes_positive.count) || (news_item.votes_count["negative"] != news.votes_negative.count))
        news_item.votes.each do |news_vote|
          vote_author = Author.find_or_update_by_name(news_vote.author)
          unless Vote.exists?([vote_author.id, news.id, 'News'])
            Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news_vote.rate, news.id, "News"))
          end
        end
      end

      # Comments retrieval if available
      if news_item.comments_available? && (news_item.comments_count != news.comments.count || news.comments_incomplete?)
        news_item.comments.each do |_, news_comment|
          if !Comment.exists?(news_comment.id) || Comment.find(news_comment.id).incomplete?
            Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
          end
        end
      end

    end

    def before(job)
      #record_stat 'vote_job/start'
    end

    def after(job)
      # TODO: Check news for completeness and mark the 'complete' field if everything ok, otherwise leave it blank?
      #if news is closed
        #check that comments are in database
        #check that news votes are in database
        #cheack that votes for comments are in database
        # any discrepancy triggers an update but we need a cut off for those news with issues (faulty field in db?)
      #else
      #  nothing to do
      #end
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