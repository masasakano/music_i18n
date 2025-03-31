class AddMemoEditorToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :memo_editor, :text
  end
end
