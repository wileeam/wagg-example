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
    Wagg.configure do |c|
      c.retrieval_delay['news'] = 4
      c.retrieval_delay['comment'] = 3
      #c.retrieval_delay['author'] = 2
    end

    news_urls_page_list = Hash.new
    #(init_index..end_index).each do |page_index|
    (end_index).downto(init_index) do |page_index|
      # Get a list of news urls from page index
      # TODO: Use interval computation buil-int feature from gem or add method in gem for single pages
      news_urls_page_list[page_index] = Wagg.page(page_index)[page_index].news_urls
    end
    Rails.logger.info 'Parsing %{urls_size} URLs' %{urls_size:news_urls_page_list.map{|_,list| list.size}.inject{|sum,x| sum + x}}

    #news_url = "https://www.meneame.net/story/estados-golfo-planean-respuesta-militar-siria-ante-aumento-rusa"
    #::ProcessNewsJob.new(news_url).perform
    #exit(0)

    # Parse and process each news in news_list to be stored in database
    news_urls_page_list.each do |page_index, news_urls_list|
      Rails.logger.info 'Processing page with index #%{index}' % {index:page_index}
      news_urls_list.each do |news_url|
        news = News.find_by_url_internal(news_url)
        if news.nil? || news.comments_count != news.comments.includes(:news_comments).count
          Rails.logger.info 'Parsing URL -> %{index}::%{url}' % {index:page_index, url:news_url}
          Delayed::Job.enqueue(NewsProcessor::NewNewsJob.new(news_url))
        end
      end
    end
  end

  def news
    n = News.find(2483835)
    puts n.closed?
    exit(0)

    Author.find_or_update_by_name('John_Doe')
    author_old_name = "plop"
    author_new_name = "plopp"
    #c = Comment.where("body LIKE ?", author_old_name)
    Comment.where("body LIKE ?", "%" + author_old_name + "%").update_all("body = REPLACE(body, '%{old}', '%{new}')" % {old:author_old_name, new:author_new_name})
    #SET Value = REPLACE(Value, '123', '')
    #puts c
    exit(0)

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

      news = News.find(:url_internal => comment_item.news_url)

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

  def votes

    # Get a list of news published between the last 60 and 30 days
    news_list = News.where(:timestamp_publication => 60.days.ago..30.days.ago).order(:timestamp_publication => :asc)
    # Iterate over each news and retrieve the votes
    news_list.each do |news|
      # Parse votes of news (last 30 days)
      if news.closed? && !news.karma.nil? && (news.votes_count_positive + news.votes_count_negative) != news.votes.count
        Rails.logger.info 'Parsing votes for news -> %{url}' % {url:news.url_internal}
        # Retrieve remaining votes for news
        Delayed::Job.enqueue(VotesProcessor::NewsVotesJob.new(news))
      end
    end

    # Get a list of comments published between the last 60 and 30 days
    comments_news_list = Comment.where(:timestamp_creation => 60.days.ago..30.days.ago).order(:timestamp_creation => :asc)
    comments_news_list.each do |comment|
      # Parse votes of comment (last 30 days)
      if comment.closed? && !comment.karma.nil? && !comment.vote_count.nil? && comment.vote_count > 0 && comment.votes.count != comment.vote_count
        Rails.logger.info 'Parsing votes for comment -> %{comment}' % {comment:comment.id}
        # Retrieve remaining votes for comment
        Delayed::Job.enqueue(VotesProcessor::CommentVotesJob.new(comment))
      end
    end

  end

end
