require 'wagg'

class RetrieveController < ApplicationController
  include Queriable

  def index
    puts 'plop'
  end

  def page
    redirect_to :update
  end

  def page_interval

    init_index = params[:init_index].to_i
    end_index = params[:end_index].to_i

    # Boundary checks
    if init_index < 0 || init_index > end_index
      # Return error
    end

    # Configuration parameters
    # TODO: Change so that first news and comments are retrieved and then the voting
    #       Perhaps the voting in two steps: from news and then from comments
    with_comments = TRUE
    with_votes = FALSE

    Wagg.configure do |c|
      c.retrieval_delay['page'] = 3
      c.retrieval_delay['author'] = 3
    end

    news_urls_page_list = Hash.new
    #(init_index..end_index).each do |page_index|
    (end_index).downto(init_index) do |page_index|
      # Get a list of news urls from page index
      news_urls_page_list[page_index] = Wagg.page(page_index).news_urls
    end
    Rails.logger.info 'Parsing %{urls_size} URLs' %{urls_size:news_urls_page_list.map{|_,list| list.size}.inject{|sum,x| sum + x}}

    #news_urls_page_list = Hash.new
    #news_urls_page_list['2'] = ['https://www.meneame.net/m/Preg%C3%BAntame/manel-fontdevila-humorista-grafico-preguntame']

    # Parse and process each news in news_list to be stored in database
    news_urls_page_list.each do |page_index, news_urls_list|
      Rails.logger.info 'Processing page with index #%{index}' % {index:page_index}
      news_urls_list.each do |news_url|
        news = News.find_by_url_internal(news_url)
        if news.nil? || news.comments_count != news.comments.includes(:news_comments).count
          Rails.logger.info 'Parsing URL -> %{index}::%{url}' % {index:page_index, url:news_url}
          # First: Parse the URL into a news object (can be done via Page object too)
          news_item = Wagg.news(news_url, with_comments, with_votes)

          # Third: Save main attributed of new news
          news = News.find_or_initialize_by(id: news_item.id) do |n|
            # Second: Check and create if needed author of news
            author = Author.find_or_initialize_by(id: news_item.author['id']) do |a|
              news_author_item = Wagg.author(news_item.author['name'])
              a.name = news_item.author['name']
              a.id = news_item.author['id']
              a.signup = Time.at(news_author_item.creation).to_datetime
            end
            author.save

            n.title = news_item.title
            n.description = news_item.description
            n.url_internal = news_item.urls['internal']
            n.url_external = news_item.urls['external']
            n.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
            n.timestamp_publication = Time.at(news_item.timestamps['publication']).to_datetime
            n.category = news_item.category
            n.poster_id = author.id

            # Fourth: Check and save if not existing news tags (and associate them)
            news_item.tags.each do |t|
              tag = Tag.find_or_initialize_by(name: t)
              tag.save
              n.tags << tag
            end
          end

          #Fifth: If news is closed we can save this data to the database (as it will not change)
          # TODO: Decide what to do with this light check...
          if news_item.closed?
            news.clicks = news_item.clicks
            news.karma = news_item.karma
            news.votes_count_anonymous = news_item.votes_count['anonymous']
            news.votes_count_negative = news_item.votes_count['negative']
            news.votes_count_positive = news_item.votes_count['positive']
            news.comments_count = news_item.comments_count
          end

          # Sixth: Store votes of news if available (and news is closed (implicit))
          if news_item.votes_available?
            news_item.votes.each do |news_vote|
              vote_author = Author.find_or_initialize_by(name: news_vote.author)
              if vote_author.id.nil?
                news_vote_author_item = Wagg.author(news_vote.author)
                vote_author.id = news_vote_author_item.id
                vote_author.signup = Time.at(news_vote_author_item.creation).to_datetime
                vote_author.save
              end
              vote = Vote.new(
                  voter_id: vote_author.id,
                  timestamp: Time.at(news_vote.timestamp).to_datetime,
                  weight: news_vote.weight
              )
              vote.votable = news
              vote.save
              news.votes << vote
            end
          end

          # Seventh: Store comment of news if available (and news is closed (implicit))
          if news_item.comments_available?
            news_item.comments.each do |news_comment_index, news_comment_item|

              comment = Comment.find_or_initialize_by(id: news_comment_item.id) do |c|
                comment_author_item = Wagg.author(news_comment_item.author)
                comment_author = Author.find_or_initialize_by(id: comment_author_item.id) do |a|
                  a.signup = Time.at(comment_author_item.creation).to_datetime
                end
                comment_author.name = comment_author_item.name
                comment_author.save

                c.commenter_id = comment_author.id
                c.timestamp_creation = Time.at(news_comment_item.timestamps['creation']).to_datetime
                c.body = news_comment_item.body
                c.vote_count = news_comment_item.vote_count
                c.karma = news_comment_item.karma
                unless news_comment_item.timestamps['edition'].nil?
                  c.timestamp_edition = Time.at(news_comment_item.timestamps['edition']).to_datetime
                end
              end

              if news_comment_item.votes_available?(news_item.timestamps)
                news_comment_item.votes.each do |comment_vote|
                  vote_author = Author.find_or_initialize_by(name: comment_vote.author)
                  if vote_author.id.nil?
                    comment_vote_author_item = Wagg.author(comment_vote.author)
                    vote_author.id = comment_vote_author_item.id
                    vote_author.signup = Time.at(comment_vote_author_item.creation).to_datetime
                    vote_author.save
                  end
                  vote = Vote.new(
                      voter_id: vote_author.id,
                      timestamp: Time.at(comment_vote.timestamp).to_datetime,
                      weight: comment_vote.weight
                  )
                  vote.votable = comment
                  vote.save
                  comment.votes << vote
                end
              end
              #comment.save && comment.news_comments.create(:news => news, :news_index => news_comment_index)
              comment.save
              unless comment.news_comments.exists?(:news => news, :news_index => news_comment_index)
                comment.news_comments.create(:news => news, :news_index => news_comment_index)
              end
            end
