class CreateMedicationSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :medication_schedules do |t|
      t.references :medication, null: false, foreign_key: true
      t.string :time_of_day, null: false
      t.text :days_of_week, null: false
      t.string :dosage_amount
      t.text :instructions

      t.timestamps
    end
  end
end
