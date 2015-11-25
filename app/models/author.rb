class Author < ActiveRecord::Base
  has_many                :votes
  has_many                :comments
  has_many                :news

  validates_uniqueness_of :id,        :scope => [:name]

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
        author_item = Wagg.author(name)

        if author_item.nil?
          error = "Couldn't find Author record with name='%{name}'" %{name: name}
          raise ActiveRecord::RecordNotFound, error
        end

        #TODO: Do we really need to issue a query here?
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
