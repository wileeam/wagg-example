namespace :maintenance do

  desc "TODO"
  task :todo =>  :environment  do

  end

  namespace :comments do
    desc "Updates votes of closed comments (those created between 30 and 60 days ago)"
    task :update_votes => :environment  do

      comments_list = Comment.incomplete.closed(-1.day).order(:timestamp_creation => :desc)
      #comments_list = Comment.joins(:news_comments).incomplete.where('comments.timestamp_creation > ?', 2.days.ago).group('news_comments.news_id').having('comments.timestamp_creation = min(comments.timestamp_creation)')
      news_comments_list = News.joins(:comments).merge(comments_list).distinct

      news_comments_list.each do |n|
        Delayed::Job.enqueue(VotesProcessor::NewsCommentsVotesJob.new(n.id, timestamp_thresholds))
        #VotesProcessor::NewsCommentsVotesJob.new(n.id, timestamp_thresholds).perform
      end

    end

    desc "Update all closed and incomplete comments with available"
    task  :complete =>  :environment  do

      comments_list = Comment.incomplete.closed.order(:timestamp_creation => :desc)
      #comments_list = Comment.incomplete.where('timestamp_creation >= ?', 60.days.ago).where('timestamp_creation <= ?', 30.days.ago).order(:timestamp_creation => :asc)
      # TODO Order news_list by comments whose votes are to expire earlier
      news_list = News.joins(:comments).merge(comments_list).distinct

      news_list.each do |n|
        news_item = Wagg.news(n.url_internal)

        if news_item.comments_available? && news_item.commenting_closed?
          comments_news_list = Comment.incomplete.closed.joins(:news).where(:news => {:id => n.id}).order(:timestamp_creation => :desc)
          comments_news_list.each do |c|
            if c.id == news_item.comment(c.news_index).id
              #Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_item.comment(c.news_index)))
              CommentsProcessor::CommentJob.new(news_item.comment(c.news_index)).perform
            else
              # TODO Not good... raise an exception for the mismatch?
            end
          end
        end
      end

    end


    desc "Check consistency of scrapped comments' votes tag them 'complete' and/or 'faulty'"
    task  :check_consistency  => :environment do

      comments_list = Comment.incomplete.closed(-1.day).order(:timestamp_creation => :desc)
      news_comments_list = News.joins(:comments).merge(comments_list).distinct

      news_comments_list.each do |n|
        news_item = Wagg.news(n.url_internal)

        news_item.comments.each do |_, news_comment|
          c = Comment.find(news_comment.id)

          if (c.complete.nil? || c.complete == FALSE) && c.closed?
            c.complete = FALSE

            if news_comment.voting_closed?
              c.faulty = FALSE

              if (news_comment.votes_count.nil? && !Author.find_by(:name => news_comment.author).disabled? && news_comment.votes_available? && news_comment.votes.size != c.votes.count) ||
                  (!news_comment.votes_count.nil? && news_comment.votes_count != c.votes.count)
                c.faulty = TRUE
              end

              c.complete = TRUE
            end

            c.save
          end
        end
      end

    end

  end

  namespace :news do
    desc  "Updates votes of news prioritizing new negative votes and queued news"
    task  :update_votes =>  :environment  do

      # We add this time to account for shifts of news' statuses in the site
      delta_time = 6.hours

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
      delta_time = 6.hours

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

      news_list = News.closed.incomplete.order(:timestamp_creation => :desc)

      news_list.each do |n|
        Delayed::Job.enqueue(NewsProcessor::NewsJob.new(n.url_internal))
        #NewsProcessor::NewsJob.new(n.url_internal).perform
      end

    end

    desc "Check consistency of scrapped news' votes and comments of each news and tag them 'complete' and/or 'faulty'"
    task  :check_consistency  => :environment do

      news_list = News.incomplete.closed(-1.day).order(:timestamp_creation => :desc)

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