class Author < ActiveRecord::Base
  has_many                :votes
  has_many                :comments

  has_many                :news

  validates_uniqueness_of :id,        :scope => [:name]

  def self.find_or_update_by_name(name)
    author_item = Wagg.author(name)

    author = self.find_or_initialize_by(id: author_item.id) do |a|
      a.signup = Time.at(author_item.creation).to_datetime
    end
    author.name = author_item.name
    author.save

    author
  end

end
