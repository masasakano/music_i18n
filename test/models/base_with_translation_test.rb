# coding: utf-8
require 'test_helper'

class BaseWithTranslationTest < ActiveSupport::TestCase
  include ApplicationHelper # for suppress_ruby270_warnings()

  test "title aka the private method get_a_title" do
    # Gets Music with some translations with "title" for the original-language but no French translation
    music = nil
    Music.all.each do |mu|
      lcs = mu.translations.pluck(:langcode)
      next if lcs.empty? || lcs.include?("fr")
      tran = mu.orig_translation
      next if tran.blank? || tran.title.blank?
      music = mu
      break
    end
    raise "should found one at least." if !music

    assert_nil music.title(langcode: "fr", lang_fallback: false, str_fallback: nil)
    assert_nil music.title(langcode: "fr", lang_fallback: false)  # Default for lang_fallback
    assert     music.title(langcode: "fr", lang_fallback: true)
    assert_equal "Nothing", music.title(langcode: "fr", lang_fallback: false, str_fallback: "Nothing")
    assert_equal "Nothing", music.title(langcode: "fr",                       str_fallback: "Nothing")

    # {#titles} are separately implemented.
    assert_empty music.titles(langcode: "fr", lang_fallback_option: :never, str_fallback: nil).compact
    assert_empty music.titles(langcode: "fr", lang_fallback_option: :never).compact  # Default for lang_fallback
    refute_empty music.titles(langcode: "fr", lang_fallback_option: :either).compact
    assert_equal "Nothing", music.titles(langcode: "fr", lang_fallback_option: :never, str_fallback: "Nothing")[1]
    assert_equal "Nothing", music.titles(langcode: "fr",                               str_fallback: "Nothing")[1]
    assert_equal "Nothing", music.title_or_alt(langcode: "fr", lang_fallback_option: :never, str_fallback: "Nothing")
    refute_equal "Nothing", music.title_or_alt(langcode: "fr",                               str_fallback: "Nothing"), "Default lang_fallback_option for title_or_alt is :either. as oppposed to :never in titles, and hence this should find matched title/alt_title, I think, but it failed..." 
  end

  # Using the subclass Sex
  test "select_regex and [] in BaseWithTranslation" do
    ar = Sex.select_regex(:title,  'male')
    assert_equal 1, ar.size
    assert_equal 1, ar[0].iso5218
    ar = Sex.select_regex('title', 'male')
    assert_equal 1, ar.size
    assert_equal 1, ar[0].iso5218

    ar = Sex.select_regex(:titles, /n/)
    assert_equal 2, ar.size
    assert_equal [0, 9], ar.map(&:iso5218).sort  ### NOTE: It has to be sorted!
    ar = Sex.select_regex(:titles, /n/, langcode: 'ja')
    assert_equal 0, ar.size
    ar = Sex.select_regex(:titles, /n/, langcode: 'en')  # "not known", "not applicable"
    assert_equal 2, ar.size
    assert_equal [0, 9], ar.map(&:iso5218).sort

    ar = Sex.select_regex(%i(title ruby romaji), /n/)
    assert_equal 3, ar.size
    assert_equal [0, 2, 9], ar.map(&:iso5218).sort
    ar = Sex.select_regex(%i(title ruby romaji), /n/, langcode: 'ja') # (romaji)     "onna", "tekiyoufunou"
    assert_equal 2, ar.size
    assert_equal [   2, 9], ar.map(&:iso5218).sort
    ar = Sex.select_regex(%i(title ruby romaji), /n/, langcode: 'en') # (title) "not known", "not applicable"
    assert_equal 2, ar.size
    assert_equal [0,    9], ar.map(&:iso5218).sort

    ## find_by_regex => nil
    sex = Sex.find_by_regex(%i(title ruby romaji), 'naiyo'*5, langcode: 'en')
    assert_nil sex

    ## find_by_regex
    sex = Sex.find_by_regex(%i(title ruby romaji), /n/, langcode: 'en') # (title) "not known", "not applicable"
    assert_equal 0, sex.iso5218
    assert_equal 'not known', sex.matched_string

    ## select_regex
    sex = Sex.select_regex(%i(title ruby romaji), /n/, langcode: 'en').first # (title) "not known", "not applicable"
    assert_equal 0, sex.iso5218
    assert_equal 'not known', sex.matched_string(%i(title ruby romaji), /n/, langcode: 'en')
    sex.set_matched_trans_att(%i(title ruby romaji), /n/, langcode: 'en')
    assert_equal 'not known', sex.matched_string

    ar = Sex.select_regex(:all, /n/)
    assert_equal 3, ar.size
    assert_equal [0, 2, 9], ar.map(&:iso5218).sort

    # Tests of self.[]
    assert_equal 2, Sex['female'].iso5218
    assert_equal 2, Sex['female', 'en'].iso5218
    assert_equal 2, Sex['fｅmale', 'en'].iso5218 # zenkaku
    assert_nil      Sex['female', 'ja']
    assert_nil      Sex['female', 'pt']

    # Tests of self.[nil]
    rel = Sex.find_all_without_translations
    assert_equal 0, rel.count
    assert_nil      Sex[nil]
    assert_nil      Sex[]
    sc = Sex.create!(iso5218: 47)
    assert_equal sc, Sex[]
    rel = Sex.find_all_without_translations
    assert_equal 1,  rel.count
    assert_equal sc, rel.first
  end

  test "class and instance methods of find_by_a_title" do
    artist = artists( :artist_proclaimers )
    art = Artist.find_by_a_title :titles, 'proclaimers'
    assert_equal artist.best_translations['en'], art.matched_translation
    assert_equal artist.best_translations[:en], art.matched_translation  # .with_indifferent_access activated (after v.0.6)
    assert_equal :title,   art.matched_attribute
    assert_equal artist.best_translations['en'].title, art.matched_string
    assert_equal :optional_article_ilike, art.match_method

    amm = [:exact, :exact_ilike]
    art = Artist.find_by_a_title :titles, 'proclaimers', accept_match_methods: amm
    assert_nil art

    art = Artist.find_by_a_title :titles, 'proclaimers', accept_match_methods: (amm << :include << :include_ilike)
    assert_operator art.title.size, '>', 10
    assert_equal :include_ilike, art.match_method

    tra = artist.find_translation_by_a_title(:titles, 'proclaimers')
    assert_equal artist.best_translations['en'], tra
    assert_equal tra.title, tra.matched_string
  end

  # Using the subclass Sex and Country
  test "create_with_translation!" do
    n_orig_sex   = Sex.count
    n_orig_trans = Translation.count
    s1name = 'f1'

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){ # "Validation failed: Iso5218 can't be blank"
      p Sex.create_with_orig_translation!(iso5218: 81, translation: {title: s1name, langcode: 'ja'}) }

    s1 = Sex.create_with_orig_translation!({iso5218: 81}, translation: {title: s1name, langcode: 'ja'})
    assert_equal n_orig_sex+1,   Sex.count
    assert_equal n_orig_trans+1, Translation.count
    trans = s1.translations
    assert_equal 1,      trans.size
    assert_equal 'ja',   trans[0].langcode
    assert_equal s1name, trans[0].title
    assert               trans[0].is_orig

    s2name = s1name+'2'
    s2 = Sex.create_with_translation!({iso5218: 82}, translation: {title: s2name, langcode: 'ja'})
    assert_equal n_orig_sex+2,   Sex.count
    assert_equal n_orig_trans+2, Translation.count
    trans = s2.translations
    assert_equal 1,      trans.size
    assert_equal 'ja',   trans[0].langcode
    assert_equal s2name, trans[0].title
    assert_not           trans[0].is_orig

    s3namej= s1name='3'
    s3name = 'en3'
    s3 = Sex.create_with_translations!({iso5218: 83}, {trim: true}, translations: {ja: {title: s3namej}, en: [{title: s3name, is_orig: true}]})
    assert_equal n_orig_sex+3,   Sex.count
    assert_equal n_orig_trans+4, Translation.count
    trans = s3.translations
    assert_equal 2,      trans.size
    bests = s3.best_translations
    assert_equal 'ja',   bests['ja'].langcode
    assert_equal s3namej,bests['ja'].title
    assert_not           bests['ja'].is_orig
    assert_equal 'en',   bests['en'].langcode
    assert_equal s3name, bests['en'].title
    assert               bests['en'].is_orig
    assert_equal s3.best_translation('ja'), bests['ja']
    assert_equal s3.best_translation('en'), bests['en']
    assert_equal s3.best_translation(),     bests['en']  # is_orig == true
    assert_equal s3.best_translation(:all), bests['en']
    assert_equal s3.best_translation('kr'), bests['en']
    assert_nil   s3.best_translation('kr', fallback: false)
    assert_equal s3.best_translation('kr', fallback: ['ja']), bests['ja']

    ## Error testing
    s4name = 'f4'
    assert_raises(ActiveRecord::RecordInvalid){
      p Sex.create_with_orig_translation!({iso5218: 83}, translation: {title: s4name, langcode: 'ja'}) } # Validation failed: Iso5218 has already been taken
    assert_raises(ArgumentError){
      p Sex.create_with_orig_translation!({iso5218: 84}, translation: {title: s4name}) } # (create_translation!) langcode is mandatory but is unspecified.
    begin 
      p Sex.create_with_orig_translation!({iso5218: 84}, translation: {title: s4name})
    rescue ArgumentError
      # No Sex objects should have been created, thanks to DB rollback!
      assert_equal n_orig_sex+3,   Sex.count
      assert_equal n_orig_trans+4, Translation.count
    end

    ## Translation creations
    s5name = s1name='5'
    c5name = 'en5'
    n_orig_cnt = Country.count
    n_orig_pre = Prefecture.count
    n_orig_pla = Place.count
    c5 = Country.create_with_translations!({note: 'random'}, {trim: true}, translations: {ja: {title: s5name}, en: [{title: c5name, is_orig: true}]})
    c5trans = c5.best_translations
    assert_equal s5name, c5trans['ja'].title
    assert_not           c5trans['ja'].is_orig
    assert_equal c5name, c5trans['en'].title
    assert               c5trans['en'].is_orig

    assert_equal n_orig_cnt+1, Country.count
    assert_equal n_orig_pre+1, Prefecture.count
    assert_equal n_orig_pla+1, Place.count
    assert_equal n_orig_trans+4+3*3-1, Translation.count # for [ja,en] for Country and 3 languages each for Prefecture, Place

    pref_en = Prefecture.select_translations_regex(:title, Prefecture::UnknownPrefecture['en'], langcode: 'en', note: 'UnknownPrefectureUkEn')[0] # Translation of Prefecture
    assert_equal Prefecture::UnknownPrefecture['en'], pref_en.title
    assert               pref_en.is_orig
    pref_ja = Prefecture.select_translations_regex(:title, Prefecture::UnknownPrefecture['ja'], langcode: 'ja')[0]
    assert_equal Prefecture::UnknownPrefecture['ja'], pref_ja.title
    assert_not           pref_ja.is_orig
    pref_fr = Prefecture.select_translations_regex(:title, Prefecture::UnknownPrefecture['fr'], langcode: 'fr')[0]
    assert_equal Prefecture::UnknownPrefecture['fr'], pref_fr.title
    assert_not           pref_fr.is_orig

    plac_en = Place.select_translations_regex(:title, Place::UnknownPlace['en'], langcode: 'en', note: 'UnknownPlaceUnknownPrefectureUkEn')[0] # Translation of Place
    assert_equal Place::UnknownPlace['en'], plac_en.title
    assert               plac_en.is_orig
    plac_ja = Place.select_translations_regex(:title, Place::UnknownPlace['ja'], langcode: 'ja')[0]
    assert_equal Place::UnknownPlace['ja'], plac_ja.title
    assert_not           plac_ja.is_orig
    plac_fr = Place.select_translations_regex(:title, Place::UnknownPlace['fr'], langcode: 'fr')[0]
    assert_equal Place::UnknownPlace['fr'], plac_fr.title
    assert_not           plac_fr.is_orig
  end

  # Checking the way to handle (extra) spaces, including multibyte ones. Using the subclass Country.
  test "handle spaces" do
    jp_orig = countries(:japan)

    hsopt = {
      #convert_spaces: true,
      #convert_blanks: true,
      #strip: true,
      #trim:  true,
    }
    hsopt_false = {
      convert_spaces: false,
      convert_blanks: false,
      strip: false,
      trim:  false,
    }

    ar = []

    assert_raises(ActiveRecord::RecordInvalid){  # Default
      ar = jp_orig.create_translations!(**({ja: {title: "日本国", langcode: 'ja'}})) }

    # Trailing spaces are insignificant in default, but specified as significant in this case.
    assert_nothing_raised(){
      ar = jp_orig.create_translations!(hsopt_false, **{ja: {title: " 日本国\n", langcode: 'ja'}}) }
    tr2s = jp_orig.update_or_create_translations!(hsopt_false, **{ja: {title: " 日本国\n", langcode: 'ja', note: 'tr02note'}})
    tr2s = jp_orig.update_or_create_translations!(hsopt_false, **{ja: {title: " 日本国\n", langcode: 'ja', note: 'tr02note'}}) # twice
    assert_equal ar[0].id,   tr2s[0].id
    assert_equal 'tr02note', tr2s[0].note
    ar[0].destroy
    tr2s[0].destroy

    assert_raises(ActiveRecord::RecordInvalid){  # Default
      ar = jp_orig.create_translations!(hsopt_false.merge({strip: true}), **{ja: {title: " 日本国\n", langcode: 'ja'}}) }

    assert_nothing_raised{                       # Japanese zenkaku space
      ar = jp_orig.create_translations!(hsopt_false.merge({strip: true}), **{ja: {title: " 日本国"+"\u3000"*3, langcode: 'ja'}}) }
    ar[0].destroy

    assert_raises(ActiveRecord::RecordInvalid){  # Japanese zenkaku space converted
      ar = jp_orig.create_translations!(hsopt_false.merge({strip: true, convert_blanks: true}), **{ja: {title: " 日本国"+"\u3000"*3, langcode: 'ja'}}) }

    # Registers one with a space in the middle to the translation set.
      _  = jp_orig.create_translations!(hsopt_false, **{ja: {title: "日 本国", langcode: 'ja'}})

    assert_raises(ActiveRecord::RecordInvalid){  # trim
      ar = jp_orig.create_translations!(hsopt_false.merge({trim: true}), **{ja: {title: "日  本国", langcode: 'ja'}}) }

    assert_nothing_raised{  # Japanese zenkaku space is regarded significant
      ar = jp_orig.create_translations!(hsopt_false.merge({trim: true, convert_blanks: false, truncate_blanks: false}), **{ja: {title: "日 "+"\u3000"*3+" 本国", langcode: 'ja'}}) }
    ar[0].destroy

    assert_raises(ActiveRecord::RecordInvalid){  # Japanese zenkaku space converted in default
      ar = jp_orig.create_translations!(hsopt_false.merge({trim: true}), **{ja: {title: "日 "+"\u3000"*3+" 本国", langcode: 'ja'}}) }

    assert_nothing_raised{  # \n is significant
      ar = jp_orig.create_translations!(hsopt_false.merge({trim: true, convert_blanks: false, truncate_blanks: false}), **{ja: {title: "日 \n"+"\u3000"*3+" 本国", langcode: 'ja'}}) }
    ar[0].destroy

    assert_raises(ActiveRecord::RecordInvalid){  # \n and Japanese zenkaku space converted
      ar = jp_orig.create_translations!(hsopt_false.merge({trim: true, convert_spaces: true}), **{ja: {title: "日 \n"+"\u3000"*3+" 本国", langcode: 'ja'}}) }

    assert_raises(ActiveRecord::RecordInvalid){  # Reproduces Default
      ar = jp_orig.create_translations!(hsopt, **{ja: {title: "日 \n"+"\u3000"*3+" 本国\n\n", langcode: 'ja'}}) }

    assert_raises(ActiveRecord::RecordInvalid){  # Default (convert_spaces (hence, blanks), truncate_spaces, strip, trim)
      ar = jp_orig.create_translation!( title: "\u3000 \n日 \n"+"\u3000"*3+" 本国\n\n", langcode: 'ja') }
  end

  test "update_or_create_ ..." do
    cj = countries(:japan)
    tj = translations(:japan_ja)
    assert_raises(ActiveRecord::RecordInvalid){  # Unique constraint
      p  Country.create_with_orig_translation!({note: 'n1'}, translation: {title: tj.title, langcode: 'ja'}) }

    # update_or, create
    tr1 = {title: 'Random A1', langcode: 'en'}
    a1 = Country.update_or_create_with_orig_translation!({note: 'n0'}, translation: tr1.merge({note: 't0'}))
    atmp = a1.best_translations['en']
    assert       atmp.is_orig, "message: Translations="+a1.translations.inspect
    assert_equal 'Random A1', atmp.title
    assert_equal 'n0',        a1.note
    assert_equal 't0',        atmp.note, "message: Translation(en)="+atmp.inspect

    assert_raises(ActiveRecord::RecordInvalid){  # Unique constraint
      p  Country.create_with_orig_translation!(          {note: 'n1'}, translation: tr1) }
    assert_nothing_raised{
         Country.update_or_create_with_translation!(     {note: 'n1'}, translation: tr1.merge({is_orig: false})) }
    assert_nothing_raised{
         Country.update_or_create_with_orig_translation!({note: 'n1'}, translation: tr1) }
    atmp = a1.best_translations['en']
    assert       atmp.is_orig
    assert_equal 'Random A1', atmp.title
    a1.reload
    assert_equal 'n1',        a1.note
    assert_equal 't0',        atmp.note

    # plural, update
    tr2 = {ja: {title: 'ランダム-A1'}, en: tr1.merge({is_orig: true})}
    a2 = Country.update_or_create_with_translations!({note: 'n2'}, translations: tr2)

    assert_equal 'n2', a2.note
    assert_equal a1.id, a2.id  # has to be update as opposed to create
    atmp = a2.orig_translation
    assert_equal 'Random A1', atmp.title
    atmp = a2.best_translations['en']
    assert       atmp.is_orig
    assert_equal 'Random A1', atmp.title
    atmp = a2.best_translations['ja']
    assert_not   atmp.is_orig
    assert_equal 'ランダム-A1', atmp.title

    # plural, create
    tr3 = {ja: {title: 'ランダム-B3'}, en: {title: 'Random B3', is_orig: true}}
    a3 = Country.update_or_create_with_translations!({note: 'n3'}, translations: tr3)
    assert_not_equal a1.id, a3.id  # has to be create
    atmp = a3.best_translations['en']
    assert_equal 'Random B3', atmp.title

    # plural, update, restricted
    preunkaus = prefectures(:unknown_prefecture_aus)
    perth_aus = places(:perth_aus)
    perth_aus_en = translations(:perth_aus_en)
    assert_equal 'Perth', perth_aus.title
    tr4 = {en: {title: 'Perth', note: 'new perth'}}
    a4 = nil
    suppress_ruby270_warnings{  # to suppress Ruby-2.7.0 warning "/active_record/persistence.rb:630: warning: The called method `update!' is defined here"
    a4 = Place.update_or_create_with_translations!({prefecture: preunkaus}, translations: tr4) }
    assert_equal     perth_aus.id, a4.id  # Perth, Australia (not UK)
    assert_equal     'Perth',      a4.title
    a4_en = a4.best_translations['en']
    assert_not_equal perth_aus_en.note, a4_en.note
    assert_equal     'new perth',       a4_en.note, "perth_aus_en.note=#{perth_aus_en.note.inspect}, a4_en.note=#{a4_en.note.inspect}"

    # plural, create, restricted
    tr5 = {en: {title: 'new some', note: 'new note5'}}
    a5 = Place.update_or_create_with_translations!({prefecture: preunkaus}, translations: tr5)
    assert_not_equal perth_aus.id, a5.id
    assert_equal     'new some',   a5.title(langcode: "en")
    assert_equal     'new some',   a5.title  # Leave Warning in Logger b/c no is_orig is defined.
  end

  # 
  test "select_by_associated_titles" do
    inhs = {
      en: [ {title: 'T1'}, {title: 'T2', is_orig: true, langcode: 'en'} ],
      ja:   {title: 'J1'},
      any:  {titles: 'Something'}
    }
    arret = [
      {langcode: 'en', title: 'T1'},
      {langcode: 'en', title: 'T2', is_orig: true},
      {langcode: 'ja', title: 'J1'},
      {titles: 'Something'}
    ]
    assert_equal arret, BaseWithTranslation.send(:flattened_translations_hash, **inhs)

    mu_en1 = musics(:music1)
    hvs = HaramiVid.select_by_associated_titles(music_title: mu_en1.title)
    assert_equal 1, hvs.count
    assert_equal harami_vids(:harami_vid1), hvs.first

    # tests of artists, which is in (many -> many) multi-layered relation
    art_en1 = artists(:artist1)
    hvs = HaramiVid.select_by_associated_titles(artist_title: art_en1.title)
    assert_equal 1, hvs.count
    assert_equal harami_vids(:harami_vid1), hvs.first

  end

  test "orig_langcode and lc_related" do
    assert_equal 'ja', countries(:japan).orig_langcode
    assert_nil prefectures(:unknown_prefecture_world).orig_langcode

    # Mimic returns of best_translations()
    class TmpObj
      attr_accessor :is_orig
      def initialize(is_orig)
        @is_orig = is_orig
      end
    end
    ten = TmpObj.new(true)
    tja = TmpObj.new(false)
    tfr = TmpObj.new(nil)

    hs = {"fr" => tfr, "en" => ten, "ja" => tja}
    assert_equal %w(en ja fr), BaseWithTranslation.sorted_langcodes(hstrans: hs, first_lang: nil)
    assert_equal %w(ja en fr), BaseWithTranslation.sorted_langcodes(hstrans: hs, first_lang: 'ja')
    assert_equal %w(en fr ja), BaseWithTranslation.sorted_langcodes(hstrans: hs, first_lang: 'fr', prioritize_orig: true)
    assert_equal %w(it en ja fr), BaseWithTranslation.sorted_langcodes(hstrans: hs, first_lang: 'it', remove_invalid: false)
    assert_equal %w(en it ja fr), BaseWithTranslation.sorted_langcodes(hstrans: hs, first_lang: 'it', remove_invalid: false, prioritize_orig: true)
    assert_equal %w(it en ja fr kr), BaseWithTranslation.sorted_langcodes(hstrans: hs.merge({'kr'=>TmpObj.new(false)}), first_lang: 'it', remove_invalid: false)
    assert_equal    %w(en ja fr kr), BaseWithTranslation.sorted_langcodes(hstrans: hs.merge({'kr'=>TmpObj.new(false)}), first_lang: 'it', remove_invalid: true)

    male = Sex['male']
    assert_equal "male",      male.title_or_alt_tuple_str
    assert_equal "male",      male.title_or_alt_tuple_str(langcode: "naiyo")
    assert_equal "male (男)", male.title_or_alt_tuple_str(langcode: "ja") # No need of prioritize_orig
    assert_equal %w(男),      male.title_or_alt_tuple(    langcode: "ja") # Would Need prioritize_orig
    assert_equal %w(male 男), male.title_or_alt_tuple(    langcode: "ja", prioritize_orig: true)
    assert_equal "male (男)", male.title_or_alt_tuple_str(langcode: "ja")
    assert_equal  "",   male.title_or_alt(      langcode: "zo", prioritize_orig: false, lang_fallback_option: :never)
    assert_equal [""],  male.title_or_alt_tuple(langcode: "zo", prioritize_orig: false, lang_fallback_option: :never)
    assert_equal [nil], male.title_or_alt_tuple(langcode: "zo", prioritize_orig: false, lang_fallback_option: :never, str_fallback: nil)

    art = artists(:artist_proclaimers)  # "Proclaimers, The"
    assert_equal "The Proclaimers",  art.title_or_alt_tuple_str(langcode: "ja")
    assert_equal "Proclaimers, The", art.title_or_alt_tuple_str(langcode: "ja", normalize_definite_article: false), "'The' should be placed at the end only when explicitly specified."
  end

  test "no translations in titles etc" do
    obj = Sex.first
    assert_equal [nil, nil], obj.titles(langcode: 'it')
    %i(title ruby romaji alt_title alt_ruby alt_romaji).each do |em| 
      assert_nil  obj.public_send(em, langcode: 'it'), "obj.#{em.to_s} fails."
    end

    # Tests of title_or_alt
    assert_equal 'Liverpool', prefectures(:liverpool).title_or_alt(langcode: 'en')
    assert_equal 'Liverpool', prefectures(:liverpool).title_or_alt(langcode: 'en', prefer_alt: true)
    assert_equal "東京都本庁舎", places(:tocho).title_or_alt(langcode: 'ja')
    assert_equal '都庁',         places(:tocho).title_or_alt(langcode: 'ja', prefer_alt: true)
    assert_equal 'male', sexes(:sex1).title_or_alt(langcode: 'en')
    assert_equal 'M',    sexes(:sex1).title_or_alt(langcode: 'en', prefer_alt: true)

    pla1 = places(:takamatsu_station)
    assert_equal '高松駅', pla1.title(langcode: 'ja', lang_fallback: false)
    assert_nil             pla1.title(langcode: 'en', lang_fallback: false)
    assert_equal '高松駅', pla1.title(langcode: 'en', lang_fallback: true)
    assert_equal 'タカマツエキ', pla1.ruby(langcode: 'ja', lang_fallback: false)
    assert_nil                   pla1.ruby(langcode: 'en', lang_fallback: false)
    assert_equal 'タカマツエキ', pla1.ruby(langcode: 'en', lang_fallback: true)
    assert_nil  pla1.alt_ruby(langcode: 'ja', lang_fallback: false)
    assert_nil  pla1.alt_ruby(langcode: 'en', lang_fallback: false)
    assert_nil  pla1.alt_ruby(langcode: 'en', lang_fallback: true) # non-existent in any languages
    assert_equal 'Takamatsu Eki', pla1.romaji(langcode: 'ja', lang_fallback: false)
    assert_nil                    pla1.romaji(langcode: 'en', lang_fallback: false)
    assert_equal 'Takamatsu Eki', pla1.romaji(langcode: 'en', lang_fallback: true)
    assert_equal '高松駅', pla1.title_or_alt(langcode: 'ja')
    assert_raises(ArgumentError){ pla1.title_or_alt(langcode: 'en', lang_fallback_option: true) }
    assert_equal '',       pla1.title_or_alt(langcode: 'en', lang_fallback_option: :never)  # String guaranteed
    assert_equal '高松駅', pla1.title_or_alt(langcode: 'en', lang_fallback_option: :both)
    assert_equal '高松駅', pla1.title_or_alt(langcode: 'en', lang_fallback_option: :either)
    assert_equal '高松駅', pla1.title_or_alt(langcode: 'en', lang_fallback_option: :either, prefer_alt: true)
  end

  test "save_unsaved_translations" do
    sex = Sex.new iso5218: 12345
    tra1 = Translation.new langcode: 'fr', title: 'qulquechose nouveau', is_orig: false
    tra2 = Translation.new langcode: 'en', title: 'some new', is_orig: true
    sex.unsaved_translations << tra1 << tra2
    sex.save!

    sex.reload
    assert_equal 2, sex.translations.count
    assert_equal 'en', sex.orig_langcode
    assert_equal 'some new', sex.title

    n_sexes = Sex.count
    sex = Sex.new iso5218: 678
    tra = Translation.new langcode: nil, title: 'some new'  # langcode=nil means invalid.
    sex.unsaved_translations << tra
    assert_not   sex.valid?
    assert_not   sex.save
    assert_equal n_sexes, Sex.count

    tra = Translation.new langcode: 'en', title: 'some new', is_orig: true  # duplication means invalid.
    sex.unsaved_translations.clear
    sex.unsaved_translations << tra
    # assert_not   sex.valid?  # Translation class validates duplication (delgating to Sex) but BaseWithTranslation::UnsavedTranslationsValidator does not.  Hence this returns "valid".
    assert_not   sex.save
    assert_raises(ActiveRecord::RecordInvalid){
      sex.save! }
    assert_equal n_sexes, Sex.count
    assert_match(/Translation.+\bexists\b/, sex.errors.full_messages.to_s)

    #assert_no_difference('Translation.count') do
    assert_no_difference('Translation.count*1000 + Sex.count') do
      sex = Sex.new iso5218: 449
      tra5 = Translation.new langcode: 'fr', title: 'amour', is_orig: false
      tra6 = Translation.new langcode: 'en', title: Sex.first.title, is_orig: true
      sex.unsaved_translations << tra5 << tra6
      assert_not   sex.save
    end
  end

  test "of_title" do
    lennon = artists(:artist2)
    assert_equal musics(:music_how), Music.of_title('How?', scoped: lennon.musics).first
    assert_equal musics(:music_how), Music.of_title('how?', scoped: lennon.musics).first
    assert_nil                       Music.of_title('how?', exact: true, scoped: lennon.musics).first
  end

  test "orig-prioritized-find" do
    france = countries(:france)
    france_en = translations(:france_en)
    france_fr = translations(:france_fr)
    assert_equal ["French Republic, The", "France"], france_en.titles
    #assert_equal "France", france.title_or_alt
    assert_equal france_en.title, france.title_or_alt(langcode: "en")
    assert_equal "France",        france.title_or_alt(langcode: "en", prefer_alt: true)
    assert_equal "France, La", france_fr.title
    assert_equal "France, La", france.title_or_alt(langcode: "fr")
    assert_equal "France, La", france.title_or_alt(langcode: "ja")
    assert_equal "fr",         france.title_or_alt(langcode: "ja").lcode
  end
end

