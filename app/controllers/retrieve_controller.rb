require 'wagg'

class RetrieveController < ApplicationController

  def page

  end

  def page_interval

    init_index = params[:init_index].to_i
    end_index = params[:end_index].to_i

    # Boundary checks
    if init_index < 0 || init_index > end_index
      # Return error
    end

    # Parse in batches of size PAGE_BATCH_SIZE
    (init_index..end_index).step(PAGE_BATCH_SIZE) do |page_index|

      # Fix page interval parsing boundaries
      page_init_index = page_index
      page_end_index = page_index + (PAGE_BATCH_SIZE - 1) > end_index ? end_index : page_index + (PAGE_BATCH_SIZE - 1)

      # Parse all news from page page_index
      news_list = Wagg.crawl_page_interval(page_init_index, page_end_index, TRUE, TRUE)

      # INIT DEBUG
      #news_list = Array.new
      #test_url = 'https://www.meneame.net/story/descubren-restos-arqueologicos-tarragona-unos-14-000-anos'
      #news_list <<  Wagg.crawl_news(test_url, TRUE, TRUE)
      #puts news_list
      # END DEBUG

      # Process each news in news_list to be stored in database
      news_list.each do |news_item|
        # Check for existing author
        author = Author.find_or_initialize_by(name: news_item.author['name']) do |field|
          news_author_item = Wagg.crawl_author(news_item.author['name'])
          field.signup = Time.at(news_author_item.creation).to_datetime
        end
        if author.id.nil?
          author.id = news_item.author['id']
        else
          if author.id != news_item.author['id']
            puts "ERROR: News (%{id_news}) has two different users (%{author_id_db} - %{author_id_news}) with the same user name (%{name)" % {id_news: news_item.id, author_id_db: author.id, author_id_news: news_item.author['name'], author_name: news_item.author['name']}
          end
        end
        author.save

        # Check for existing news
        news = News.find_or_initialize_by(id: news_item.id) do |field|
          field.title = news_item.title
          field.description = news_item.description
          field.url_internal = news_item.urls['internal']
          field.url_external = news_item.urls['external']
          field.timestamp_creation = Time.at(news_item.timestamps['creation']).to_datetime
          field.timestamp_publication = Time.at(news_item.timestamps['publication']).to_datetime
          field.category = news_item.category
          field.poster_id = author.id
        end

        # Parse news tags
        news_item.tags.each do |t|
          tag = Tag.find_or_initialize_by(name: t)
          tag.save
          news.tags << tag
        end

        # TODO: Decide what to do with this light check...
        # If news is closed we can save this data to the database (as it is not change)
        if news_item.closed?
          news.clicks = news_item.clicks
          news.karma = news_item.karma
          news.votes_count_anonymous = news_item.votes_count['anonymous']
          news.votes_count_negative = news_item.votes_count['negative']
          news.votes_count_positive = news_item.votes_count['positive']
          news.comments_count = news_item.comments_count
        end

        # We store votes of news if available (and news is closed (implicit))
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

        if news_item.comments_available?

          news_item.comments.each do |news_comment_position, news_comment_item|

            comment_author = Author.find_or_initialize_by(name:news_comment_item.author)
            if comment_author.id.nil?
              comment_author_item = Wagg.crawl_author(news_comment_item.author)
              comment_author.id = comment_author_item.id
              comment_author.signup = Time.at(comment_author_item.creation).to_datetime
              comment_author.save
            end

            comment = Comment.new(
                id: news_comment_item.id,
                commenter_id: comment_author.id,
                timestamp_creation: Time.at(news_comment_item.timestamps['creation']).to_datetime,
                body: news_comment_item.body,
                vote_count: news_comment_item.vote_count,
                karma: news_comment_item.karma
            )
            puts comment_author.name
            puts news_comment_item.timestamps
            unless news_comment_item.timestamps['edition'].nil?
              comment.timestamp_edition = news_comment_item.timestamps['edition']
            end

            if news_comment_item.votes_available?(news_item.timestamps)
              news_comment_item.votes.each do |comment_vote|
                vote_author = Author.find_or_initialize_by(name:comment_vote.author)
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

            #news.save && news.news_comments.create(:comment => comment, :position => news_comment_position)
            comment.save && comment.news_comments.create(:news => news, :position => news_comment_position)
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
      puts "Nope... no news with such id: #{id}"
    end
  end

  def comment
    News.find_each(:batch_size => 25) do |news|
      puts news.url_internal

    end

  end

  def vote

  end
end
