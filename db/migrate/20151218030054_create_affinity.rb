class CreateAffinity < ActiveRecord::Migration
  def change
    create_table :affinities, :id => false do |t|
      t.references  :minor
      t.references  :major
      t.datetime    :timestamp_begin
      t.datetime    :timestamp_end
      t.string      :status,              :limit => 191
      t.integer     :closeness_pos,       :default => 0
      t.integer     :closeness_neg,       :default => 0
      t.integer     :closeness_dif,       :default => 0
      t.float       :weighted_closeness,  :default => nil, :null => true

      t.timestamps null: false
    end

    add_foreign_key :affinities, :authors, name: :minor, column: :minor_id
    add_foreign_key :affinities, :authors, name: :major, column: :major_id

    execute "ALTER TABLE affinities ADD PRIMARY KEY (minor_id, major_id, timestamp_begin, timestamp_end, status(191));"

    add_index       :affinities, :minor_id
    add_index       :affinities, :major_id
    add_index       :affinities, [:timestamp_begin, :timestamp_end]
    add_index       :affinities, [:minor_id, :major_id]
  end
end
