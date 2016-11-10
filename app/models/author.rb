class Author < ActiveRecord::Base
  has_many                :votes,       :foreign_key => :voter_id
  has_many                :comments,    :foreign_key => :commenter_id
  has_many                :news,        :foreign_key => :poster_id
  has_many                :affinities,  :foreign_key => [:minor_id, :major_id]

  validates_uniqueness_of :id,          :scope => [:name]

  def disabled?
    match = self.name.match(/^--(?<id>\d+)--$/)
    # There is no need to compare the id with the matched one
    !match.nil? && self.id == match["id"].to_i
  end

  module Scopes
    def disabled
      where('name REGEXP "^--[[:digit:]]+--$"')
    end

    def find_or_update_by_name(name)
      author = Author.find_by(:name => name)

      if author.nil?
        begin
          author_item = Wagg.author(name)
        rescue Mechanize::ResponseCodeError => response_exception
          error = "User '%{name}' has changed its name => %{e}" %{name: name, e:response_exception.to_s}
          error = "User '%{name}' has changed its name => %{e}" % {name: name, e:response_exception.to_s}
          raise ActiveRecord::RecordNotFound, error
        end

        author = Author.find_or_initialize_by(:id => author_item.id) do |a|
          a.signup = Time.at(author_item.creation).to_datetime
        end
        author.name = author_item.name

        author.save
      end

      author
    end
  end
  extend Scopes

end
