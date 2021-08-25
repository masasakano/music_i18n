# coding: utf-8

# == Schema Information
#
# Table name: places
#
#  id            :bigint           not null, primary key
#  note          :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  prefecture_id :bigint           not null
#
# Indexes
#
#  index_places_on_prefecture_id  (prefecture_id)
#
# Foreign Keys
#
#  fk_rails_...  (prefecture_id => prefectures.id) ON DELETE => cascade
#
require 'test_helper'

class PlaceTest < ActiveSupport::TestCase
  test "unique constraint by Rails" do
    jp_orig = places(:shinagawa_station)
    tocho = places(:tocho)
    assert_not Place.create.valid?  # Validation failed: Prefecture must exist
    newp = Place.create!(prefecture: jp_orig.prefecture)

    assert_raises(ArgumentError){ newp.with_orig_translation(langcode: 'ja') } # title mandatory
    assert_raises(ArgumentError){ newp.with_orig_translation(title: 'abc') } # langcode mandatory
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: nil, langcode: 'ja') } # one of the 6 should be non-blank,
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: nil, langcode: 'ja', ruby: 'tekito') } # Neither title nor alt_title is significant for Translation for Place
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: '品川駅', langcode: 'ja') } # title="品川駅" (ja) already exits in Translation for Place
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: " 品川駅\n", langcode: 'ja') } # spaces are ignored in default.
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: ' 品川駅', alt_title: 'え', langcode: 'ja') }  # even alt_title differ, main title matters.

    tr = nil
    assert_nothing_raised{
      tr = newp.with_orig_translation(title: nil, alt_title: " あ", langcode: 'ja')
    } # alt_title alone is accepted as long as title is explicitly specified.
    assert_equal "あ", tr.reload.alt_title

    # New newp (so the translations belong to a different Place
    newp = Place.create!(prefecture: jp_orig.prefecture)
    #assert_raises(ActiveRecord::RecordInvalid){ Place.create!().with_orig_translation(title: nil, alt_title: '都庁', langcode: 'ja') }
    assert_raises(ActiveRecord::RecordInvalid){
      newp.with_orig_translation(title: nil, alt_title: "あ", langcode: 'ja', romaji: 'a') } # Combination of (title, alt_title) must be unique: [nil, "あ"], alt_title="あ" (ja) already exits in Translation for Place in Prefecture.

    tmp2 = Place.create!(prefecture: jp_orig.prefecture)
    newp2 =
      tmp2.with_orig_translation(title: nil, alt_title: "あ", langcode: 'ko') # Same words are accepted for a different language.
    assert_raises(ActiveRecord::RecordInvalid){
      tmp2.with_orig_translation(title: nil, alt_title: "あ", langcode: 'en')} # alt_title should not contain oriengal characters for "en"

    # Even if alt_title differs, the same title should not be allowed for Prefecture's translation
    # (though it does not apply to Translation in general).
    assert_raises(ActiveRecord::RecordInvalid){ newp.with_orig_translation(title: '品川駅', alt_title: 'Dif', langcode: 'ja') }

    hstmp = { ja: [{title: '江戸城下', alt_title: 'Edo'}, {title: nil, alt_title: '東の地'}] }
    # assert_nothing_raised{
    c12 = newp.with_translations(**hstmp) #}

    t12 = c12.select_translations_regex(:alt_title, 'Edo', langcode: 'ja')[0]
    t12.title = '品川駅'
    assert_raises(ActiveRecord::RecordInvalid,
                  "Update should fail, if it tries to modify the title to an existing one, but?"){
      t12.save! }

    ## Test of unique constraints of Translation
    c12.update!(note: 'new-t2')
    t12f = Translation.create!(title: '江戸城下', langcode: 'ko', translatable: c12)
    t12f.update!(note: 'updated-ko')
    c12.best_translations['ja'].update!(note: 'updated-ja')
    p22 = Place.create_with_orig_translation!({prefecture: c12.prefecture}, translation: {title: 'some plac22', langcode: 'ja'})
    assert_raises(ActiveRecord::RecordInvalid,
                 "Korean translated title for Japan exists and hence it should not be allowed") {
      p p22.with_translation(title: '江戸城下', langcode: 'ko') }
    p22.with_translation(title: 'sous edo', langcode: 'ko')

    ## Test of unknown
    plau0 = Place.unknown
    assert_equal Place::UnknownPlace['en'], plau0.title
    assert plau0.unknown?

    ## Test of unknown
    plau0 = Place.unknown
    assert_equal Place::UnknownPlace['en'], plau0.title
    assert plau0.unknown?
    plauj = Place.unknown(country: 'JPN')
    assert_equal Place::UnknownPlace['en'], plauj.title(langcode: 'en')
    assert plauj.unknown?
    assert_not_equal plau0, plauj

    assert_equal places(:unknown_place_kagawa_japan), Place.unknown(prefecture: Prefecture['香川県', Country['JPN']])

    ## encompass? covered_by? ##########
    cnt_unk = Country.unknown
    jp_orig = countries(:japan)

    pref_wor = prefectures(:unknown_prefecture_world)
    pref_unk = prefectures(:unknown_prefecture_japan)
    pref_tok = prefectures(:tokyo)
    pref_uku = prefectures(:unknown_prefecture_uk)

    plac_unk = places(:unknown_place_unknown_prefecture_world)
    plac_unj = places(:unknown_place_unknown_prefecture_japan)
    plac_uuk = places(:unknown_place_unknown_prefecture_uk)
    plac_tok = places(:unknown_place_tokyo_japan)
    plac_toc = places(:tocho)
    plac_pek = places(:perth_uk)

    assert_not plac_unk.encompass?(cnt_unk)
    assert_not plac_unk.encompass?(jp_orig)
    assert_not plac_unk.encompass?(pref_unk)
    assert     plac_unk.encompass?(plac_unk)
    assert_not plac_unk.encompass_strictly?(plac_unk)
    assert_not plac_unk.coarser_than?(plac_unk)
    assert     plac_unk.encompass?(plac_unj)
    assert     plac_unk.encompass?(plac_tok)
    assert     plac_unk.encompass?(plac_pek)

    assert     plac_unk.covered_by?(cnt_unk)
    assert_not plac_unk.covered_by?(jp_orig)
