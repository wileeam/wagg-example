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
        #VotesProcessor::NewsCommentsVotesJob.new(n.id, timestamp_thresholds).perform
      end

    end

    desc "Check consistency of scrapped comments' votes tag them 'complete' and/or 'faulty'"
    task  :check_consistency  => :environment do

      news_list = News.closed.where(:complete => nil).union(News.closed.where(:complete => FALSE))
      news_comments_list = nil
      News.joins(:comments).where('comments.timestamp_creation <= ?', latest_time).order(:timestamp_creation => :desc).distinct


      news_list.each do |n|
        news_item = Wagg.news(n.url_internal)

        n.complete = FALSE

        if news_item.voting_closed? && news_item.commenting_closed?
          n.faulty = FALSE

          if ((news_item.votes_count["positive"] > 0 && news_item.votes_count["positive"] != n.votes_positive.count) ||
              (news_item.votes_count["negative"] > 0 && news_item.votes_count["negative"] != n.votes_negative.count)) &&
              n.votes.count != 0
            n.faulty = TRUE
          end

          if news_item.comments_count != n.comments.count
            n.faulty = TRUE
          end

          n.complete = TRUE
        end

        n.save
      end

      # Final checks for each comment of the news
      if news_item.commenting_closed? && news_item.comments_available?
        # TODO Use internal queries to avoid overparsing?
        news_item.comments.each do |_, news_comment|
          comment = Comment.find(news_comment.id)

          if news_comment.voting_closed?
            comment.faulty = FALSE

            if (news_comment.votes_count.nil? && !Author.find_by(:name => news_comment.author).disabled? && news_comment.votes.size != comment.votes.count) ||
                (!news_comment.votes_count.nil? && news_comment.votes_count != comment.votes.count)
              comment.faulty = TRUE
            end

            comment.complete = TRUE
          end
          comment.save
        end
      end

    end

  end

  namespace :news do
    desc  "Updates votes of news prioritizing new negative votes and queued news"
    task  :update_votes =>  :environment  do

      # We add this time to account for shifts of news' statuses in the site
      delta_time = 3.hours

      status_ref_timestamps = Hash.new
      status_ref_timestamps['queued']    = (News.queued.open.first.timestamp_creation - delta_time).to_i
      status_ref_timestamps['published'] = (News.published.open.first.timestamp_publication - delta_time).to_i
      status_ref_timestamps['discarded'] = (News.discarded.open.first.timestamp_creation - delta_time).to_i

      status_ref_timestamps.each do |status, ref_timestamp|
        voting_lists = Array.new
        index_counter = 1

        page = Wagg.page(status, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
        while page.max_timestamp >= ref_timestamp || page.max_timestamp >= ref_timestamp
          # Parse and process each news in news_list to be stored in database
          page.news_list.each do |news_url, news_item|
            if !News.exists?(news_item.id)
              Delayed::Job.enqueue(NewsProcessor::NewsJob.new(news_url))
            else
              n = News.find(news_item.id)
              if news_item.votes_available?
                if news_item.votes_count['negative'] != n.votes_negative.count
                  Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(news_item.id, 'News'))
                elsif news_item.votes_count['positive'] != n.votes_positive.count
                  voting_lists.push(news_item.id)
                end
              end
            end
          end

          index_counter += 1
          page = Wagg.page(status, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
        end

        # Enqueue now voting lists with only missing positive votes (negative ones are enqueued as found)
        voting_lists.each do |vl|
          Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(vl, 'News'))
        end
      end
    end

    desc "Scraps the site for recent submissions"
    task  :scrap_latest =>  :environment  do

      # We add this time to account for shifts of news' statuses in the site
      delta_time = 3.hours

      status_ref_timestamps = Hash.new
      status_ref_timestamps['published'] = (News.published.last.timestamp_publication - delta_time).to_i
      status_ref_timestamps['queued']    = (News.queued.last.timestamp_creation - delta_time).to_i
      status_ref_timestamps['discarded'] = (News.discarded.last.timestamp_creation - delta_time).to_i

      status_ref_timestamps.each do |status, ref_timestamp|
        index_counter = 1

        page = Wagg.page(status, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]

        while page.max_timestamp >= ref_timestamp || page.max_timestamp >= ref_timestamp
          # Parse and process each news in news_list to be stored in database
          page.news_list.each do |news_url, news|
            Delayed::Job.enqueue(NewsProcessor::NewsJob.new(news_url))
          end

          index_counter += 1
          page = Wagg.page(status, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
        end

      end

    end

    desc "Update all closed and incomplete news with available votes and comments"
    task  :complete =>  :environment  do

      news_list = News.closed.where(:complete => nil).union(News.closed.where(:complete => FALSE)).order(:timestamp_creation => :desc)

      news_list.each do |n|
        Delayed::Job.enqueue(NewsProcessor::NewsJob.new(n.url_internal))
        #NewsProcessor::NewsJob.new(n.url_internal).perform
      end

    end

    desc "Check consistency of scrapped news' votes and comments of each news and tag them 'complete' and/or 'faulty'"
    task  :check_consistency  => :environment do

      news_list = News.closed.where(:complete => nil).union(News.closed.where(:complete => FALSE)).order(:timestamp_creation => :desc)

      news_list.each do |n|
        n.complete = FALSE

        news_item = Wagg.news(n.url_internal)

        if news_item.voting_closed? && news_item.commenting_closed?
          n.faulty = FALSE

          if ((news_item.votes_count["positive"] > 0 && news_item.votes_count["positive"] != n.votes_positive.count) ||
              (news_item.votes_count["negative"] > 0 && news_item.votes_count["negative"] != n.votes_negative.count)) &&
              n.votes.count != 0
            n.faulty = TRUE
          end

          if news_item.comments_count != n.comments.count
            n.faulty = TRUE
          end

          n.complete = TRUE
        end

        n.save
      end

    end

  end

end