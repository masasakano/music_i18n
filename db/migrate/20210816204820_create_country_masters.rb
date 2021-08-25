class CreateCountryMasters < ActiveRecord::Migration[6.1]
  def change
    create_table :country_masters, comment: 'Country code in JIS X 0304:2011 and ISO 3166-1:2013' do |t|
      t.string  :iso3166_a2_code, comment: 'ISO 3166-1 alpha-2, JIS X 0304'
      t.string  :iso3166_a3_code, comment: 'ISO 3166-1 alpha-3, JIS X 0304'
      t.integer :iso3166_n3_code, comment: 'ISO 3166-1 numeric-3, JIS X 0304'
      t.string :name_ja_full
      t.string :name_ja_short
      t.string :name_en_full
      t.string :name_en_short
      t.string :name_fr_full
      t.string :name_fr_short
      t.boolean :independent, comment: 'Flag in ISO-3166'
      t.json :territory, comment: 'Territory names in ISO-3166-1 in Array'
      t.json :iso3166_remark, comment: 'Remarks in ISO-3166-1, 2, 3 in Hash'
      t.text :orig_note, comment: 'Remarks by HirMtsd'
      t.date :start_date
      t.date :end_date
      t.text :note

      t.timestamps
    end
    add_index :country_masters, :iso3166_a2_code, unique: true
    add_index :country_masters, :iso3166_a3_code, unique: true
    add_index :country_masters, :iso3166_n3_code, unique: true
  end
end
