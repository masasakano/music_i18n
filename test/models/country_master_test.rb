# coding: utf-8
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
require "test_helper"

class CountryMasterTest < ActiveSupport::TestCase
  test "has_many" do
    cm = country_masters(:aus_master)
    assert_equal 1, cm.countries.count
    assert_equal cm.iso3166_a3_code, cm.countries.first.iso3166_a3_code
    assert_raises(ActiveRecord::DeleteRestrictionError){
      cm.destroy }
    assert_equal "Ashmore and Cartier Islands", cm.territory[0] 
    assert( country_masters(:uk_master).iso3166_remark.is_a? Hash )
    assert_equal "BS 6879", country_masters(:uk_master).iso3166_remark["part2"][0,7]
  end

  test "create_child_country" do
    cm = country_masters(:syria_master)
    assert_equal "シリア・アラブ共和国", cm.name_ja_full, "testing fixtures"
    assert_match(/^the /,     cm.name_en_full, "testing fixtures")
    assert_match(/ \(the\)$/, cm.name_en_short, "testing fixtures")
    assert_match(/ \(la\)$/,  cm.name_fr_full,  "testing fixtures")

    cntry = cm.create_child_country
    assert cntry
    refute cntry.errors.any?
    tran = cntry.best_translations["ja"]
    assert_equal cm.name_ja_full,              tran.title
    assert_equal "シリア・アラブ共和国",       tran.title
    assert_equal "シリア・アラブキョウワコク", tran.ruby

    tran = cntry.best_translations["en"]
    assert_match(/^Syrian /,  tran.title)
    assert_match(/, the$/,    tran.title)
    assert_match(/^Syria/,    tran.alt_title)
    assert_match(/, the$/,    tran.alt_title)

    tran = cntry.best_translations["fr"]
    assert_match(/^République/, tran.title)
    assert_match(/, la$/,       tran.title)

    assert_raises(ActiveRecord::RecordInvalid){  ## Iso3166 n3 code has already been taken
      ret = cm.create_child_country
    }

    ret = cm.create_child_country(check_clobber: true)  # Here, this cm (CountryMaster) doesn't know, yet, self has a Child.
    assert_equal cntry, ret, "Country with iso3166_a2_code has been already taken, but this this cm (CountryMaster) doesn't know, yet, self has a Child, so Country should be returned with its errors set, but..."
    assert ret.errors.any?
    assert cm.errors.any?

    cm.countries.reset
    ret = cm.create_child_country
    assert_nil ret, "CountryMaster already has a child, so this should be nil, but..."


    ### Another country
    cm = country_masters(:britishvirgin_master)
    assert_equal "英領バージン諸島", cm.name_ja_full, "testing fixtures"
    assert_match(/ \(British\)$/, cm.name_en_short, "testing fixtures")
    assert_match(/ \(les Îles\)$/,  cm.name_fr_full,  "testing fixtures")

    cntry = cm.create_child_country
    assert cntry
    refute cntry.errors.any?
    tran = cntry.best_translations["ja"]
    assert_equal cm.name_ja_full,              tran.title
    assert_equal "エイリョウバージンショトウ", tran.ruby

    tran = cntry.best_translations["en"]
    assert_equal cm.name_en_short,             tran.alt_title

    tran = cntry.best_translations["fr"]
    assert_match(/^Îles Vierges/,      tran.title)
    assert_match(/britanniques, les$/, tran.title)
    assert_match(/^Vierges/,           tran.alt_title)
    assert_match(/britanniques$/,      tran.alt_title)

    # French translation 1
    cm = country_masters(:angola_master)
    
    assert_equal "アンゴラ共和国", cm.name_ja_full, "testing fixtures"
    assert_match(/ \(l'\)$/,  cm.name_fr_full,  "testing fixtures")

    cntry = cm.create_child_country
    assert cntry
    refute cntry.errors.any?
    tran = cntry.best_translations["ja"]
    assert_equal cm.name_ja_full,              tran.title
    assert_equal "アンゴラキョウワコク", tran.ruby

    tran = cntry.best_translations["fr"]
    assert_equal("Angola, l'",      tran.title, "tran=#{tran.inspect}")

    # French translation 2
    cm = country_masters(:christmas_master)
    
    assert_equal "クリスマス島", cm.name_ja_full, "testing fixtures"
    assert_match(/ \(l'Île\)$/,  cm.name_fr_full,  "testing fixtures")

    cntry = cm.create_child_country
    assert cntry
    refute cntry.errors.any?

    tran = cntry.best_translations["fr"]
    assert_equal("Île Christmas, l'", tran.title, "tran=#{tran.inspect}")
    assert_equal("Christmas",         tran.alt_title, "tran=#{tran.inspect}")
  end
end

