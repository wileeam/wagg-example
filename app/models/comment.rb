class Comment < ActiveRecord::Base
  belongs_to  :commenter, foreign_key: :commenter_id#, inverse_of: :authors

  has_many  :votes,         :as      => :votable

  has_many  :news_comments
  has_many  :news,        :through => :news_comments
end
