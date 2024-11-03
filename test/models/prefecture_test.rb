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

    liverpool = prefectures(:liverpool)
    liverpool_st = places(:liverpool_street)
    assert_equal 0,  liverpool.musics.size

    music2 = musics(:music2)
    assert_difference('liverpool_st.musics.count', 1, "Sanity check failed in diff") do
      music2.update!(place: liverpool_st)
    end
    music2.reload
    liverpool_st.reload

    assert_equal liverpool_st, music2.place, "Sanity check failed"
    music3 = musics(:music3)
    pla3 = Place.create!(prefecture: liverpool)
    music3.update!(place: pla3)

    # tests whether it can be destoryed
    liverpool.reload
    assert_equal 3,  liverpool.places.size, "Prefecture 'Liverpool' should have 3 Places (1 was just created), but... Places="+liverpool.places.inspect
    assert_equal 1,  liverpool.places.last.musics.size
    assert_equal 2,  liverpool.musics.size, "should have 2, but... musics="+liverpool.musics.inspect # "SQL="+liverpool.musics.to_sql

    assert_raises(ActiveRecord::RecordNotDestroyed, "destroy should raise Error because Prefecture have significant places"){
      liverpool.destroy!}  # p liverpool.errors.details # p liverpool.errors.full_messages
    refute liverpool.destroyed?
    refute liverpool_st.destroyed?
    refute music2.destroyed?

    assert_raises(ActiveRecord::DeleteRestrictionError, "Should be 'Cannot delete record because of dependent musics', but...") {
      refute pla3.destroy }

    music2.destroy!  # "liverpool_st" now has no dependent Musics
    music3.update!(place: nil)
    assert pla3.destroy  # b/c music3 does not depend on it anymore.
    assert pla3.destroyed?
    assert_equal 2,  liverpool.places.size, "Prefecture 'Liverpool' should have 2 Places, but... Places="+liverpool.places.inspect
    
    #liverpool.reload
    refute liverpool.destroy, "destroy should fail because Prefecture have a significant place: places="+liverpool.places.inspect

    liverpool_st.destroy!
    assert liverpool.destroy, "destroy should succeed because Prefecture have only an unknown Place"
    assert liverpool.destroyed?
    assert liverpool_st.destroyed?
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

  test "can destroy" do
    newp = Prefecture.create!(country: countries(:aus))
    newp.with_orig_translation(title: 'NewTestDestroy', langcode: 'en')

    ## Test of destroy
    newp_id = newp.id
    assert_equal 1, newp.places.size, 'Sanity check'
    pla = Place.create!(prefecture_id: newp.id, note: 'Test new place')
    pla_id = pla.id
    assert           newp.places[0].unknown?, "Sanity check - it should be unknown: #{newp.places[0].inspect}"  # NOTE: if this sentence was placed 3 lines above, the following "assert_equal 2" would fail, perhaps because of the caching mechanism...
    pla_unknown_id = newp.places[0].id
    assert_equal 2, newp.places.size, "Sanity check: newp=#{newp.inspect}; pla=#{pla.inspect}"
    assert_raises(ActiveRecord::RecordNotDestroyed, "Should not be destoryed because significant child Places exist."){
      newp.destroy! }
    refute newp.destroy
    assert_match(/\bchild Places?\b/i, newp.errors[:base][0]) # "Destroy failed. Prefecture has significant non-unknown child Places. Delete them first."

    newp.force_destroy = true
    assert newp.destroy, "Should be successfully destoryed because #force_destroy==true"
    refute Prefecture.exists? newp_id
    #refute Place.exists? pla_unknown_id
    refute Place.exists? pla_id
    assert_raises(ActiveRecord::RecordNotFound){ #Couldn't find Place with 'id'=1040129588
      pla.reload }

    ## Test of destroy (if a significant place is gone (destroyed), Prefecture can be destroyed)
    #new2 = newp.dup  # id is not copied (Rails-3.1+)
    #new2.save!  # the following tests would not pass for some reason...
    new2 = Prefecture.create!(country: countries(:aus))
    new2_id = new2.id
    assert_equal 0, new2.places.size, 'Sanity check'
    new2.with_orig_translation(title: 'NewTestDestroy', langcode: 'en')
    assert_equal 1, new2.places.size, 'After the first translation, Place.unknown should be added.'
    pla = Place.create!(prefecture_id: new2_id, note: 'Test new place')
    assert_equal 2, new2.places.size
    refute new2.destroy, "new2=#{new2.inspect}; new2.places=#{new2.places.inspect}"
    assert_match(/\bchild Places?\b/i, new2.errors[:base][0]) # "Destroy failed. Prefecture has significant non-unknown child Places. Delete them first."
    assert_raises(ActiveRecord::RecordNotDestroyed){ new2.destroy! }
    assert pla.destroy, "Should be successfully destroyed."
    assert new2.destroy
    assert new2.destroyed?
    refute Prefecture.exists? new2_id

    ## Test of destroy with only Place.unknown (of a prefecture in Japan); This test is redundant now -- it has once made sense as Prefectures in Japan were treated differently.
    new3 = Prefecture.create!(country: countries(:japan))
    new3_id = new3.id
    new3.with_orig_translation(title: 'NewTestDestroy', langcode: 'en')
    assert_equal 1, new3.places.size, 'After the first translation, Place.unknown should be added.'
    #refute new3.destroy, "Prefecture in Japan should not be destroyed: new3=#{new3.inspect}; new3.places=#{new3.places.inspect}"
    #assert_match(/\bCountry\b.+Japan\b/i, new3.errors[:base][0]) # "Destroy failed. Prefecture is in Country (Japan)."
    assert new3.places.first.destroy, "Associated Unknwon Place should be destroyed without a trouble."
    assert new3.destroy, "Prefecture with absolutely no associated Place including unknown should be successfully destroyed."
    assert new3.destroyed?
    refute Prefecture.exists? new3_id
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
    assert_equal newp.places[0], newp.unknown_place
    assert_equal places(:unknown_place_tokyo_japan), prefectures(:tokyo).unknown_place, "Test of unknown_place where Prefecture has more than one Places"
    assert_equal prefectures(:unknown_prefecture_japan), prefectures(:tokyo).unknown_sibling

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
  end

  test "translation at save" do
    perth = "Perthshiretest"
    hsprm = {
      translatable_type: Prefecture.name,
      langcode: 'en',
      is_orig: true,
      title: perth,
    }

    new1 = Prefecture.new(country: countries(:uk))
    tra1 = Translation.preprocessed_new(**hsprm)
    new1.unsaved_translations << tra1
    assert new1.save, 'save with unsaved_translations should succeed, but.'
    assert_equal perth, new1.title(langcode: 'en')

    new2 = Prefecture.new(country: countries(:aus))
    tra2 = Translation.preprocessed_new(**hsprm)
    new2.unsaved_translations << tra2
    assert new2.save, 'save with unsaved_translations should succeed, but.'
    assert_equal perth, new2.title(langcode: 'en')

    new3 = Prefecture.new(country: countries(:uk))
    tra3 = Translation.preprocessed_new(**hsprm)
    new3.unsaved_translations << tra3
    refute new3.save, 'save with unsaved_translations should fail (same translation, same country, same language), but.'

    new3.unsaved_translations.pop
    tra4 = Translation.preprocessed_new(**(hsprm.merge({langcode: 'ja'})))
    new3.unsaved_translations << tra4
    assert new3.save, 'save with unsaved_translations should succeed (same translation, same country, but different language), but.'
    assert_equal perth, new2.title
  end

  test "encompass? and covered_by?" do
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
    assert     pref_wor.encompass?(plac_toc)
    assert     pref_wor.encompass?(plac_pek)

    assert     pref_tok.encompass?(plac_tok)
    assert     pref_tok.encompass?(plac_toc)
    assert_not pref_tok.encompass?(plac_unj)
    assert_not pref_tok.encompass?(plac_pek)

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

  test "more_significant and less_significant" do
    japan = countries(:japan)
    uk    = countries(:uk)

    tokyo = prefectures(:tokyo)
    kagawa= prefectures(:kagawa)
    greater_london  = prefectures(:greater_london )
    unknown_pref_jp = prefectures(:unknown_prefecture_japan)
    unknown_pref_uk = prefectures(:unknown_prefecture_uk)
   #unknown_pref    = prefectures(:unknown_prefecture_world)  # == Prefecture.unknown

    tocho = places(:tocho)
    takamatsu_st = places(:takamatsu_station)
    unknown_pla_tokyo  = places(:unknown_place_tokyo_japan)
    unknown_pla_kagawa = places(:unknown_place_kagawa_japan)
    unknown_pla_jp     = places(:unknown_place_unknown_prefecture_japan)
    unknown_pla_uk     = places(:unknown_place_unknown_prefecture_uk)
    unknown_pla_london = places(:unknown_place_greater_london)
   #unknown_pla        = places(:unknown_place_unknown_prefecture_world)  # == Place.unknown

    ## Prefecture <=> Prefecture
    refute tokyo.more_significant_than?( tokyo )
    refute tokyo.more_significant_than?( kagawa )
    refute tokyo.more_significant_than?( greater_london )
    assert tokyo.more_significant_than?( unknown_pref_jp )
    assert tokyo.more_significant_than?( unknown_pref_uk )
    assert tokyo.more_significant_than?( Prefecture.unknown )

    refute unknown_pref_jp.more_significant_than?( tokyo )
    refute unknown_pref_jp.more_significant_than?( greater_london )
    refute unknown_pref_jp.more_significant_than?( unknown_pref_jp )
    refute unknown_pref_jp.more_significant_than?( unknown_pref_uk )
    assert unknown_pref_jp.more_significant_than?( Prefecture.unknown )

    assert unknown_pref_jp.less_significant_than?( tokyo )
    assert unknown_pref_jp.less_significant_than?( greater_london )
    refute unknown_pref_jp.less_significant_than?( unknown_pref_jp )
    refute unknown_pref_jp.less_significant_than?( unknown_pref_uk )
    refute unknown_pref_jp.less_significant_than?( Prefecture.unknown )

    refute Prefecture.unknown.more_significant_than?( tokyo )
    refute Prefecture.unknown.more_significant_than?( unknown_pref_jp )
    refute Prefecture.unknown.more_significant_than?( Prefecture.unknown )

    ## Prefecture <=> Country
    assert tokyo.more_significant_than?(japan)
    assert tokyo.more_significant_than?(uk)
    assert tokyo.more_significant_than?(Country.unknown)

    refute unknown_pref_jp.more_significant_than?( japan )
    refute unknown_pref_jp.more_significant_than?( uk )
    assert unknown_pref_jp.more_significant_than?( Country.unknown)

    refute Prefecture.unknown.more_significant_than?( japan )
    refute Prefecture.unknown.more_significant_than?( uk )
    refute Prefecture.unknown.more_significant_than?( Country.unknown)

    ## Prefecture <=> Place
    refute tokyo.more_significant_than?(tocho )
    refute tokyo.more_significant_than?(takamatsu_st )
    refute tokyo.more_significant_than?(unknown_pla_tokyo  )
    refute tokyo.more_significant_than?(unknown_pla_kagawa )
    assert tokyo.more_significant_than?(unknown_pla_jp     )
    assert tokyo.more_significant_than?(unknown_pla_uk     )
    refute tokyo.more_significant_than?(unknown_pla_london )
    assert tokyo.more_significant_than?(Place.unknown      )

    refute unknown_pref_jp.more_significant_than?( tocho )
    refute unknown_pref_jp.more_significant_than?( takamatsu_st )
    refute unknown_pref_jp.more_significant_than?( unknown_pla_tokyo )
    refute unknown_pref_jp.more_significant_than?( unknown_pla_jp )
    refute unknown_pref_jp.more_significant_than?( unknown_pla_uk )
    assert unknown_pref_jp.more_significant_than?( Place.unknown )

    refute Prefecture.unknown.more_significant_than?( tocho )
    refute Prefecture.unknown.more_significant_than?( unknown_pla_tokyo )
    refute Prefecture.unknown.more_significant_than?( unknown_pla_jp )
    refute Prefecture.unknown.more_significant_than?( unknown_pla_uk )
    refute Prefecture.unknown.more_significant_than?( Place.unknown )

    assert Prefecture.unknown.less_significant_than?( tocho )
    assert Prefecture.unknown.less_significant_than?( unknown_pla_tokyo )
    assert Prefecture.unknown.less_significant_than?( unknown_pla_jp )
    assert Prefecture.unknown.less_significant_than?( unknown_pla_uk )
    refute Prefecture.unknown.less_significant_than?( Place.unknown )
  end

  test "title_or_alt_ascendants" do
    pla1 = places(:takamatsu_station)
    pref = pla1.prefecture
    assert_equal ['香川県', '日本国'], pref.title_or_alt_ascendants
    assert_equal ['香川県', '日本'],   pref.title_or_alt_ascendants(langcode: 'ja', prefer_shorter: true)
    assert_equal ['香川県', 'Japon'],  pref.title_or_alt_ascendants(langcode: 'fr')
    assert_equal ['',       'Japon'],  pref.title_or_alt_ascendants(langcode: 'fr', lang_fallback_option: :never)

    ar = pref.title_or_alt_ascendants(set_singleton: true)
    refute ar[0].unknown?
    refute ar[1].unknown?

    pref_unk = prefectures(:unknown_prefecture_japan)
    ar = pref_unk.title_or_alt_ascendants(set_singleton: true)
    assert pref_unk.unknown?
    assert ar[0].unknown?
    refute ar[1].unknown?

    pref_unk = prefectures(:unknown_prefecture_world)
    ar = pref_unk.title_or_alt_ascendants(set_singleton: true)
    assert ar[0].unknown?
    assert ar[1].unknown?

    ar = pref_unk.title_or_alt_ascendants(set_singleton: false)
    refute ar[0].respond_to?(:unknown?)
    refute ar[1].respond_to?(:unknown?)
  end

  test "mname related" do
    pref_london = Prefecture[/\bLondon\b/]
    assert_equal Country["GBR"], pref_london.country, 'sanity check'
    assert_equal "london", pref_london.mname_to_s
    pref_confusing = Prefecture.create_basic!(title: "London", langcode: "en", is_orig: true, country: Country["AUS"])
    assert_includes Prefecture.select_regex(:title, /\bLondon\b/), pref_confusing, 'sanity check'
    assert_equal 2, Prefecture.select_regex(:title, /\bLondon\b/).size, 'sanity check (of fixtures)'
    assert_equal pref_london, (pref=Prefecture.find_by_mname(:london)), 'This should always be "Greater London" in the UK (GBR), but...'+pref.inspect
    assert_equal Prefecture[/\bParis\b/], Prefecture.find_by_mname(:paris)
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
