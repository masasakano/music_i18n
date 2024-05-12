# coding: utf-8

# == Schema Information
#
# Table name: countries
#
#  id                                                   :bigint           not null, primary key
#  end_date                                             :date
#  independent(Independent in ISO-3166-1)               :boolean
#  iso3166_a2_code(ISO-3166-1 Alpha 2 code, JIS X 0304) :string
#  iso3166_a3_code(ISO-3166-1 Alpha 3 code, JIS X 0304) :string
#  iso3166_n3_code(ISO-3166-1 Numeric code, JIS X 0304) :integer
#  iso3166_remark(Remarks in ISO-3166-1, 2, 3)          :text
#  note                                                 :text
#  orig_note(Remarks by HirMtsd)                        :text
#  start_date                                           :date
#  territory(Territory name in ISO-3166-1)              :text
#  created_at                                           :datetime         not null
#  updated_at                                           :datetime         not null
#  country_master_id                                    :bigint
#
# Indexes
#
#  index_countries_on_country_master_id  (country_master_id)
#  index_countries_on_iso3166_a2_code    (iso3166_a2_code) UNIQUE
#  index_countries_on_iso3166_a3_code    (iso3166_a3_code) UNIQUE
#  index_countries_on_iso3166_n3_code    (iso3166_n3_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_master_id => country_masters.id) ON DELETE => restrict
#
require 'test_helper'

