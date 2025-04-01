class AddMemoEditorToPlaces < ActiveRecord::Migration[7.0]
  def change
    add_column :places, :memo_editor, :text, comment: "Internal-use memo for Editors"
  end
end
