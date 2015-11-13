class CreateNewsTags < ActiveRecord::Migration
  def change
    create_join_table :news,  :tags do |t|
      t.references  :news
      t.references  :tag
    end

    add_foreign_key :news_tags, :news,    name: :news,    column:  :news_id
    add_foreign_key :news_tags, :tags,    name: :tag,     column:  :tag_id
  end
end