#p plac_unk
    assert     plac_unk.covered_by?(pref_wor)
    #assert_not plac_unk.covered_by?(pref_unk)
    #assert_not plac_unk.covered_by?(pref_tok)
    #assert_not plac_unk.covered_by?(plac_unk)
    #assert_not plac_unk.covered_by_permissively?(plac_unk)
    #assert_not plac_unk.covered_by?(plac_unj)
    #assert_not plac_unk.covered_by?(plac_tok)
    #assert_not plac_unk.covered_by?(plac_pek)

  end

  test "title_or_alt_ascendants" do
    pla1 = places(:takamatsu_station)
    assert_equal ['高松駅', '香川県', '日本'], pla1.title_or_alt_ascendants
    assert_equal ['高松駅', '香川県', '日本'], pla1.title_or_alt_ascendants(langcode: 'ja')
    assert_equal ['高松駅', 'Kagawa', 'Japan'], pla1.title_or_alt_ascendants(langcode: 'en')
    assert_equal ['',       'Kagawa', 'Japan'], pla1.title_or_alt_ascendants(langcode: 'en', lang_fallback_option: :never)
  end

  test "brackets" do
    assert_equal '都庁', Place[/都庁/, 'ja', true, Prefecture[13, Country[392]]].alt_title  # => '都庁'(alt_title) in Tokyo(iso3166_loc_code: 13)
    assert_equal 'タカマツエキ', Place[/高松駅/, Country['JPN']].ruby(langcode: 'ja') # => 高松駅 in 香川県(iso3166_loc_code: 37) providing there is no other (if there is another '高松駅', this may return an unexpected {Place}).
  end

  test "not_disagree?" do
    pref_liverpool = prefectures( :liverpool )
    unknown_place_liverpool_uk = places( :unknown_place_liverpool_uk )
    liverpool_street = places( :liverpool_street )
    perth_uk = places(:perth_uk)
    unknown_prefecture_uk = prefectures( :unknown_prefecture_uk )
    perth_aus = places(:perth_aus)

    place = perth_uk
    assert_raises(TypeError){ place.not_disagree?(3) }
    assert     place.not_disagree?(nil)
    assert_not place.not_disagree?(nil, allow_nil: false)

    assert     place.not_disagree?(Country.unknown)     ########## WARN: This should succeed!
    assert     place.not_disagree?(Prefecture.unknown)
    assert     place.not_disagree?(Country['GBR'])
    assert     place.not_disagree?(unknown_prefecture_uk)
    assert     place.not_disagree?(place)
    assert_not place.not_disagree?(liverpool_street)
    assert_not place.not_disagree?(perth_aus)

    assert_not places(:perth_aus).not_disagree?(places(:unknown_place_tokyo_japan))
    assert_not places(:unknown_place_tokyo_japan).not_disagree?(places(:perth_aus))

    unk_japan = places(:unknown_place_unknown_prefecture_japan)
    perth_aus = places(:perth_aus)
    assert_not unk_japan.prefecture.encompass?(perth_aus)
    assert_not unk_japan.encompass?(perth_aus)
    assert_not unk_japan.not_disagree?(perth_aus)
  end

end

