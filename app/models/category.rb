class Category < ActiveRecord::Base
  validates_uniqueness_of :id, scope: [:name]
end
