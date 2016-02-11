class Affinity < ActiveRecord::Base
  self.primary_keys = :minor_id, :major_id, :timestamp_begin, :timestamp_end, :status

  belongs_to  :author,     :foreign_key => [:minor_id, :major_id]


  module Scopes

  end
  extend Scopes

end
