module NewsProcessor
  class NewNewsJob < Struct.new(:news_url)

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
      news_item = Wagg.news(news_url)

      # TODO If a news is found in this job... switch it to an udpate job
      #news = News.find_by(:id => news_item.id)

      # Retrieve or create news with provided data
      news = News.find_or_initialize_by(id: news_item.id) do |n|
        author = Author.find_or_update_by_name(news_item.author['name'])
        n.poster_id = author.id
        n.title = news_item.title
        n.description = news_item.description
        n.url_internal = news_item.urls['internal']
        n.url_external = news_item.urls['external']
        n.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
        n.timestamp_publication = Time.at(news_item.timestamps['publication']).to_datetime
        n.category = news_item.category
        news_item.tags.each do |t|
          tag = Tag.find_or_create_by(name: t)
          n.tags << tag
        end
      end

      # News' metadata if available
      # Wagg.News object has a more accurate knowledge on retrieval time
      unless news_item.open?
        news.clicks = news_item.clicks
        news.karma = news_item.karma
        news.votes_count_anonymous = news_item.votes_count['anonymous']
        news.votes_count_negative = news_item.votes_count['negative']
        news.votes_count_positive = news_item.votes_count['positive']
        news.comments_count = news_item.comments_count
      end

      news.save

      # Comments retrieval ONLY if available
      # TODO Switch to update comment job if comment is found
      if news_item.comments_available? && !news_item.comments.empty?
        news_item.comments.each do |_, news_comment|
          Delayed::Job.enqueue(CommentsProcessor::NewCommentJob.new(news_comment))
        end
      end

      # News's votes retrieval if available
      if news_item.votes_available?
        news_item.votes.each do |news_vote|
          vote_author = Author.find_or_update_by_name(news_vote.author)
          unless Vote.exists?([vote_author.id, news.id, 'News'])
            Delayed::Job.enqueue(VotesProcessor::NewVoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news, "News"))
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