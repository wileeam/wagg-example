class Author < ActiveRecord::Base
  has_many                :votes
  has_many                :comments

  has_many                :news

  validates_uniqueness_of :id,        :scope => [:name]

  def self.find_or_update_by_name(name)
    author_item = Wagg.author(name)

    if author_item.nil?
      error = "Couldn't find Author record with name='%{name}'" %{name:name}
      raise ActiveRecord::RecordNotFound, error
    end
    author = self.find_or_initialize_by(id: author_item.id) do |a|
      a.signup = Time.at(author_item.creation).to_datetime
    end
    author.name = author_item.name
    author.save

    author
  end

end
