class Updater

  class << self

    def all

      status = Hash.new
      status['published'] = [1,110]
      status['queued'] = [1,220]
      status['discarded'] = [1,100]

      status.each do |news_type, indexes|
        init_index = indexes[0]
        end_index =  indexes[1]
        index_counter = end_index - WaggExample::PAGE_BATCH_SIZE

        while index_counter + WaggExample::PAGE_BATCH_SIZE >= init_index
          pages_list = Wagg.page(news_type, :begin_interval => index_counter + 1, :end_interval => index_counter + WaggExample::PAGE_BATCH_SIZE)

          # Parse and process each news in news_list to be stored in database
          pages_list.each do |index, page|
            Rails.logger.info 'Processing page with index #%{index}' % {index:index}
            page.news_list.each do |n_url, n|
              news = News.find_by(:url_internal => n_url)
              if news.nil?
                Rails.logger.info 'Parsing new URL -> %{index}::%{url}' % {index: index, url: n_url}
                # TODO Look for object id in delayed_jobs table... if there, don't insert...
                Delayed::Job.enqueue(NewsProcessor::NewsJob.new(n_url))
              elsif news.votes_negative.count != n.votes_count['negative']
                # If news is open, we only care for negative votes as those we need to infer data within 24 hours
                Rails.logger.info 'Parsing update URL -> %{index}::%{url}' % {index: index, url: n_url}
                # TODO Look for object id in delayed_jobs table... if there, don't insert...
                Delayed::Job.enqueue(NewsProcessor::NewsJob.new(n_url))
              end
            end
          end

          # Decrement index counter
          index_counter -= WaggExample::PAGE_BATCH_SIZE
        end
      end
    end

  end

end