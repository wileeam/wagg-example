class Author < ActiveRecord::Base
  has_many  :votes#,     inverse_of: :author
  has_many  :comments#,  inverse_of: :author
  has_many  :news#,      inverse_of: :author

  validates_uniqueness_of :id, scope: [:name]
end
