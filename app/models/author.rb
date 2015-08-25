class Author < ActiveRecord::Base
  has_many                :votes
  has_many                :comments

  has_many                :news

  validates_uniqueness_of :id,        :scope => [:name]
end
