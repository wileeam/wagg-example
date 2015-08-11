class CreateAuthors < ActiveRecord::Migration
  def change
    create_table :authors do |t|
      t.string    :name
      t.timestamp :signup

      t.timestamps null: false
    end

    change_column(:authors, :id, :integer, null: false, unique: true)

    add_index(:authors, :id, unique: true)
  end
end
