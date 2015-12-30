class CreateNews < ActiveRecord::Migration
  def change
    create_table :news do |t|
      t.text        :title
      t.text        :description
      t.string      :category, :limit => 191
      t.string      :status, :limit => 191
      t.datetime    :timestamp_creation
      t.datetime    :timestamp_publication
      t.text        :url_internal
      t.text        :url_external
      t.integer     :karma
      t.integer     :votes_count_positive
      t.integer     :votes_count_negative
      t.integer     :votes_count_anonymous
      t.integer     :clicks
      t.integer     :comments_count

      t.references  :poster

      t.boolean     :complete
      t.boolean     :faulty

      t.timestamps null: false
    end

    change_column(:news, :id, :integer, null: false, unique: true)

    add_foreign_key :news, :authors, name: :poster, column: :poster_id

    add_index(:news, :id, unique: true)
    add_index(:news, :poster_id)
    add_index(:news, :url_internal, :length => 191)
  end

end
