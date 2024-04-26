class AddEventItemToHarami1129s < ActiveRecord::Migration[7.0]
  def change
    add_reference :harami1129s, :event_item, null: true, foreign_key: true
  end
end
