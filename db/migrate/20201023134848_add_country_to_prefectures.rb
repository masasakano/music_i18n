class AddCountryToPrefectures < ActiveRecord::Migration[6.0]
  def change
    remove_reference :prefectures, :country, foreign_key: true
    add_reference    :prefectures, :country, null: false, foreign_key: {on_delete: :cascade}
  end
end
