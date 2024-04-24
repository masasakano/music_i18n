class CreateHaramiVidEventItemAssocs < ActiveRecord::Migration[7.0]
  def change
    create_table :harami_vid_event_item_assocs, comment: "Association between HaramiVid and EventItem" do |t|
      t.references :harami_vid, null: false, foreign_key: {on_delete: :cascade}
      t.references :event_item, null: false, foreign_key: {on_delete: :cascade}
      t.integer :timing, index: true, comment: "in second; boundary with another EventItem like Artist's appearance"
      t.text :note

      t.timestamps
    end

    add_index :harami_vid_event_item_assocs, [:harami_vid_id, :event_item_id], unique: true, name: "index_harami_vid_event_item"
  end
end
