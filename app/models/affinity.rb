class Affinity < ActiveRecord::Base
  self.primary_keys = :minor_id, :major_id, :week, :year, :status

  belongs_to  :author,     :foreign_key => [:minor_id, :major_id]
end
