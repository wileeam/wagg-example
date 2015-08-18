class CreateNewsComments < ActiveRecord::Migration
  def change
    create_join_table :news,  :comments, :table_name => 'news_comments' do |t|
      t.index       :news_id
      t.index       :comment_id

      t.integer     :news_index
    end
  end
end
