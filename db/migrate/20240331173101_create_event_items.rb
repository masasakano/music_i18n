class CreateEventItems < ActiveRecord::Migration[7.0]
  def change
    create_table :event_items, comment: "EventItem in each Event such as a single Music playing" do |t|
      t.string :machine_title, null: false
      t.timestamp :start_time
      t.float :start_time_err, comment: "in second"
      t.float :duration_minute
      t.float :duration_minute_err, comment: "in second"
      t.float :weight
      t.float :event_ratio, comment: "Event-covering ratio [0..1]"
      t.references :event, null: false, foreign_key: {on_delete: :restrict}
      t.references :place, null: true, foreign_key: {on_delete: :nullify}
      t.text :note

      t.timestamps
    end

    add_index :event_items, :machine_title, unique: true
    add_index :event_items, :start_time
    add_index :event_items, :duration_minute
    add_index :event_items, :weight
    add_index :event_items, :event_ratio
  end
end
