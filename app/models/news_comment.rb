class NewsComment < ActiveRecord::Base
  self.primary_keys = :news_id, :comment_id, :news_index

  belongs_to  :news,    :foreign_key => :news_id
  belongs_to  :comment, :foreign_key => :comment_id

  module Scopes
    def comments_count(news_id)
      where(:news_id => news_id).count
    end
  end
  extend Scopes

end