=begin
            ## Verify that all comments are in
            if news.comments.count != news.comments_count
              news_comments_index_list = NewsComment.where(:news => news).order(:news_index => :asc).pluck(:news_index)
              tracking_index = 1
              news_comments_index_list.each do |news_comment_index|
                while tracking_index != news_comment_index
                  # Retrieve tracking index for that news
                  corrected_news_url_internal = '%{news_url_internal}/c0%{news_comment_index}' % {news_url_internal: news.url_internal, news_comment_index: news_comment_index}
                  puts corrected_news_url_internal
                  corrected_news = Wagg.news(corrected_news_url_internal, TRUE, FALSE)
                  puts corrected_news
                  news_comment_item = corrected_news.comment(tracking_index)
                  puts news_comment_item
                  comment = Comment.find_or_initialize_by(id: news_comment_item.id) do |c|
                    comment_author_item = Wagg.author(news_comment_item.author)
                    comment_author = Author.find_or_initialize_by(id: comment_author_item.id) do |a|
                      a.signup = Time.at(comment_author_item.creation).to_datetime
                    end
                    comment_author.name = comment_author_item.name
                    comment_author.save

                    c.commenter_id = comment_author.id
                    c.timestamp_creation = Time.at(news_comment_item.timestamps['creation']).to_datetime
                    c.body = news_comment_item.body
                    c.vote_count = news_comment_item.vote_count
                    c.karma = news_comment_item.karma
                    unless news_comment_item.timestamps['edition'].nil?
                      c.timestamp_edition = Time.at(news_comment_item.timestamps['edition']).to_datetime
                    end
                  end
                  comment.save
                  unless comment.news_comments.exists?(:news => news, :news_index => tracking_index)
                    comment.news_comments.create(:news => news, :news_index => tracking_index)
                  end
                  # Update tracking_index and check again (there can be two consecutive comments missing)
                  tracking_index += 1
                end
                tracking_index += 1
              end
            end
            ##
