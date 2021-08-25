class CreateEngages < ActiveRecord::Migration[6.1]
  def change
    create_table :engages do |t|
      t.references :music, null: false, foreign_key: {on_delete: :cascade}
      t.references :artist, null: false, foreign_key: {on_delete: :cascade}
      t.float :contribution
      t.integer :year
      t.text :note

      t.timestamps
      t.check_constraint "year IS NULL OR year > 0", name: 'check_engages_on_year'
    end

    add_index :engages, [:music_id, :artist_id], unique: true
  end
end
