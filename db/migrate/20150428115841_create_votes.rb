class CreateVotes < ActiveRecord::Migration
  def change
    create_table :votes do |t|
      t.float       :weight
      t.datetime    :timestamp

      t.references  :votable, polymorphic: true
      t.references  :voter

      t.timestamps null: false
    end

    add_foreign_key :votes,  :authors, name: :voter, column: :voter_id

    add_index(:votes, :id, unique: true)

    add_index(:votes, :votable_type, length: 191)
    add_index(:votes, :votable_id)
  end
end
