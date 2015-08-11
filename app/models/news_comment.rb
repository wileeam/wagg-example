class NewsComment < ActiveRecord::Base
  belongs_to  :news
  belongs_to  :comment

  validates_presence_of :position
end
