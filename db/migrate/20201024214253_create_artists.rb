class CreateArtists < ActiveRecord::Migration[6.0]
  def change
    create_table :artists do |t|
      t.references :sex, null: false, foreign_key: true
      t.references :place, null: false, foreign_key: true
      t.integer :birth_year
      t.integer :birth_month
      t.integer :birth_day
      t.text :wiki_ja
      t.text :wiki_en
      t.text :note

      t.timestamps
    end

    add_index    :artists, [:birth_year, :birth_month, :birth_day], name: :index_artists_birthdate
  end
end
