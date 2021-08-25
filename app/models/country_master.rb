# == Schema Information
#
# Table name: country_masters
#
#  id                                                  :bigint           not null, primary key
#  end_date                                            :date
#  independent(Flag in ISO-3166)                       :boolean
#  iso3166_a2_code(ISO 3166-1 alpha-2, JIS X 0304)     :string
#  iso3166_a3_code(ISO 3166-1 alpha-3, JIS X 0304)     :string
#  iso3166_n3_code(ISO 3166-1 numeric-3, JIS X 0304)   :integer
#  iso3166_remark(Remarks in ISO-3166-1, 2, 3 in Hash) :json
#  name_en_full                                        :string
#  name_en_short                                       :string
#  name_fr_full                                        :string
#  name_fr_short                                       :string
#  name_ja_full                                        :string
#  name_ja_short                                       :string
#  note                                                :text
#  orig_note(Remarks by HirMtsd)                       :text
#  start_date                                          :date
#  territory(Territory names in ISO-3166-1 in Array)   :json
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_country_masters_on_iso3166_a2_code  (iso3166_a2_code) UNIQUE
#  index_country_masters_on_iso3166_a3_code  (iso3166_a3_code) UNIQUE
#  index_country_masters_on_iso3166_n3_code  (iso3166_n3_code) UNIQUE
#
class CountryMaster < ApplicationRecord
  has_many :countries, dependent: :restrict_with_exception
end

