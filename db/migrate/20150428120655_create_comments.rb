class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      #t.integer     :position
      t.datetime    :timestamp_creation
      t.datetime    :timestamp_edition
      t.text        :body
      t.integer     :vote_count
      t.integer     :karma

      t.references  :commenter
      #t.references  :news

      t.timestamps null: false
    end

    change_column   :comments, :id, :integer, null: false, unique: true

    add_foreign_key :comments_processor, :authors, name: :commenter, column: :commenter_id
    #add_foreign_key :comments, :news,    name: :news,      column: :news_id

    add_index :comments,    :id,           unique: true
    add_index :comments,    :commenter_id
    #add_index :comments,   :news_id

  end
end
