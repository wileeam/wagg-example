class NewsTag < ActiveRecord::Base
  belongs_to  :news,    foreign_key: :news_id
  belongs_to  :tag,     foreign_key: :tag_id
end
