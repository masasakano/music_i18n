class AddMemoEditorToHaramiVids < ActiveRecord::Migration[7.0]
  def change
    add_column :harami_vids, :memo_editor, :text, comment: "Internal-use memo for Editors"
  end
end
