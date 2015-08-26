class Vote < ActiveRecord::Base
  self.primary_keys = :voter_id, :votable_id, :votable_type

  belongs_to  :voter,   foreign_key: :voter_id #inverse_of: :authors,
  belongs_to  :votable, polymorphic: true#,inverse_of: :votes,
end
