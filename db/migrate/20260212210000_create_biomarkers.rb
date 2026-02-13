class CreateBiomarkers < ActiveRecord::Migration[8.1]
  def change
    create_table :biomarkers do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :unit, null: false
      t.decimal :ref_min, null: false, precision: 10, scale: 2
      t.decimal :ref_max, null: false, precision: 10, scale: 2

      t.timestamps
    end

    add_index :biomarkers, :code, unique: true
    add_index :biomarkers, :name
  end
end
