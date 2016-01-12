module VotesProcessor
  class NewsCommentsVotesJob < Struct.new(:news_id, :timestamp_thresholds)

    def queue_name
      WaggExample::JOB_QUEUE['voting_lists']
    end

    def enqueue(job)
      job.priority = WaggExample::JOB_PRIORITY['voting_lists']
      job.save!
    end

    def perform

      if News.exists?(news_id)
        news = News.find(news_id)
        news_item = Wagg.news(news.url_internal)
        news.comments.where(:timestamp_creation => timestamp_thresholds['end']..timestamp_thresholds['begin']).each do |c|
          comment_news_index = c.news_index
          if news_item.comments.has_key?(comment_news_index) && news_item.comment(comment_news_index).id == c.id
            news_comment_item = news_item.comment(comment_news_index)
            if (news_comment_item.votes_count.nil? && !Author.find_by(:name => news_comment_item.author).disabled? && news_comment_item.votes.size != c.votes.count) ||
                (!news_comment_item.votes_count.nil? && news_comment_item.votes_count != c.votes.count)
              Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(news_comment_item.id, 'Comment'))
            end
          end
        end
      else
        #TODO: Convert into a new news job?
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