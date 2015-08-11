class Tag < ActiveRecord::Base
  has_many  :news_tags
  has_many  :newses,    :through => :news_tags

  validates_uniqueness_of :id, scope: [:name]
end
