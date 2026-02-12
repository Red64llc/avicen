class CreateBiologyReports < ActiveRecord::Migration[8.1]
  def change
    create_table :biology_reports do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.date :test_date, null: false
      t.string :lab_name
      t.text :notes

      t.timestamps
    end

    add_index :biology_reports, :test_date
    add_index :biology_reports, [:user_id, :test_date]
  end
end
