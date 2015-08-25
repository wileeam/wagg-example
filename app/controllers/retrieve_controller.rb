require 'wagg'

class RetrieveController < ApplicationController
  include Queriable

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
      news_urls_page_list[page_index] = Wagg::Crawler::Page.new(page_index).news_urls
    end
    Rails.logger.info 'Parsing %{urls_size} URLs' %{urls_size:news_urls_page_list.map{|_,list| list.size}.inject{|sum,x| sum + x}}

    # Parse and process each news in news_list to be stored in database
    news_urls_page_list.each do |page_index, news_urls_list|
      Rails.logger.info 'Processing page with index #%{index}' % {index:page_index}
      news_urls_list.each do |news_url|
        news = News.find_by_url_internal(news_url)
        if news.nil? || news.comments_count != news.comments.includes(:news_comments).count
          Rails.logger.info 'Parsing URL -> %{index}::%{url}' % {index:page_index, url:news_url}
          # First: Parse the URL into a news object (can be done via Page object too)
          news_item = Wagg.crawl_news(news_url, with_comments, with_votes)

          # Second: Check and create if needed author of news
          author = Author.find_or_initialize_by(id: news_item.author['id']) do |a|
            news_author_item = Wagg.crawl_author(news_item.author['name'])
            a.name = news_item.author['name']
            a.id = news_item.author['id']
            a.signup = Time.at(news_author_item.creation).to_datetime
          end
          author.save

          # Third: Save main attributed of new news
          news = News.new do |n|
            n.id = news_item.id
            n.title = news_item.title
            n.description = news_item.description
            n.url_internal = news_item.urls['internal']
            n.url_external = news_item.urls['external']
            n.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
            n.timestamp_publication = Time.at(news_item.timestamps['publication']).to_datetime
            n.category = news_item.category
            n.poster_id = author.id
          end

          # Fourth: Check and save if not existing news tags (and associate them)
          news_item.tags.each do |t|
            tag = Tag.find_or_initialize_by(name: t)
            tag.save
            news.tags << tag
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
                news_vote_author_item = Wagg.crawl_author(news_vote.author)
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
              comment_author_item = Wagg.crawl_author(news_comment_item.author)
              comment_author = Author.find_or_initialize_by(id: comment_author_item.id) do |a|
                a.signup = Time.at(comment_author_item.creation).to_datetime
              end
              comment_author.name = comment_author_item.name
              comment_author.save

              comment = Comment.find_or_initialize_by(id: news_comment_item.id) do |c|
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
                    comment_vote_author_item = Wagg.crawl_author(comment_vote.author)
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

        end
        news.save
        end
    end
  end

  def news

    id = params[:id].to_i

    if News.exists?(id)
      news = News.find(id)
      #news_object = Wagg.crawl_news(news.url_internal,TRUE,TRUE)
      puts news.url_internal
    else
      # Inform the user that there is no news with such id in the database
      puts "Nope... no news with such id: %{id}" %{id:params[:id]}
    end
  end

  def all_comments

    # We first filter the news that are no more than 60 days old
    news_list = News.where(:timestamp_publication => 60.days.ago..DateTime.now)
    news_list.each do |news|
      comments_news_list = news.comments.where(:timestamp_creation => :timestamp_creation + 30.days.ago)
      puts comments_news_list
    end
    exit(0)
    #comments_list = Comment.where(:timestamp_creation => 60.days.ago..DateTime.now)
    #comments_list.each do |comment|
    #  puts comment.news.count
    #end

    #news.comments.includes(:news_comments).count
    #comments.each do |c|
    #  puts c.id
    #end

  end

  def all_votes

    news_list = News.where(:timestamp_publication => 60.days.ago..DateTime.now)
    news_list.each do |news|
      Rails.logger.info 'Parsing votes for news -> %{url}' % {url:news.url_internal}
      #Parse votes of news (last 30 days)
      if (news.votes_count_positive + news.votes_count_negative) != news.votes.count
        # Retrieve remaning votes for news
        # TODO: Retrieve all votes and check again that retrieved votes match the news counting
        news_votes_items = Wagg.crawl_news_for_votes(news.id)
        if news_votes_items.size == (news.votes_count_positive + news.votes_count_negative)
          news_votes_items.each do |news_vote_item|
            vote_author = Author.find_or_initialize_by(name: news_vote_item.author)
            if vote_author.id.nil?
              news_vote_author_item = Wagg.crawl_author(news_vote_item.author)
              vote_author.id = news_vote_author_item.id
              vote_author.signup = Time.at(news_vote_author_item.creation).to_datetime
              vote_author.save
            end
            vote = Vote.new(
                voter_id: vote_author.id,
                timestamp: Time.at(news_vote_item.timestamp).to_datetime,
                weight: news_vote_item.weight
            )
            vote.votable = news
            vote.save
            news.votes << vote
          end
        else
          Rails.logger.error 'Inconsistent votes for news -> %{url}' % {url:news.url_internal}
        end
      end
    end

  end

end
