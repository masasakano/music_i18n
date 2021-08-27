# coding: utf-8

# == Schema Information
#
# Table name: prefectures
#
#  id                                                           :bigint           not null, primary key
#  end_date                                                     :date
#  iso3166_loc_code(ISO 3166-2:JP (etc) code (JIS X 0401:1973)) :integer
#  note                                                         :text
#  orig_note(Remarks by HirMtsd)                                :text
#  start_date                                                   :date
#  created_at                                                   :datetime         not null
#  updated_at                                                   :datetime         not null
#  country_id                                                   :bigint           not null
#
# Indexes
#
#  index_prefectures_on_country_id        (country_id)
#  index_prefectures_on_iso3166_loc_code  (iso3166_loc_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id) ON DELETE => cascade
#
require 'test_helper'

class PrefectureTest < ActiveSupport::TestCase
  test "has_many and belongs_to" do
    assert_equal 'MyTextJapan', prefectures(:tokyo).country.note
    assert_equal 1,             prefectures(:tokyo).places.where(note: 'MyTextTocho').size
  end

  test "unique constraint by Rails" do
    jp_orig = prefectures(:tokyo)
    assert_equal '東京都', jp_orig.orig_translation.title
    assert_raises(ActiveRecord::RecordInvalid){ Prefecture.create! } # Validation failed: Country must exist

    loc_code = 71234
    newp = Prefecture.create!(country: jp_orig.country, iso3166_loc_code: loc_code)
    assert_raises(ArgumentError){ newp.with_orig_translation(langcode: 'ja') } # title mandatory
    assert_raises(ArgumentError){ newp.with_orig_translation(title: 'abc') } # langcode mandatory
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: nil, langcode: 'ja') } # one of the 6 should be non-blank,
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: nil, langcode: 'ja', ruby: 'tekito') } # Neither title nor alt_title is significant for Translation for Prefecture
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: '東京都', langcode: 'ja') } # title="東京" (ja) already exits in Translation for Prefecture in Country
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: " 東京都\n", langcode: 'ja') } # spaces are ignored in default.

    tr = nil
    assert_nothing_raised{
      tr = newp.with_orig_translation(title: nil, alt_title: " あ", langcode: 'ja')
    } # alt_title alone is accepted as long as title is explicitly specified.
    assert_equal "あ", tr.reload.alt_title

    # New newp (so the translations belong to a different Prefecture)
    newp = Prefecture.create!(country: jp_orig.country)
    assert_raises(ActiveRecord::RecordInvalid){
      newp.with_orig_translation(title: nil, alt_title: "あ", langcode: 'ja', romaji: 'a') } # Combination of (title, alt_title) must be unique: [nil, "あ"], alt_title="あ" (ja) already exits in Translation for Prefecture in Country.

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) { # DRb::DRbRemoteError: PG::UniqueViolation => "Validation failed: Iso3166 loc code has already been taken"
      p Prefecture.create!(country: jp_orig.country, iso3166_loc_code: loc_code) }

    tmp2 = Prefecture.create!(country: jp_orig.country)
    newp2 =
      tmp2.with_orig_translation(title: nil, alt_title: "あ", langcode: 'ko') # Same words are accepted for a different language.
    assert_raises(ActiveRecord::RecordInvalid){
      tmp2.with_orig_translation(title: nil, alt_title: "あ", langcode: 'en')} # alt_title should not contain oriengal characters for "en"

    # Even if alt_title differs, the same title should not be allowed for Country's translation
    # (though it does not apply to Translation in general).
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: '東京都', alt_title: 'Dif', langcode: 'ja') }

    hstmp = { ja: [{title: '江戸城下', alt_title: 'Edo'}, {title: nil, alt_title: '東の地'}] }
    # assert_nothing_raised{
    c12 = newp.with_translations(**hstmp) #}

    t12 = c12.select_translations_regex(:alt_title, 'Edo', langcode: 'ja')[0]
    t12.title = '東京都'
    assert_raises(ActiveRecord::RecordInvalid,
                  "Update should fail, if it tries to modify the title to an existing one, but?"){
      t12.save! }

    ## Test of unique constraints of Translation
    c12.update!(note: 'new-t2')
    t12f = Translation.create!(title: '江戸城下', langcode: 'ko', translatable: c12)
    t12f.update!(note: 'updated-ko')
    c12.best_translations['ja'].update!(note: 'updated-ja')
    p22 = Prefecture.create_with_orig_translation!({country: c12.country}, translation: {title: 'some pref22', langcode: 'ja'})
    assert_raises(ActiveRecord::RecordInvalid,
                 "French translated title for Japan exists and hence it should not be allowed") {
      p p22.with_translation(title: '江戸城下', langcode: 'ko') }
  end

  test "hook after new entry" do
    newp = Prefecture.new(country: countries(:japan))
    newp.save!
    assert_raises(ArgumentError){               newp.with_orig_translation() }
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(langcode: 'en', title: '') }  # One of the columns must be non-blank.
    newp.reload
    assert_equal 'Catalonia', newp.with_orig_translation(langcode: 'en', title: 'Catalonia').orig_translation.title
    place_trans = newp.places[0].orig_translation
    assert_equal 'UnknownPlace', place_trans.title
    assert_equal 'en',           place_trans.langcode
    assert                       place_trans.original?
    assert_equal 0,              place_trans.weight

    newp = Prefecture.new(country: countries(:japan))
    newp.save!
    assert_raises(ArgumentError){               newp.with_orig_translation() }
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(langcode: 'en', title: '') }  # One of the columns must be non-blank.
    newp.reload
    assert_equal '高知', newp.with_orig_translation(langcode: 'ja', title: '高知').orig_translation.title
    place_trans = newp.places[0].orig_translation
    assert_equal 'どこかの場所', place_trans.title
    assert_equal 'ja',           place_trans.langcode
    assert                       place_trans.original?
    assert_equal 0,              place_trans.weight

    ## Test of unknown
    plau0 = Prefecture.unknown
    assert_equal Prefecture::UnknownPrefecture['en'], plau0.title
    assert plau0.unknown?
    plauj = Prefecture.unknown(country: 'JPN')
    assert_equal Prefecture::UnknownPrefecture['en'], plauj.title(langcode: 'en')
    assert plauj.unknown?
    assert_not_equal plau0, plauj
    assert_equal 0, plau0.best_translations['en'].weight
    assert_equal 0, plau0.best_translations['ja'].weight

    ## encompass? covered_by? ##########
    cnt_unk = Country.unknown
    jp_orig = countries(:japan)

    pref_wor = prefectures(:unknown_prefecture_world)
    pref_unj = prefectures(:unknown_prefecture_japan)
    pref_tok = prefectures(:tokyo)
    pref_uku = prefectures(:unknown_prefecture_uk)

    plac_unk = places(:unknown_place_unknown_prefecture_world)
    plac_unj = places(:unknown_place_unknown_prefecture_japan)
    plac_uuk = places(:unknown_place_unknown_prefecture_uk)
    plac_tok = places(:unknown_place_tokyo_japan)
    plac_toc = places(:tocho)
    plac_pek = places(:perth_uk)

    assert_not pref_wor.encompass?(cnt_unk)
    assert_not pref_wor.encompass?(jp_orig)
    assert     pref_wor.encompass?(pref_wor)
    assert_not pref_wor.encompass_strictly?(pref_wor)
    assert_not pref_wor.coarser_than?(      pref_wor)
    assert     pref_wor.encompass?(plac_unk)
    assert     pref_wor.encompass?(plac_unj)
    assert     pref_wor.encompass?(plac_tok)
    assert     pref_wor.encompass?(plac_pek)

    assert     pref_wor.covered_by?(cnt_unk)
    assert     pref_wor.covered_by_permissively?(pref_wor)
    assert_not pref_wor.covered_by?(pref_wor)
    assert_not pref_wor.covered_by?(jp_orig)  # PrefectureInWorld should not be covered by Japan
    assert     pref_wor.covered_by_permissively?(jp_orig)
    assert     pref_wor.covered_by_permissively?(Country.unknown)

    assert     pref_tok.covered_by_permissively?(jp_orig)
    assert     pref_tok.covered_by_permissively?(Country.unknown)
    assert     pref_tok.covered_by_permissively?(pref_wor)
    assert     pref_tok.covered_by_permissively?(pref_unj)
    assert_not pref_tok.covered_by_permissively?(pref_uku)
    assert     pref_tok.covered_by_permissively?(plac_unj) # Unknown Place in Tokyo is equivalent to Prefecture Tokyo
    assert     pref_tok.covered_by_permissively?(plac_tok)
    assert_not pref_tok.covered_by_permissively?(plac_toc)

    #assert_not pref_wor.covered_by?(pref_unj)
    #assert_not pref_wor.covered_by?(pref_tok)
    #assert_not pref_wor.covered_by?(plac_unk)
    #assert_not pref_wor.covered_by_permissively?(plac_unk)
    #assert_not pref_wor.covered_by?(plac_unj)
    #assert_not pref_wor.covered_by?(plac_tok)
    #assert_not pref_wor.covered_by?(plac_pek)
  end

  test "brackets" do
    assert_equal 'Tokyo',  Prefecture[13, Country[392]].title(langcode: 'en')
    assert_equal 13,       Prefecture[13, 'naiyo', Country[392]].iso3166_loc_code
    assert_equal 'Tokyo',  Prefecture['東京都', Country[392]].title(langcode: 'en')
    assert_equal 'Tokyo',  Prefecture[/Tokyo/, 'en', Country['JPN']].title(langcode: 'en')
    assert_equal 'Kagawa', Prefecture['Kagawa', 'en', true, Country[392]].alt_title(langcode: 'en')
    assert_nil             Prefecture['Kagawa', 'en', Country[392]] # b/c "Kagawa"(en) is alt_title
    assert_equal 37,       Prefecture[/香川/, Country[392]].iso3166_loc_code
    assert_nil             Prefecture['香川', Country[392]] # b/c title="香川県"
  end
end
