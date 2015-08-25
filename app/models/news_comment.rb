class NewsComment < ActiveRecord::Base
  self.primary_keys = :news_id, :comment_id, :news_index
  belongs_to  :news
  belongs_to  :comment
end
