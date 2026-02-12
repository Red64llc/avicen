class CreateTestResults < ActiveRecord::Migration[8.1]
  def change
    create_table :test_results do |t|
      t.references :biology_report, null: false, foreign_key: { on_delete: :cascade }
      t.references :biomarker, null: false, foreign_key: { on_delete: :restrict }
      t.decimal :value, null: false, precision: 10, scale: 2
      t.string :unit, null: false
      t.decimal :ref_min, precision: 10, scale: 2
      t.decimal :ref_max, precision: 10, scale: 2
      t.boolean :out_of_range

      t.timestamps
    end

    add_index :test_results, :out_of_range
  end
end
