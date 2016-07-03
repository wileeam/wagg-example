class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.datetime    :timestamp_creation
      t.datetime    :timestamp_edition
      t.text        :body,                :limit => 16.megabytes - 1
      t.integer     :vote_count
      t.integer     :karma

      t.references  :commenter

      t.boolean     :complete
      t.boolean     :faulty

      t.timestamps null: false
    end

    change_column   :comments, :id, :integer, null: false, unique: true

    add_foreign_key :comments, :authors, name: :commenter, column: :commenter_id

    add_index :comments,    :id,           unique: true
    add_index :comments,    :commenter_id
    add_index :comments,    :timestamp_creation
  end
end
