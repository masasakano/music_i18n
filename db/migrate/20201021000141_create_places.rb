class CreatePlaces < ActiveRecord::Migration[6.0]
  def change
    create_table :places do |t|
      t.references :prefecture, null: false, foreign_key: true
      t.text :note

      t.timestamps
    end
  end
end
