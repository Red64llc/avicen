class CreateMedicationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :medication_logs do |t|
      t.references :medication, null: false, foreign_key: true
      t.references :medication_schedule, null: false, foreign_key: true
      t.integer :status, null: false
      t.datetime :logged_at
      t.date :scheduled_date, null: false
      t.text :reason

      t.timestamps
    end

    add_index :medication_logs, [ :medication_schedule_id, :scheduled_date ], unique: true, name: "index_medication_logs_on_schedule_and_date"
    add_index :medication_logs, :scheduled_date
  end
end
