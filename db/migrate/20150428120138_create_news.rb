class CreateNews < ActiveRecord::Migration
  def change
    create_table :news do |t|
      t.string      :title
      t.text        :description
      t.datetime    :timestamp_creation
      t.datetime    :timestamp_publication
      t.string      :url_internal
      t.string      :url_external
      t.integer     :karma
      t.integer     :votes_count_positive
      t.integer     :votes_count_negative
      t.integer     :votes_count_anonymous
      t.integer     :clicks
      t.integer     :comments_count

      t.references  :poster
      t.string      :category

      t.timestamps null: false
    end

    change_column(:news, :id, :integer, null: false, unique: true)

    add_foreign_key :news, :authors, name: :poster, column: :poster_id

    add_index(:news, :id, unique: true)
    add_index(:news, :poster_id)
    add_index(:news, :url_internal)
  end

end
