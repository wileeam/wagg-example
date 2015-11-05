module NewsProcessor
  class UpdateNewsJob < Struct.new(:news_id)

    def queue_name
      WaggExample::JOB_QUEUE['news']
    end

    def enqueue(job)
      #job.delayed_reference_id   = news_id
      #job.delayed_reference_type = 'news'
      job.priority = WaggExample::JOB_PRIORITY['news'] + 5
      job.save!
    end

    def perform
      news = News.find(news_id)

      if !news.nil? && news.closed?
        # Retrieve the news from the site
        news_item = Wagg.news(news.url_internal)

        # Update everything that is possible to have changed
        news.title = news_item.title
        news.description = news_item.description
        news.category = news_item.category
        news_item.tags.each do |t|
          tag = Tag.find_or_initialize_by(name: t)
          tag.save
          news.tags << tag
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
        # TODO

        # Check comments
        # TODO
        #### Comment retrieval if available
        #unless news_item.comments.nil? || news_item.comments.empty?
        #news_item.comments(TRUE).each do |_, news_comment|
        #  Delayed::Job.enqueue(::ProcessCommentJob.new(news_comment))
        #end
        #end

        # Check news' votes
        # TODO
        ### News's votes retrieval if available
        #unless !news_parameters['with_votes'] || news_item.votes.nil? || news_item.votes.empty?
        #  news_item.votes.each do |news_vote|
        #    Delayed::Job.enqueue(::ProcessVoteJob.new(news_vote['author'], news_vote['timestamp'], news_vote['weight'], news, "News"))
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