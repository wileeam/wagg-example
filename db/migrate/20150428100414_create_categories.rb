class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|

      t.string :name

      t.timestamps null: false
    end

    change_column(:categories, :name, :string, null: false, unique: true)

    add_index(:categories, :id, unique: true)
    add_index(:categories, :name, unique: true)
  end

end
