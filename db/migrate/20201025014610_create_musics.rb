class CreateMusics < ActiveRecord::Migration[6.1]
  def change
    create_table :musics do |t|
      t.integer :year
      t.references :place, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.text :note

      t.timestamps
      t.check_constraint "year IS NULL OR year > 0", name: 'check_musics_on_year'
    end
  end
end
