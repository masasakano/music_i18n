class CreatePrefectures < ActiveRecord::Migration[6.0]
  def change
    create_table :prefectures do |t|
      t.references :country, null: false, foreign_key: true
      t.text :note

      t.timestamps
    end
  end
end
