class CreateVotes < ActiveRecord::Migration
  def change
    create_table :votes do |t|
      t.float       :weight
      t.datetime    :timestamp

      t.references  :votable, polymorphic: true, index: true
      t.references  :voter

      t.timestamps null: false
    end

    add_foreign_key :votes,  :authors, name: :voter, column: :voter_id

  end
end
