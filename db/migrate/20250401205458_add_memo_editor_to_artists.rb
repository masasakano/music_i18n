class AddMemoEditorToArtists < ActiveRecord::Migration[7.0]
  def change
    add_column :artists, :memo_editor, :text, comment: "Internal-use memo for Editors"
  end
end
