class CreateEngageEventItemHows < ActiveRecord::Migration[7.0]
  def change
    create_table :engage_event_item_hows, comment: "How an Engage-EventItem is associated." do |t|
      t.string :mname, null: false, comment: "unique machine name"
      t.float :weight, null: false, default: 999.0, index: true, comment: "weight to sort entries in Index for Editors"
      t.text :note

      t.timestamps
    end

    add_index :engage_event_item_hows, :mname, unique: true #, name: "index_foo"
  end
end
