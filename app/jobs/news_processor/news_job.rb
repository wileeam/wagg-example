module NewsProcessor
  class NewsJob < Struct.new(:news_url)

    def queue_name
      WaggExample::JOB_QUEUE['news']
    end

    def enqueue(job)
      job.priority = WaggExample::JOB_PRIORITY['news']
      job.save!
    end

    def perform

      news = News.find_or_initialize_by(:url_internal => news_url)

      # If we have marked the news as complete and/or faulty in database, we don't need to even check beyond
      # TODO Could I use the 'complete?' method in combination or this one to include the 'complete' flag instead?
      if !news.nil? && (news.complete && !news.faulty)
        # TODO Check for completeness of comments?
        return
      end

      # Retrieve the news from the site
      # Note that Wagg.News object has a more accurate knowledge on retrieval time
      news_item = Wagg.news(news_url)
      # Retrive the author of the news from database or site
      news_author = Author.find_or_update_by_name(news_item.author['name'])

      news.id = news_item.id
      news.poster_id = news_author.id
      news.title = news_item.title
      news.description = news_item.description
      #news.url_internal = news_item.urls['internal']
      news.url_external = news_item.urls['external']
      news.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
      news.category = news_item.category
      news.status = news_item.status

      if news_item.tags.size > news.tags.count #|| !(news.tags.pluck(:name) - news_item.tags).empty?
        news.tags.clear
        news_item.tags.each do |t|
          tag = Tag.find_or_create_by(:name => t)
          news.tags << tag
        end
      end

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

      # Persist news object because it will be needed as foreign key
      news.save

      # Votes retrieval (any that is missing: not in database) if available (regardless of news open/closed)
      # Note that only when there are new votes these votes are parsed, otherwise not
      if news_item.votes_available?
        if (news_item.votes_count['positive'] > 0 && news_item.votes_count['positive'] > news.votes_positive.count) ||
            (news_item.votes_count['negative'] > 0 && news_item.votes_count['negative'] > news.votes_negative.count)
          Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(news_item.id, 'News'))
          #VotesProcessor::VotingListJob.new(news_item.id, 'News').perform
        end
      end

      # Comments retrieval (any that is missing: not in database) if available (regardless of news open/closed)
      if news_item.comments_available?
        if news_item.commenting_closed?
          news_item.comments.each do |_, news_comment|
            Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
            #CommentsProcessor::CommentJob.new(news_comment).perform
          end
        elsif news_item.comments_count > news.comments.count
          news_item.comments.each do |_, news_comment|
            unless Comment.exists?(news_comment.id)
              Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
              #CommentsProcessor::CommentJob.new(news_comment).perform
            end
          end
        end
      end

    end

  end
end