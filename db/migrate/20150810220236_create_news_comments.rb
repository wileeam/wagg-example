class CreateNewsComments < ActiveRecord::Migration
  def change
    create_join_table :news,  :comments, :table_name => 'news_comments' do |t|
      t.integer     :news_id
      t.integer     :comment_id
      t.integer     :news_index
    end
    execute "ALTER TABLE news_comments ADD PRIMARY KEY (news_id, comment_id, news_index);"
  end
end
