class Vote < ActiveRecord::Base
  self.primary_keys = :voter_id, :votable_id, :votable_type

  belongs_to  :voter,     :foreign_key => :voter_id, :class_name => Author

  belongs_to  :votable,   :polymorphic => true
  belongs_to  :comment,   -> { where(:votes => {:votable_type => 'Comment'}) },   :foreign_key => :votable_id
  belongs_to  :news,      -> { where(:votes => {:votable_type => 'News'}) },      :foreign_key => :votable_id

  def positive?
    self.rate >= 0
  end

  def negative?
    self.rate < 0
  end

end
