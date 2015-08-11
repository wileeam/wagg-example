class Comment < ActiveRecord::Base
  has_many    :votes,     as: :votable
  belongs_to  :commenter, foreign_key: :commenter_id#, inverse_of: :authors

  has_many  :news_comments
  has_many  :newses,        :through => :news_comments
end
