class CreateMedications < ActiveRecord::Migration[8.1]
  def change
    create_table :medications do |t|
      t.references :prescription, null: false, foreign_key: true
      t.references :drug, null: false, foreign_key: true
      t.string :dosage, null: false
      t.string :form, null: false
      t.text :instructions
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :medications, :active
  end
end
