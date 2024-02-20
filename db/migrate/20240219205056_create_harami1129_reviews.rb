class CreateHarami1129Reviews < ActiveRecord::Migration[7.0]
  def change
    create_table :harami1129_reviews, comment: "Harami1129 for which Artist or Music is updated" do |t|
      t.references :harami1129,      null: true , foreign_key: {on_delete: :nullify}, comment: "One of Harami1129 this change is applicable to; nullable"  # Once Harami1129 is deleted, this is nullified. Ideally, this should be "on_delete: :restrict"; then, before the corresponding Harami1129 is destroyed, either this value should be updated for any other Harami1129 or this record should be simply destroyed as irrelevant any more.  However, that would break some existing tests.  So, it is {on_delete: :nullify} for now.
      t.string :harami1129_col_name, null: false, comment: "Either ins_singer or ins_song"
      t.string :harami1129_col_val, comment: "String Value of column harami1129_col_name"
      t.references :engage,          null: false, foreign_key: {on_delete: :cascade},  comment: "Updated Engage"  # Engage (usually) may disappear only when multiple Engage-s are merged into one.  Ideally, this should be "{on_delete: :restrict}" so a new Engage is assigned instead in such a case.  However, it would need an extra routine to be invoked when Engage is destroyed, and to catch such a timing perfectly is rather complicated. Rather, I choose the record of Harami1129Review would be simply destroyed, considering Harami1129Review is used only for the administrators of this site and Harami1129.
      t.boolean :checked,  default: false, comment: "This record of Harami1129 is manually checked"
      t.references :user,            null: true,  foreign_key: {on_delete: :nullify},  comment: "Last User that created or updated, or nil"
      t.text :note

      t.timestamps
    end

    add_index :harami1129_reviews, [:harami1129_id, :harami1129_col_name], unique: true, name: "index_harami1129_reviews_unique01"
    add_index :harami1129_reviews, :harami1129_col_val
  end
end
