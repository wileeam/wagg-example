class CreateNewsTags < ActiveRecord::Migration
  def change
    create_join_table :news,  :tags do |t|
      t.index       :news_id
      t.index       :tag_id
    end
  end
end
