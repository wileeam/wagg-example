class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.string :name, :limit => 191

      t.timestamps null: false
    end

    change_column(:categories, :name, :string, null: false, unique: true)

    add_index(:categories, :id, unique: true)
  end

end
