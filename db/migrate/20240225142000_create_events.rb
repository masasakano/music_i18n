class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events, comment: "Event such as a solo concert" do |t|
      t.timestamp :start_time
      t.bigint :start_time_err, comment: "in second"
      t.float :duration_hour
      t.float :weight
      t.references :event_group, null: false, foreign_key: {on_delete: :restrict}
      t.references :place,       null: true, foreign_key: {on_delete: :nullify}
      t.text :note

      t.timestamps
    end

    add_index :events, :start_time
    add_index :events, :duration_hour
    add_index :events, :weight
  end
end
