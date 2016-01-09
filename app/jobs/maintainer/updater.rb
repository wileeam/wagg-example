module Maintainer
  class Updater

    class << self

      def latest_submitted_news

        status = Hash.new
        status['published'] = News.published.last.timestamp_publication.to_i
        status['queued']    = News.queued.last.timestamp_creation.to_i
        status['discarded'] = News.discarded.last.timestamp_creation.to_i

        status.each do |news_type, ref_timestamp|
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

      def latest_votes_open_news

        status = Hash.new
        status['published'] = News.published.open.first.timestamp_publication.to_i
        status['queued']    = News.queued.open.first.timestamp_creation.to_i
        status['discarded'] = News.discarded.open.first.timestamp_creation.to_i

        status.each do |news_type, ref_timestamp|
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
                Rails.logger.info('Updating URL (%{nid}) => %{url}' % {nid: n.id, url: n.url_internal})
                Rails.logger.info('  Checking votes (%{nid})...' % {nid:n.id})
                if news_item.votes_available? && ((news_item.votes_count['positive'] != n.votes_positive.count) || (news_item.votes_count['negative'] != n.votes_negative.count))
                  Rails.logger.info '    Missing %{pos} pos :: %{neg} neg' % {pos:(news_item.votes_count['positive'] - n.votes_positive.count).abs, neg:(news_item.votes_count['negative'] - n.votes_negative.count).abs}
                  news_item.votes.each do |news_vote|
                    vote_author = Author.find_or_update_by_name(news_vote.author)
                    unless Vote.exists?([vote_author.id, n.id, 'News'])
                      Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news_vote.rate, n.id, 'News'))
                    end
                  end
                end
              end
            end

            index_counter += 1
            page = Wagg.page(news_type, :begin_interval => index_counter, :end_interval => index_counter)[index_counter]
          end

        end
      end


      def all_open_news
        news_list = News.open.order(:status => :asc, :timestamp_creation => :desc)
        news_list.each do |n|
          Rails.logger.info('Updating URL (%{nid}) => %{url}' % {nid: n.id, url: n.url_internal})
          news_item = Wagg.news(n.url_internal)

          Rails.logger.info('  Checking votes (%{nid})...' % {nid:n.id})
          if news_item.votes_available? && ((news_item.votes_count['positive'] != n.votes_positive.count) || (news_item.votes_count['negative'] != n.votes_negative.count))
            Rails.logger.info '    Missing %{pos} pos :: %{neg} neg' % {pos:(news_item.votes_count['positive'] - n.votes_positive.count).abs, neg:(news_item.votes_count['negative'] - n.votes_negative.count).abs}
            news_item.votes.each do |news_vote|
              vote_author = Author.find_or_update_by_name(news_vote.author)
              unless Vote.exists?([vote_author.id, n.id, 'News'])
                Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news_vote.rate, n.id, 'News'))
              end
            end
          end

          Rails.logger.info('  Checking comments (%{nid})...' % {nid:n.id})
          # Call to news_item.votes_available? is redundant as it always returns TRUE
          if news_item.votes_available? && news_item.comments_count > 0 && news_item.comments_count != n.comments.count
            Rails.logger.info('    Missing %{com}' % {com:(news_item.comments_count - n.comments.count).abs})
            news_item.comments.each do |_, news_comment|
              if !Comment.exists?(news_comment.id) || Comment.find(news_comment.id).incomplete?
                Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
              end
            end
          end

        end
      end

      def fix_news
        #news_list = News.incomplete.where('timestamp_creation < ?', 60.days.ago).order(:timestamp_creation => 'DESC')
        news_list = News.incomplete.closed.order(:timestamp_creation => 'DESC')
        news_list.each do |n|
          news_item = Wagg.news(n.url_internal)

          unless news_item.commenting_open?
            n.comments_count = news_item.comments_count
          end

          if news_item.votes_available? && news_item.comments_count > 0 && news_item.comments_count != n.comments.count
            #if news_item.comments_available? && (news_item.comments_count != n.comments.count || n.comments_incomplete?)
            news_item.comments.each do |_, news_comment|
              if !Comment.exists?(news_comment.id) || Comment.find(news_comment.id).incomplete?
                Delayed::Job.enqueue(CommentsProcessor::CommentJob.new(news_comment))
              end
            end
          end

          unless news_item.voting_open?
            n.clicks = news_item.clicks
            n.karma = news_item.karma
            n.votes_count_anonymous = news_item.votes_count['anonymous']
            n.votes_count_negative = news_item.votes_count['negative']
            n.votes_count_positive = news_item.votes_count['positive']
          end

          # Votes should not be available anymore, so now we check the news votes and also the comments themselves
          # But we try retrieving them
          if news_item.votes_available? && ((news_item.votes_count['positive'] != n.votes_positive.count) || (news_item.votes_count['negative'] != n.votes_negative.count))
            news_item.votes.each do |news_vote|
              vote_author = Author.find_or_update_by_name(news_vote.author)
              unless Vote.exists?([vote_author.id, n.id, 'News'])
                Delayed::Job.enqueue(VotesProcessor::VoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news_vote.rate, n.id, 'News'))
              end
            end
          end



          #if n.comments_incomplete? || n.votes_incomplete?
          #  n.faulty = TRUE
          #end

          #n.complete = TRUE
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