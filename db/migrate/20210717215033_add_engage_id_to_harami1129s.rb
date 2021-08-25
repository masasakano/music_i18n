class AddEngageIdToHarami1129s < ActiveRecord::Migration[6.1]
  def change
    add_reference :harami1129s, :engage, null: true, foreign_key: {on_delete: :restrict}  # null is allowed.
    add_column :harami1129s, :orig_modified_at, :datetime, comment: 'Any downloaded column modified at'
    add_index  :harami1129s, :orig_modified_at
    add_column :harami1129s, :checked_at, :datetime, comment: 'Insertion validity manually confirmed at'
    add_index  :harami1129s, :checked_at
  end
end
