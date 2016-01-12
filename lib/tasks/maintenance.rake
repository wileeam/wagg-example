namespace :maintenance do

  desc "TODO"
  task :todo =>  :environment  do

  end

  namespace :comments do
    desc "Updates votes of closed comments (those created between 30 and 60 days ago)"
    task :update_votes => :environment  do

      timestamp_thresholds = Hash.new
      timestamp_thresholds['begin'] = 30.days.ago
      timestamp_thresholds['end'] = 60.days.ago

      news_comments_list = News.joins(:comments).where(:comments => {:timestamp_creation => timestamp_thresholds['end']..timestamp_thresholds['begin']}).distinct

      news_comments_list.each do |n|
        Delayed::Job.enqueue(VotesProcessor::NewsCommentsVotesJob.new(n.id, timestamp_thresholds))
      end

    end

    desc "TODO"
    task  :mark_complete_faulty =>  :environment  do

      news_list = News.closed.where(:complete => nil)

      news_list.each do |n|
        news_item = Wagg.news(n.url_internal)

        # Add all missing comments (and their votes)
        if news_item.commenting_closed? && news_item.comments_available?
          news.comments_count = news_item.comments_count

          # First add the missing comments if any
          if news_item.comments_count > news.comments.count
            # There are missing comments, so we need to retrieve those we don't have
            news_item.comments.each do |_, news_comment|
              unless Comment.exists?(news_comment.id)
                Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
              end
            end
          end
        end


      end

    end
  end

  namespace :news do
    desc  "Updates votes of open news prioritizing new negative votes and queued news"
    task  :update_votes =>  :environment  do

      status = Hash.new
      status['queued']    = News.queued.open.first.timestamp_creation.to_i
      status['published'] = News.published.open.first.timestamp_publication.to_i
      status['discarded'] = News.discarded.open.first.timestamp_creation.to_i

      status.each do |news_type, ref_timestamp|
        voting_lists = Array.new
        index_counter = 1

        page = Wagg.page(news_type, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
        while page.max_timestamp >= ref_timestamp || page.max_timestamp >= ref_timestamp
          # Parse and process each news in news_list to be stored in database
          Rails.logger.info 'Processing page (%{type}) #%{index}' % {type:news_type.upcase, index:page.index}
          page.news_list.each do |news_url, news_item|
            if !News.exists?(news_item.id)
              Rails.logger.info 'Parsing URL -> #%{index}::%{url}' % {index: page.index, url: news_url}
              Delayed::Job.enqueue(NewsProcessor::NewsJob.new(news_url))
            else
              n = News.find(news_item.id)
              Rails.logger.info('Checking votes (%{nid})...' % {nid:n.id})
              if news_item.votes_available?
                Rails.logger.info '  ...missing %{pos} pos :: %{neg} neg' % {pos:(news_item.votes_count['positive'] - n.votes_positive.count).abs, neg:(news_item.votes_count['negative'] - n.votes_negative.count).abs}
                if news_item.votes_count['negative'] != n.votes_negative.count
                  Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(news_item.id, 'News'))
                elsif news_item.votes_count['positive'] != n.votes_positive.count
                  voting_lists.push(news_item.id)
                end
              end
            end
          end

          index_counter += 1
          page = Wagg.page(news_type, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
        end

        # Enqueue now voting lists with only missing positive votes (negative ones are enqueued as found)
        voting_lists.each do |vl|
          Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(vl, 'News'))
        end
      end
    end

    desc "TODO"
    task  :mark_complete_faulty =>  :environment  do

    end
  end

end