class CountryTest < ActiveSupport::TestCase
  include ApplicationHelper # for suppress_ruby270_warnings()

  test "belongs_to" do
    cnt = countries(:aus)
    assert_equal cnt.iso3166_a3_code, cnt.country_master.iso3166_a3_code
  end

  test "has_many" do
    assert_equal 1, countries(:japan).prefectures.where(note: 'NoteTokyo').size
  end

  test "has_many as polymorphic" do
    assert_equal 'Japan', countries(:japan).translations.where(langcode: 'en')[0].title
  end


  test "unique constraint by Rails" do
    jp_orig = countries(:japan)
    assert_raises(ActiveRecord::RecordInvalid, 'Same-name translation is banned to add for the identical Country.'){
      jp_orig.with_translations(**({ja: {title: " 日本国\u3000\n", langcode: 'ja'}})) }

    assert_raises(ActiveRecord::RecordInvalid, 'No two countries should have the identical name...'){
      Country.create!().with_orig_translation(title: '日本国', langcode: 'ja') }

    # Even if alt_title differs, the same title should not be allowed for Country's translation
    # (though it does not apply to Translation in general).
    c1 = Country.create!().with_orig_translation(title: 'Australia', alt_title: 'Aus', langcode: 'en')
    assert_raises(ActiveRecord::RecordInvalid){ Country.create!().with_orig_translation(title: 'Australia', alt_title: 'Dif', langcode: 'en') }

    hstmp = { en: [{title: 'Aussie', alt_title: 'Aus'}], ja: {title: nil, alt_title: '豪州'} }
    # assert_nothing_raised{
    c12 = c1.with_translations(**hstmp) #}
    assert_raises(ActiveRecord::RecordInvalid, 'Should have raised "Title has already been taken".'){
        p c1.with_translations(**hstmp)}  # twice
    #suppress_ruby270_warnings{  # to suppress Ruby-2.7.0 warning "/active_record/persistence.rb:630: warning: The called method `update!' is defined here"
    c1.with_updated_translations(**hstmp)#} # twice -- successful

    t12 = c12.select_translations_regex(:alt_title, '豪州', langcode: 'ja')[0]  # not the primary language
    t12.langcode = 'en'
    t12.title = 'Australia'
    assert_raises(ActiveRecord::RecordInvalid,
                  "Update should fail, if it tries to modify the title to an existing one, but?"){
      t12.save! }

    assert_raises(ActiveRecord::RecordInvalid){
      Country.create!().with_orig_translation(title: nil, alt_title: '豪州', langcode: 'ja') }  # not the primary language, but still must fail.

    # Exception: if the titles are nil for both, then alt_title's difference is suffice to be unique.
    c2 = Country.create!().with_orig_translation(title: nil, alt_title: 'NZer', langcode: 'en')
    assert_nothing_raised{
      Country.create!().with_orig_translation(   title: nil, alt_title: 'KRea', langcode: 'en') }

    # with_orig_translation does not allow overwriting, but with_orig_updated_translation does
    assert_raises(ActiveRecord::RecordInvalid){
       p c2.with_orig_translation(title: nil, alt_title: 'NZer', langcode: 'en') }
    assert_raises(ArgumentError, 'Should be "title is mandatory"'){
       p c2.with_translation(                 alt_title: 'NZer', langcode: 'en') }
    assert_raises(ActiveRecord::RecordInvalid){
       p c2.with_translation(     title: nil, alt_title: 'NZer', langcode: 'en') }
    assert_nothing_raised{
      c2.with_orig_updated_translation(title: nil, alt_title: 'NZer', langcode: 'en') }
    assert_nothing_raised{
      c2.with_updated_translation(     title: nil, alt_title: 'NZer', langcode: 'en') }

    t2 = c2.best_translations['en']
    assert_equal 'NZer', t2.alt_title
    assert_nothing_raised{
      t2.update!(note: 'new-t2')
      Translation.create!(alt_title: 'NZer', langcode: 'fr', translatable: c2) }
  end

  test "hook after new entry 2" do
    c3 = Country[/Australia/, 'en', true]
    t3 = c3.translations_with_lang('en')[0]
    t3.romaji='oosutoraria'
    uk_title = "United Kingdom of Great Britain and Northern Ireland, the"
    t3.title = uk_title  # an existing record
    assert_not t3.valid?
    t3.title = 'Australia'  # Australia#title wasl nil (but alt_title=='Australia'). But it is allowed to add it to title in update, whereas any other Translation record for Country should be banned.
    #assert     t3.valid?
    t3.save!
  end

  test "hook after new entry" do
    newp = Country.new
    newp.save!
    assert_raises(ArgumentError){               newp.with_orig_translation() }
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(langcode: 'en', title: '') }  # One of the columns must be non-blank.
    newp.reload
    assert_equal 'Catalonia', newp.with_orig_translation(langcode: 'en', title: 'Catalonia').orig_translation.title
    prefecture_trans = newp.prefectures[0].orig_translation
    assert_equal 'UnknownPrefecture', prefecture_trans.title
    assert_equal 'en',                prefecture_trans.langcode
    assert                            prefecture_trans.original?
    assert_equal 0,                   prefecture_trans.weight

    newc = Country.new
    newc.save!
    assert_raises(ArgumentError){               newc.with_orig_translation() }
    assert_raises(ActiveRecord::RecordInvalid){ newc.with_orig_translation(langcode: 'en', title: '') }  # One of the columns must be non-blank.
    newc.reload
    country_trans = newc.with_orig_translation(langcode: 'ja', title: '高麗').orig_translation
    assert_equal '高麗', country_trans.title
    child_prefecture = newc.prefectures[0]
    prefecture_trans = child_prefecture.orig_translation
    assert_equal 'どこかの都道府県', prefecture_trans.title
    assert_equal 'ja',               prefecture_trans.langcode
    assert                           prefecture_trans.original?
    child_place = child_prefecture.places[0]
    # place_trans = child_place.orig_translation  # NOTE: I can't figure out how this differs from prefecture above...  This started to happen since the order in the definitions of Unknown languages have changed ("en" comes first; 2024-05-12).
    place_trans = child_place.best_translations[:ja]
    assert_equal 'どこかの場所',     place_trans.title
    assert_equal 'ja',               place_trans.langcode
    #assert                           place_trans.original?
    assert_equal 0,                  place_trans.weight
    assert_equal child_prefecture, newc.unknown_prefecture
    assert_equal prefectures(:unknown_prefecture_japan), countries(:japan).unknown_prefecture, "Test of unknown_prefecture where Country has more than one Prefectures"
    assert_equal Country.unknown, countries(:japan).unknown_sibling

    newc.reload
    child_prefecture.reload
    prefecture_trans.reload
    child_place.reload
    place_trans.reload

    assert_equal '高麗', Country['高麗'].title
    assert_equal '高麗', Country['高麗'].title(langcode: 'ja')
    ids = {
      country: newc.id,
      country_trans: country_trans.id,
      child_prefecture: child_prefecture.id,
      prefecture_trans: prefecture_trans.id,
      child_place: child_place.id,
      place_trans: place_trans.id,
    }

    # tests of callback (on_delete)
    pref = Prefecture.find(ids[:child_prefecture])
    assert_equal 'どこかの都道府県', pref.title, "ERROR: id = #{ids[:child_prefecture]}"
    assert_equal pref, Translation.find(ids[:prefecture_trans]).translatable

    #tr= Translation.find(ids[:prefecture_trans]);
    #print "BEFORE: Trans(Pref): type=#{tr.translatable_type}\n";  p tr
    #puts "BEF:Referred-ID(#{tr.translatable_id}) <=> old-ID(Prefecture)=#{ids[:child_prefecture]}"
    #print "BEF:Parent Prefecture: "; p tr.translatable_type.classify.constantize.find(tr.translatable_id)

    newc.destroy
    assert_nil Country['高麗']
    assert_raises(ActiveRecord::RecordNotFound){ p Country.find(    ids[:country]) }
    assert_raises(ActiveRecord::RecordNotFound){ p Prefecture.find( ids[:child_prefecture]) }
    assert_raises(ActiveRecord::RecordNotFound){ p Place.find(      ids[:child_place]) }

    assert_raises(ActiveRecord::RecordNotFound){ p Translation.find(ids[:country_trans]) }

    assert_raises(ActiveRecord::RecordNotFound){ p Translation.find(ids[:prefecture_trans]) }
    assert_raises(ActiveRecord::RecordNotFound){ p Translation.find(ids[:place_trans]) }

    assert_raises(ActiveRecord::RecordNotFound){ place_trans.reload }
    assert_raises(ActiveRecord::RecordNotFound){ child_place.reload }
    assert_raises(ActiveRecord::RecordNotFound){ prefecture_trans.reload }
    assert_raises(ActiveRecord::RecordNotFound){ child_prefecture.reload }
    
    ## Test of unknown
    plau0 = Country.unknown
    assert_equal Country::UnknownCountry['en'], plau0.title
    assert plau0.unknown?
    assert_equal 0, plau0.best_translations['en'].weight
    assert_equal 0, plau0.best_translations['ja'].weight

    ## encompass? covered_by? ##########
    con3 = countries(:japan)
    assert     plau0.encompass?(plau0)
    assert_not plau0.encompass_strictly?(plau0)
    assert_not plau0.coarser_than?(plau0)
    assert     plau0.encompass?(con3)
    assert     plau0.encompass_strictly?(con3)

    assert     con3.encompass?(con3)
    assert_not con3.encompass_strictly?(con3)
    assert_not con3.encompass?(plau0)
    assert_not con3.encompass_strictly?(plau0)

    assert_not plau0.covered_by?(plau0)
    assert     plau0.covered_by_permissively?(plau0)
    assert_not plau0.covered_by?(con3)
    assert     plau0.covered_by_permissively?(con3)

    assert_not con3.covered_by?(con3)
    assert     con3.covered_by_permissively?(con3)
    assert     con3.covered_by?(plau0)
    assert     con3.covered_by_permissively?(plau0)

    pref2 = Prefecture.second
    plac2 = Place.second
    assert     plau0.encompass?(pref2)
    assert     plau0.encompass?(plac2)
    assert_not plau0.covered_by?(pref2)
    assert_not plau0.covered_by?(plac2)

    jp_orig = countries(:japan)
    pref_unk = prefectures(:unknown_prefecture_japan)
    pref_tok = prefectures(:tokyo)
    pref_uku = prefectures(:unknown_prefecture_uk)

    plac_unk = places(:unknown_place_unknown_prefecture_world)
    plac_unj = places(:unknown_place_unknown_prefecture_japan)
    plac_uuk = places(:unknown_place_unknown_prefecture_uk)
    plac_tok = places(:unknown_place_tokyo_japan)
    plac_toc = places(:tocho)
    plac_pek = places(:perth_uk)

    assert     jp_orig.encompass?(pref_unk)
    assert     jp_orig.encompass?(plac_tok)
    assert_not jp_orig.encompass?(pref_uku)
    assert_not jp_orig.encompass_strictly?(plac_unk)
    assert_not jp_orig.encompass?(plac_unk)
    assert     jp_orig.encompass?(plac_unj)
    assert_not jp_orig.encompass?(plac_uuk)
    assert     jp_orig.encompass?(plac_tok)
    assert     jp_orig.encompass?(plac_toc)
    assert_not jp_orig.encompass?(plac_pek)

    assert_not jp_orig.covered_by?(pref_unk)
    assert_not jp_orig.covered_by?(pref_tok)
    assert_not jp_orig.covered_by?(pref_uku)
    assert_not jp_orig.covered_by?(plac_unk)
    assert_not jp_orig.covered_by?(plac_unj)
    assert_not jp_orig.covered_by?(plac_uuk)
    assert_not jp_orig.covered_by?(plac_tok)
    assert_not jp_orig.covered_by?(plac_toc)
    assert_not jp_orig.covered_by?(plac_pek)
  end

  test "Country.modify_masters_trans" do
    hsin = {
      fr: {title: "France (la)"},
      en: {title: "Kingdom of Spain, the", alt_title: "United Kingdom of Great Britain and Northern Ireland (the)"},
    }
    hsexp = {
      fr: {title: "France, la"},
      en: {title: "Kingdom of Spain, the", alt_title: "UK"},
    }
    assert_equal hsexp, Country.modify_masters_trans(hsin)
  end
end

