class CreatePrescriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :prescriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :doctor_name
      t.date :prescribed_date, null: false
      t.text :notes

      t.timestamps
    end

    add_index :prescriptions, [ :user_id, :prescribed_date ]
  end
end
