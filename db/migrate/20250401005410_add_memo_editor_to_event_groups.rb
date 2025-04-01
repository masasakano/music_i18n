class AddMemoEditorToEventGroups < ActiveRecord::Migration[7.0]
  def change
    add_column :event_groups, :memo_editor, :text, comment: "Internal memo for Editors"
  end
end
