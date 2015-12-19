class CreateAffinity < ActiveRecord::Migration
  def change
    create_table :affinities, :id => false do |t|
      t.references  :minor
      t.references  :major
      t.integer     :week
      t.integer     :closeness,           :default => 0
      t.float       :weighted_closeness,  :default => nil, :null => true

      t.timestamps null: false
    end

    add_foreign_key :affinities, :authors, name: :minor, column: :minor_id
    add_foreign_key :affinities, :authors, name: :major, column: :major_id

    execute "ALTER TABLE affinities ADD PRIMARY KEY (minor_id, major_id, week);"

    add_index       :affinities, :minor_id
    add_index       :affinities, :major_id
    add_index       :affinities, :week
    add_index       :affinities, [:minor_id, :major_id]
  end
end
