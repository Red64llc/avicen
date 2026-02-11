class CreateDrugs < ActiveRecord::Migration[8.1]
  def change
    create_table :drugs do |t|
      t.string :name, null: false
      t.string :rxcui
      t.text :active_ingredients

      t.timestamps
    end

    add_index :drugs, :name
    add_index :drugs, :rxcui, unique: true
  end
end
