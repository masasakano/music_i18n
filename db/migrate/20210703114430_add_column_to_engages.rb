class AddColumnToEngages < ActiveRecord::Migration[6.1]
  def change
    add_reference   :engages, :engage_how, null: false, foreign_key: {on_delete: :restrict}	
    #add_foreign_key :engages, :engage_hows, on_delete: :restrict
    #add_index       :engages, :engage_how_id
    #change_column_null :engages, :engage_how_id, false
  end
end
