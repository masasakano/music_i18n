class AddIso3166JpCodeToPrefectures < ActiveRecord::Migration[6.0]
  def change
    add_column :prefectures, :iso3166_loc_code, :integer, comment: 'ISO 3166-2:JP (etc) code (JIS X 0401:1973)'
    add_index :prefectures, :iso3166_loc_code, unique: true
    add_column :prefectures, :start_date, :date
    add_column :prefectures, :end_date, :date
    add_column :prefectures, :orig_note, :text, comment: 'Remarks by HirMtsd'
  end
end