=end
          end
        end
        news.save
      end
    end
  end

  def news

    id = params[:id].to_i

    if News.exists?(id)
      news = News.find(id)
      #news_object = Wagg.news(news.url_internal,TRUE,TRUE)
      puts news.url_internal
    else
      # Inform the user that there is no news with such id in the database
      puts "Nope... no news with such id: %{id}" %{id:params[:id]}
    end
  end

  def comment

    id = params[:id].to_i

    comment = Comment.find_or_initialize_by(id: id) do |c|
      comment_item = Wagg.comment(id, FALSE)
      comment_author_item = Wagg.author(comment_item.author)
      comment_author = Author.find_or_initialize_by(id: comment_author_item.id) do |a|
        a.signup = Time.at(comment_author_item.creation).to_datetime
      end
      comment_author.name = comment_author_item.name
      comment_author.save

      c.commenter_id = comment_author.id
      c.timestamp_creation = Time.at(comment_item.timestamps['creation']).to_datetime
      c.body = comment_item.body
      c.vote_count = comment_item.vote_count
      c.karma = comment_item.karma
      unless comment_item.timestamps['edition'].nil?
        c.timestamp_edition = Time.at(comment_item.timestamps['edition']).to_datetime
      end

      news = News.find_by_url_internal(comment_item.news_url)

      c.save
      unless c.news_comments.exists?(:news => news, :news_index => comment_item.news_index)
        c.news_comments.create(:news => news, :news_index => comment_item.news_index)
      end

    end

  end

  def comments

    ids = params[:id].split(',')

    ids.each do |id|
      #redirect_to
    end
  end

  def all_votes

    # Get a list of news published between the last 60 and 30 days
    news_list = News.where(:timestamp_publication => 60.days.ago..30.days.ago).order(:timestamp_publication => :asc)

    # Iterate over each news and retrieve the votes
    news_list.each do |news|
      # Parse votes of news (last 30 days)
      if (news.votes_count_positive + news.votes_count_negative) != news.votes.count
        Rails.logger.info 'Parsing votes for news -> %{url}' % {url:news.url_internal}
        # Retrieve remaining votes for news
        Delayed::Job.enqueue(::ProcessNewsVotesJob.new(news))
      end

      comments_news_list = news.comments.where(:timestamp_creation => 60.days.ago..30.days.ago).order(:timestamp_creation => :asc)
      comments_news_list.each do |comment|
        # Parse votes of comment (last 30 days)
        if !comment.vote_count.nil? && !comment.karma.nil? && comment.vote_count > 0 && comment.votes.count != comment.vote_count
          Rails.logger.info 'Parsing votes for comment -> %{comment}' % {comment:comment.id}
          # Retrieve remaining votes for comment
          Delayed::Job.enqueue(::ProcessCommentVotesJob.new(comment))
        end
      end
    end

  end

  def fix_news

    # Get a list of news missing meta-data (they were not closed by crawling date)
    # TODO: add constraint in where that news is closed, otherwise gets parsed and it is a waste of time
    news_list = News.where(:karma => nil)
    news_list.each do |news|
      Rails.logger.info 'Completing meta-data for news -> %{url}' % {url:news.url_internal}

      news_item = Wagg.news(news.url_internal, FALSE, FALSE)
      if news_item.closed?
        news.clicks = news_item.clicks
        news.karma = news_item.karma
        news.votes_count_anonymous = news_item.votes_count['anonymous']
        news.votes_count_negative = news_item.votes_count['negative']
        news.votes_count_positive = news_item.votes_count['positive']
        news.comments_count = news_item.comments_count
      end

      # Store in database the changes
      news.save
    end

    # Get a list of news with missing comments
    news_list = News.where('comments_count != (SELECT count(*) FROM news_comments WHERE news_comments.news_id = news.id)')
    news_list.each do |news|
      Rails.logger.info 'Completing comments for news -> %{url}' % {url:news.url_internal}

      news_item = Wagg.news(news.url_internal, TRUE, FALSE)

      if news_item.comments_available?
        news_item.comments.each do |news_comment_index, news_comment_item|

          comment = Comment.find_or_initialize_by(id: news_comment_item.id) do |c|
            comment_author_item = Wagg.author(news_comment_item.author)
            comment_author = Author.find_or_initialize_by(id: comment_author_item.id) do |a|
              a.signup = Time.at(comment_author_item.creation).to_datetime
            end
            comment_author.name = comment_author_item.name
            comment_author.save

            c.commenter_id = comment_author.id
            c.timestamp_creation = Time.at(news_comment_item.timestamps['creation']).to_datetime
            c.body = news_comment_item.body
            c.vote_count = news_comment_item.vote_count
            c.karma = news_comment_item.karma
            unless news_comment_item.timestamps['edition'].nil?
              c.timestamp_edition = Time.at(news_comment_item.timestamps['edition']).to_datetime
            end
          end

          if news_comment_item.votes_available?(news_item.timestamps)
            news_comment_item.votes.each do |comment_vote|
              vote_author = Author.find_or_initialize_by(name: comment_vote.author)
              if vote_author.id.nil?
                comment_vote_author_item = Wagg.author(comment_vote.author)
                vote_author.id = comment_vote_author_item.id
                vote_author.signup = Time.at(comment_vote_author_item.creation).to_datetime
                vote_author.save
              end
              vote = Vote.new(
                  voter_id: vote_author.id,
                  timestamp: Time.at(comment_vote.timestamp).to_datetime,
                  weight: comment_vote.weight
              )
              vote.votable = comment
              vote.save
              comment.votes << vote
            end
          end
          #comment.save && comment.news_comments.create(:news => news, :news_index => news_comment_index)
          comment.save
          unless comment.news_comments.exists?(:news => news, :news_index => news_comment_index)
            comment.news_comments.create(:news => news, :news_index => news_comment_index)
          end
        end
      end
      #news.save
    end

  end

end
