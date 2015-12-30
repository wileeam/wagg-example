module Maintainer
  class Updater

    class << self

      def all

        status = ['published', 'queued', 'discarded']
        ref_timestamp = Time.now.yesterday.beginning_of_day.to_i

        status.each do |news_type|
          index_counter = 1
          page = Wagg.page(news_type, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]

          while page.max_timestamp >= ref_timestamp || page.max_timestamp >= ref_timestamp
            # Parse and process each news in news_list to be stored in database
            Rails.logger.info 'Processing page (%{type}) #%{index}' % {type:news_type.upcase, index:page.index}
            page.news_list.each do |news_url, news|
              Rails.logger.info 'Parsing URL -> #%{index}::%{url}' % {index: page.index, url: news_url}
              Delayed::Job.enqueue(NewsProcessor::NewsJob.new(news_url))
            end

            index_counter += 1
            page = Wagg.page(news_type, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
          end

        end
      end
    end

  end

  class Fixer
    class << self
      def fix_news
        news_list = News.incomplete.where('timestamp_creation < ?', 60.days.ago)
        news_list.each do |n|
          news_item = Wagg.news(n.url_internal)

          unless news_item.commenting_open?
            n.comments_count = news_item.comments_count
          end

          if news_item.comments_available? && (news_item.comments_count != n.comments.count || n.comments_incomplete?)
            news_item.comments.each do |_, news_comment|
              if !Comment.exists?(news_comment.id) || Comment.find(news_comment.id).incomplete?
                CommentsProcessor::CommentJob.new(news_comment).perform
              end
            end
          end



          if n.comments_incomplete? || n.votes_incomplete?
            n.faulty = TRUE
          end

          n.complete = TRUE
          n.save

        end
        # list of news incomplete of comments older than 60.days.ago (exclude already ticked complete)
        # parse each news for comments
        # mark each parsed news complete
        # mark faulty those that after going over the list are still incomplete as per the first query
      end
    end
  end

end