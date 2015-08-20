class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string    :name, :limit => 191

      t.timestamps null: false
    end

    change_column(:tags, :name, :string, null: false, unique: true)

    add_index :tags, :name, unique: true, :length => 191
  end
end
