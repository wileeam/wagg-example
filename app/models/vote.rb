class Vote < ActiveRecord::Base
  belongs_to  :voter,   foreign_key: :voter_id #inverse_of: :authors,
  belongs_to  :votable, polymorphic: true#,inverse_of: :votes,
end
