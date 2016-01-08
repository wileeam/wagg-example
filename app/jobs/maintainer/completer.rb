module Maintainer
  class Completer
    class << self

      def mark_news_complete_faulty

        latest_time = 30.days.ago
        news_list = News.published.where('timestamp_publication <= ?', latest_time).union(News.unpublished.where('timestamp_creation <= ?', latest_time)).order(:timestamp_creation => :asc)

        news_list.each do |news|
          news_item = Wagg.news(news.url_internal)

          # Add all missing comments (and their votes)
          if news_item.commenting_closed? && news_item.comments_available?
            news.comments_count = news_item.comments_count

            # First add the missing comments if any
            if news_item.comments_count != news.comments.count
              news_item.comments.each do |_, news_comment|
                unless Comment.exists?(news_comment.id)
                  CommentsProcessor::CommentJob.new(news_comment).perform
                end
              end
            end
          end

          # Add all missing NEWS votes
          if news_item.voting_closed? && news_item.votes_available?
            news.karma = news_item.karma
            news.votes_count_anonymous = news_item.votes_count['anonymous']
            news.votes_count_negative = news_item.votes_count['negative']
            news.votes_count_positive = news_item.votes_count['positive']

            if news_item.votes_count["positive"] != news.votes_positive.count || news_item.votes_count["negative"] != news.votes_negative.count
              news_item.votes.each do |news_vote|
                vote_author = Author.find_or_update_by_name(news_vote.author)
                # We overwrite the rate and weight of the vote if they changed due to a previous bug... sorry...
                begin
                  vote = Vote.find([vote_author.id, news.id, 'News'])
                rescue ActiveRecord::RecordNotFound => e
                  VotesProcessor::VoteJob.new(vote_author.name, news_vote.timestamp, news_vote.weight, news_vote.rate, news.id, "News").perform
                else
                  vote.rate = news_vote.rate
                  if vote.rate < 0 && news_vote.weight != vote.weight && vote.weight.nil?
                    vote.weight = news_vote.weight
                  end
                  vote.save
                end
              end
            end
          end

          news.clicks = news_item.clicks


          # Final checks for the news (yet to do one for each comment...)
          if news_item.voting_closed? && news_item.commenting_closed?
            news.faulty = FALSE

            if (news_item.votes_count["positive"] > 0 && news_item.votes_count["positive"] != news.votes_positive.count) ||
               (news_item.votes_count["negative"] > 0 && news_item.votes_count["negative"] != news.votes_negative.count)
              news.faulty = TRUE
            end

            if news_item.comments_count != news.comments.count
              news.faulty = TRUE
            end

            news.complete = TRUE
          end
          news.save
        end

      end

      def mark_comments_complete_faulty

        latest_time = 30.days.ago
        news_list = News.joins(:comments).where('comments.timestamp_creation <= ?', latest_time).order(:timestamp_creation => :desc).distinct

        news_list.each do |news|
          news_item = Wagg.news(news.url_internal)

          # Add all missing comments (and their votes)
          if news_item.commenting_closed? && news_item.comments_available?

            # Second add all missing COMMENTS votes
            # At this point we have all comments already, so we can rely on the database data instead
            news_item.comments.each do |_, news_comment|
              if news_comment.voting_closed? && news_comment.votes_available?
                comment = Comment.find(news_comment.id)
                if (news_comment.votes_count.nil? && !Author.find_by(:name => news_comment.author).disabled? && news_comment.votes.size != comment.votes.count) ||
                  (!news_comment.votes_count.nil? && news_comment.votes_count != comment.votes.count)
                  news_comment.votes.each do |comment_vote|
                    vote_author = Author.find_or_update_by_name(comment_vote.author)
                    # We overwrite the rate and weight of the vote if they changed due to a previous bug... sorry...
                    begin
                      vote = Vote.find([vote_author.id, comment.id, 'Comment'])
                    rescue ActiveRecord::RecordNotFound => e
                      VotesProcessor::VoteJob.new(vote_author.name, comment_vote.timestamp, comment_vote.weight, comment_vote.rate, comment.id, 'Comment').perform
                    else
                      vote.rate = comment_vote.rate
                      if vote.rate < 0 && comment_vote.weight != vote.weight && vote.weight.nil?
                        vote.weight = comment_vote.weight
                      end
                      vote.save
                    end
                  end
                end
              end
            end
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

    end
  end
end