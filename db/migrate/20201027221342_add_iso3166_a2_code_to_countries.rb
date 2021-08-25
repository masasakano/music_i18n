class AddIso3166A2CodeToCountries < ActiveRecord::Migration[6.0]
  def change
    add_column :countries, :iso3166_a2_code, :string, comment: 'ISO-3166-1 Alpha 2 code, JIS X 0304'
    add_index  :countries, :iso3166_a2_code, unique: true
    add_column :countries, :iso3166_a3_code, :string, comment: 'ISO-3166-1 Alpha 3 code, JIS X 0304'
    add_index  :countries, :iso3166_a3_code, unique: true
    add_column :countries, :iso3166_n3_code, :integer, comment: 'ISO-3166-1 Numeric code, JIS X 0304'
    add_index  :countries, :iso3166_n3_code, unique: true
    add_column :countries, :independent, :bool, comment: 'Independent in ISO-3166-1'
    add_column :countries, :territory, :text, comment: 'Territory name in ISO-3166-1'
    add_column :countries, :start_date, :date
    add_column :countries, :end_date, :date
    add_column :countries, :iso3166_remark, :text, comment: 'Remarks in ISO-3166-1, 2, 3'
    add_column :countries, :orig_note, :text, comment: 'Remarks by HirMtsd'
  end
end
