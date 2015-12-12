class Updater

  class << self

    def all

      # Configuration parameters
      Wagg.configure do |c|
        c.retrieval_delay['news'] = 4
        c.retrieval_delay['comment'] = 3
        #c.retrieval_delay['author'] = 2
      end

      init_index = 1
      end_index = 50
      status = ['published', 'discarded', 'queued']

      status.each do |news_type|
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
                Delayed::Job.enqueue(NewsProcessor::NewNewsJob.new(n_url))
              else
                if n.commenting_closed? || n.voting_closed?
                  Rails.logger.info 'Parsing update URL -> %{index}::%{url}' % {index: index, url: n_url}
                  Delayed::Job.enqueue(NewsProcessor::UpdateNewsJob.new(news.id))
                else
                  if news.votes.count != n.votes_count['positive'] + n.votes_count['negative']
                    Rails.logger.info 'Parsing update URL -> %{index}::%{url}' % {index: index, url: n_url}
                    Delayed::Job.enqueue(NewsProcessor::UpdateNewsJob.new(news.id))
                  end
                end
              end
            end
          end

          index_counter -= WaggExample::PAGE_BATCH_SIZE
        end
      end

    end

  end


end