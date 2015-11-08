class CreateVotes < ActiveRecord::Migration
  def change
    create_table :votes, :id => false do |t|
      t.float       :weight
      t.datetime    :timestamp

      t.references  :votable, polymorphic: true
      t.references  :voter

      t.timestamps null: false
    end

    add_foreign_key :votes, :authors, name: :voter, column: :voter_id

    execute "ALTER TABLE votes ADD PRIMARY KEY (voter_id, votable_id, votable_type(191));"

    #add_index(:votes, :votable_type, length: 191)
    #add_index(:votes, :votable_id)
    #add_index(:votes, :voter_id)
  end
end
