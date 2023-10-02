class CreateEventGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :event_groups, comment: 'Event Group, mutually exclusive, typically lasting less than a year' do |t|
      t.integer :order_no, index: true, comment: 'Serial number for a series of Event Group, e.g., 5(-th)'
      t.integer :start_year, index: true
      t.integer :start_month, index: true
      t.integer :start_day, index: true
      t.integer :end_year
      t.integer :end_month
      t.integer :end_day
      t.references :place, index: true, null: true, foreign_key: {on_delete: :nullify}
      t.text :note

      t.timestamps
    end
  end
end
