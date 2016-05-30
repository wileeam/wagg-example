require 'thread'

namespace :maintenance do

  # TODO: Tasks that rely only on database don't need threads, those using the Wagg API should use threads

  desc "TODO"
  task :todo =>  :environment  do

  end

  namespace :comments do

    THREAD_COMMENTS_WORKERS = 3
    COMMENTS_BATCH_SIZE = 500000

    desc "Updates votes of closed comments (those created between 30 and 60 days ago)"
    task :update_votes => :environment  do

      # Oldest to newest (ascending) order
      news_comments_id_list = NewsComment.joins(:comment).merge(Comment.incomplete.closed.where('comments.timestamp_creation > ?', 60.days.ago).order(:timestamp_creation => :asc)).pluck(:news_id).uniq
      news_comments_list = News.where(:id => news_comments_id_list)

      news_comments_queue = Queue.new
      news_comments_list.each do |n|
        news_comments_queue.push(n)
      end

      workers = (0..THREAD_COMMENTS_WORKERS).map do
        Thread.new do
          begin
            while n = news_comments_queue.pop(true)
              news_item = Wagg.news(n.url_internal)

              n.comments.incomplete.closed.each do |c|
                comment_news_index = c.news_index
                if news_item.comments.has_key?(comment_news_index) && news_item.comment(comment_news_index).id == c.id && news_item.comment(comment_news_index).votes_available?
                  news_comment_item = news_item.comment(comment_news_index)
                  if (news_comment_item.votes_count.nil? && !Author.find_by(:name => news_comment_item.author).disabled? && news_comment_item.votes.size != c.votes.count) ||
                      (!news_comment_item.votes_count.nil? && news_comment_item.votes_count != c.votes.count)
                    Delayed::Job.enqueue(VotesProcessor::VotingListJob.new(news_comment_item.id, 'Comment'))
                    #VotesProcessor::VotingListJob.new(news_comment_item.id, 'Comment').perform
                  end
                else
                  # TODO: Log event: comment's votes not available or no key or comment id doesn't match
                end
              end
            end
          rescue ThreadError
          end
        end
      end

      workers.map(&:join)

    end

    desc "Update all closed and incomplete comments with available"
    task  :complete =>  :environment  do

      # TODO Issue to query to count these comments and focus only on the ones that we can get some useful data, plus some extra to catch up with the past
      news_id_list = NewsComment.joins(:comment).merge(Comment.incomplete.closed.order(:timestamp_creation => :desc).limit(COMMENTS_BATCH_SIZE)).pluck(:news_id).uniq
      news_list = News.where(:id => news_id_list)

      news_list_queue = Queue.new
      news_list.each do |n|
        news_list_queue.push(n)
      end

      workers = (0..THREAD_COMMENTS_WORKERS).map do
        Thread.new do
          begin
            while n = news_list_queue.pop(true)
              news_item = Wagg.news(n.url_internal)
              if news_item.comments_available? && news_item.commenting_closed?
                comments_news_list = Comment.incomplete.closed.joins(:news_comments).merge(NewsComment.where(:news_id => n.id)).order(:timestamp_creation => :desc)
                comments_news_list.each do |c|
                  if c.id == news_item.comment(c.news_index).id
                    Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_item.comment(c.news_index)))
                    #CommentsProcessor::CommentJob.new(news_item.comment(c.news_index)).perform
                  else
                    # TODO Not good... raise an exception for the mismatch?
                  end
                end
              end
            end
          rescue ThreadError
          end
        end
      end

      workers.map(&:join)

    end


    desc "Check consistency of scrapped comments' votes tag them 'complete' and/or 'faulty'"
    task  :check_consistency  => :environment do

      DELAY = -1.day

      news_id_list = NewsComment.joins(:comment).merge(Comment.incomplete.closed(DELAY).order(:timestamp_creation => :desc).limit(COMMENTS_BATCH_SIZE)).pluck(:news_id).uniq
      news_list = News.where(:id => news_id_list)

      news_list_queue = Queue.new
      news_list.each do |n|
        news_list_queue.push(n)
      end

      workers = (0..THREAD_COMMENTS_WORKERS).map do
        Thread.new do
          begin
            while n = news_list_queue.pop(true)
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
          rescue ThreadError
          end
        end
      end

      workers.map(&:join)

    end

  end

  namespace :news do

    THREAD_NEWS_WORKERS = 3

    desc  "Updates votes of news prioritizing new negative votes and queued news"
    task  :update_votes =>  :environment  do

      # We add this time to account for shifts of news' statuses in the site
      delta_time = 6.hours

      status_ref_timestamps = Hash.new
      status_ref_timestamps['queued']    = (News.queued.open.order(:timestamp_creation => :asc).first.timestamp_creation - delta_time).to_i
      status_ref_timestamps['published'] = (News.published.open.order(:timestamp_creation => :asc).first.timestamp_publication - delta_time).to_i
      status_ref_timestamps['discarded'] = (News.discarded.open.order(:timestamp_creation => :asc).first.timestamp_creation - delta_time).to_i

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
      status_ref_timestamps['published'] = (News.published.order(:timestamp_publication => :asc).last.timestamp_publication - delta_time).to_i
      status_ref_timestamps['queued']    = (News.queued.order(:timestamp_creation => :asc).last.timestamp_creation - delta_time).to_i
      status_ref_timestamps['discarded'] = (News.discarded.order(:timestamp_creation => :asc).last.timestamp_creation - delta_time).to_i

      status_ref_timestamps.each do |status, ref_timestamp|
        index_counter = 1

        page = Wagg.page(status, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]

        while page.max_timestamp >= ref_timestamp || page.max_timestamp >= ref_timestamp
          # Parse and process each news in news_list to be stored in database
          page.news_list.each do |news_url, news|
            if !News.exists?(news.id)
              if Delayed::Job.where(:queue => 'news').count < 1000
                Delayed::Job.enqueue(NewsProcessor::NewsJob.new(news_url))
              else
                NewsProcessor::NewsJob.new(news_url).perform
              end
            end
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

      DELAY = -1.day

      news_list = News.incomplete.closed(DELAY).order(:timestamp_creation => :desc)

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