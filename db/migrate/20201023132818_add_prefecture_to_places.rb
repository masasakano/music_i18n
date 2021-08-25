class AddPrefectureToPlaces < ActiveRecord::Migration[6.0]
  def change
    remove_reference :places, :prefecture, foreign_key: true
    add_reference    :places, :prefecture, null: false, foreign_key: {on_delete: :cascade}
  end
end
