# coding: utf-8
require 'test_helper'

class BaseWithTranslationTest < ActiveSupport::TestCase
  include ApplicationHelper # for suppress_ruby270_warnings()

  setup do
    # Without this, current_user may(!) exist if you run Controller or Integration tests at the same time.
    ModuleWhodunnit.whodunnit = nil
  end

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
    ar2= Sex.select_regex('title', 'male')
    assert_equal ar, ar2

    ret = Sex.select_regex(:title, 'male', debug_return_sql: true)
    assert_equal "SELECT \"sexes\".* FROM \"sexes\" INNER JOIN \"translations\" ON \"translations\".\"translatable_type\" = 'Sex' AND \"translations\".\"translatable_id\" = \"sexes\".\"id\" WHERE (\"translations\".\"translatable_type\" = 'Sex' AND \"translations\".\"title\" = 'male')", ret

    ret = Sex.select_regex(:title, /^male/, debug_return_sql: true, sql_regexp: true)
    assert_equal "SELECT \"sexes\".* FROM \"sexes\" INNER JOIN \"translations\" ON \"translations\".\"translatable_type\" = 'Sex' AND \"translations\".\"translatable_id\" = \"sexes\".\"id\" WHERE (\"translations\".\"translatable_type\" = 'Sex' AND (regexp_match(translations.title, '^male', 'n') IS NOT NULL))", ret

    ret = Sex.select_regex(:title, /^male/, debug_return_sql: true, sql_regexp: false)
    assert  ret.respond_to?(:each_pair), "should be Hash with values for the SQL String for Translation::ActiveRecord_Relation"
    assert_equal(:title, ret.keys.first)

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
  test "self.select_by_translations" do
    ret = Sex.select_by_translations(en: {title: 'male'})
    assert_equal Sex[1], ret.first
    ret = Sex.select_by_translations(debug_return_sql: true, en: {title: 'male'})
    assert_equal "SELECT DISTINCT \"sexes\".* FROM \"sexes\" INNER JOIN translations ON translations.translatable_id = sexes.id and translations.translatable_type = 'Sex' WHERE (translations.langcode = 'en' AND translations.title = 'male')", ret
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
    #cj = countries(:japan)
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

  # Testing methods for new records
  #
  test "methods with unsaved_translations" do
    mdl0 = Sex.new iso5218: 888
    mdlt = Sex.new iso5218: 999
    tra0 = Translation.new langcode: "ja", title: "翻訳-0", ruby: "ほんやく-0", romaji: "honnyaku-0", is_orig: false
    tra1 = Translation.new langcode: "en", alt_title: "tra-1-alt", is_orig: true
    assert_raise(RuntimeError){ mdlt.unsaved_translations = tra0 }
    mdlt.unsaved_translations = [tra0, tra1]

    assert_nil         mdl0.orig_translation
    assert_equal tra1, mdlt.orig_translation
    assert_nil         mdl0.orig_langcode
    assert_equal "en", mdlt.orig_langcode.to_s
    assert_equal [],     mdl0.translations_with_lang("ja")
    assert_equal [tra0], mdlt.translations_with_lang("ja")
    assert_nil                 mdl0.title
    assert_nil                 mdl0.ruby
    assert_equal "翻訳-0",     mdlt.title(langcode: "ja")
    assert_equal "ほんやく-0", mdlt.ruby(langcode: "ja")
    assert_equal "tra-1-alt",  mdlt.alt_title
    assert                     mdlt.title.blank?
    assert_nil                 mdl0.best_translation_is_orig
    assert_equal true,         mdlt.best_translation_is_orig
    assert_empty               mdl0.best_translations
    assert_empty               mdlt.best_translations
    assert_nil                 mdl0.best_translation
    assert_equal "en",         mdlt.best_translation.langcode
    tra1.is_orig=false
    assert_equal "ja",         mdlt.best_translation.langcode
    assert_equal false,        mdlt.best_translation_is_orig
  end # test "methods with unsaved_translations" do
 
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

  test "get_unique_weight" do
    # For Artist, Sex is mandatory. As long as birth_year or place differ, identical Translation-s are allowed.
    tras_orig = [
      [
       Translation.new(title: "b0", is_orig: true,  langcode: "en", weight: 0),
       Translation.new(title: "b1", is_orig: true,  langcode: "en", weight: 0),  # This may fail in validate in future.
       Translation.new(title: "b2", is_orig: false, langcode: "en", weight: 98),
       Translation.new(title: "b3", is_orig: false, langcode: "en", weight: 104),
       Translation.new(title: "b4", is_orig: false, langcode: "en", weight: 1104),
       Translation.new(title: "b5", is_orig: false, langcode: "en", weight: Float::INFINITY),
       Translation.new(title: "b6", is_orig: false, langcode: "en", weight: Float::INFINITY),
       Translation.new(title: "b7", is_orig: false, langcode: "en", weight: nil),
       Translation.new(title: "f0", is_orig: false, langcode: "fr", weight: 700),  # to ensure there is at least 1 Translation remaining
      ].shuffle,  # the order is deliberately mixed up.
      [Translation.new(title: "x1", is_orig: false, langcode: "en")]
    ]
    art0 = Artist.new(sex: Sex[0], birth_year: 1999)
    art0.unsaved_translations = tras_orig[0]
    art0.save!  # See a comment above for potential future failure in validate
    art1 = Artist.new(sex: Sex[1], birth_year: 2000)
    art1.unsaved_translations = tras_orig[1]
    art1.save!

    assert_equal 9, art0.translations.count, 'Sanity check.'
    assert_equal 8, art0.translations.where(langcode: "en").count, 'Sanity check.'
    assert_equal 2, art0.translations.where(weight: 0).count, 'Sanity check.'
    assert_equal 3, art0.translations.where(weight: Float::INFINITY).count, "Strangely failed sometimes ('setup do' should circumvent it now): ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} art0.translations(title,weight)="+Translation.sort(art0.translations).pluck(:title, :weight).inspect  # weight==nil => Float::INFINITY (for system (no current_user); see Translation#set_create_user)

    weight_def = Role::DEF_WEIGHT.values.max  # see get_unique_weight (base_with_translation.rb)

    trao = art1.best_translation("en")
    assert_equal Float::INFINITY, trao.weight  # weight==nil => Float::INFINITY (for system (no current_user); see Translation#set_create_user)

    trao.update!(weight: Float::INFINITY)  # redundant
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :low)
    assert_equal 2208, art0.get_unique_weight(trao, priority: :high)
    assert_equal    0, art0.get_unique_weight(trao, priority: :highest)

    trao.update!(weight: 2000)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal 2000, art0.get_unique_weight(trao, priority: :low)
    assert_equal 2000, art0.get_unique_weight(trao, priority: :high)

    trao.update!(weight: 1104)
    assert_equal 2208, art0.get_unique_weight(trao, priority: :low)
    assert_equal  604, art0.get_unique_weight(trao, priority: :high)

    trao.update!(weight: 1000)
    assert_equal 1000, art0.get_unique_weight(trao, priority: :low)
    assert_equal 1000, art0.get_unique_weight(trao, priority: :high)

    trao.update!(weight: 104)
    assert_equal  604, art0.get_unique_weight(trao, priority: :low)
    assert_equal  101, art0.get_unique_weight(trao, priority: :high)

    artra = []
    assert_equal  0, art0.get_unique_weight(trao, priority: :highest,  to_destroy: artra)
    assert_equal  2, artra.size  # Two Trans-weight=0 are destroyed.
    assert_equal  0, artra[-1].weight

    artra = []
    trao.update!(weight: 0)  # for :high
    assert_equal  0, art0.get_unique_weight(trao, priority: :high,   to_destroy: artra)
    assert_equal  2, artra.size  # Two Trans-weight=0 are destroyed.
    assert_equal  0, artra[-1].weight

    art0.translations.where(weight: 0, langcode: "en").each do |et|
      et.destroy
    end
    art0.reload
    assert_equal  7, art0.translations.count, "should have decreased by 2."

    trao.update!(weight: 50)
    artra = []
    assert_equal 50, art0.get_unique_weight(trao, priority: :low,     to_destroy: artra)
    assert_equal 50, art0.get_unique_weight(trao, priority: :high,    to_destroy: artra)
    assert      [49, 50].include?(art0.get_unique_weight(trao, priority: :highest, to_destroy: artra))
    assert_empty artra

    trao.update!(weight: 98)
    assert_equal 101, art0.get_unique_weight(trao, priority: :low,   )
    assert_equal  49, art0.get_unique_weight(trao, priority: :high,  )
    assert_equal  49, art0.get_unique_weight(trao, priority: :highest)
    assert_empty artra

    ## In the existing, no Infinity, no 0, but normal weights only
    art0.translations.where(weight: Float::INFINITY, langcode: "en").each do |et|
      et.destroy
    end
    art0.reload
    assert_equal  4, art0.translations.count, "should have decreased by 3."

    trao.update!(weight: 1104)
    assert_equal 2208, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal 2208, art0.get_unique_weight(trao, priority: :low)
    assert_equal  604, art0.get_unique_weight(trao, priority: :high,  )
    assert_equal   49, art0.get_unique_weight(trao, priority: :highest)

    trao.update!(weight: 1500)
    assert_equal 2208, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal 1500, art0.get_unique_weight(trao, priority: :low)
    assert_equal 1500, art0.get_unique_weight(trao, priority: :high,  )
    assert_equal   49, art0.get_unique_weight(trao, priority: :highest)

    ## only the existing weight is Infinity (for 2 Translations)
    tmp_tras = art0.translations.where(langcode: "en")
    tmp_tras[1..].each do |et|
      et.destroy
    end
    tmp_tras = art0.translations.where(langcode: "en")  # Without this, FrozenError would be raised below.
    tmp_tras[0..1].each do |et|
      et.update!(weight: Float::INFINITY)  # only the existing weight is Infinity (for 2 Translations) (for system (no current_user); see Translation#set_create_user)
    end
    art0.reload

    trao.update!(weight: Float::INFINITY)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :lowest), "Strangely sometimes fails ('setup do' should circumvent it now): art0.trans="+art0.translations.pluck(:title, :weight).inspect
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :low)
    assert_equal weight_def, art0.get_unique_weight(trao, priority: :high)
    assert_equal weight_def, art0.get_unique_weight(trao, priority: :highest)

    tmp_tras[0..1].each do |et|
      et.destroy # no existing Translation (for the langcode)
    end
    assert_not art0.translations.where(langcode: "en").exists?, 'Sanity check'

    trao.update!(weight: Float::INFINITY)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :low)
    assert_equal Float::INFINITY, art0.get_unique_weight(trao, priority: :high)
    assert_equal weight_def,    art0.get_unique_weight(trao, priority: :highest)

    trao.update!(weight: 88)
    assert_equal weight_def*10, art0.get_unique_weight(trao, priority: :lowest)
    assert_equal 88, art0.get_unique_weight(trao, priority: :low)
    assert_equal 88, art0.get_unique_weight(trao, priority: :high)
    assert_equal 88, art0.get_unique_weight(trao, priority: :highest)
  end  # test "get_unique_weight" do

  def _prepare_artists_with_trans
    # For Artist, Sex is mandatory. As long as birth_year or place differ, identical Translation-s are allowed.
    tras = [
      {ja: Translation.new(title: "何か000",         is_orig: false, langcode: "ja"),
       en: Translation.new(title: "Something000",    is_orig: true,  langcode: "en")}.with_indifferent_access,
      {ja: Translation.new(title: "何か001",         is_orig: false, langcode: "ja"),
       en: Translation.new(title: "Something001",    is_orig: true,  langcode: "en"),
       fr: Translation.new(title: "Quelquechose001", is_orig: false, langcode: "fr")}.with_indifferent_access
    ]
    art0 = Artist.new(sex: Sex[0], birth_year: 1999)
    art0.unsaved_translations = tras[0].values
    art0.save!
    art1 = Artist.new(sex: Sex[1], birth_year: 2000)
    art1.unsaved_translations = tras[1].values
    art1.save!

    art0_org = art0.dup
    art0.reload
    art1_org = art1.dup
    art1.reload

    [art0, art1, tras]
  end

  test "_merge_lang_orig01" do
    ## Test of "priority: :self". Both have different ja&en, is_orig=true(en)
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art1.best_translation("fr").update!(is_orig: nil)
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 3, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal Float::INFINITY, art0.orig_translation.weight, 'Strange sometimes ("setup do" should circumvent it now): art0.orig_translation='+art0.orig_translation.inspect  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      art0.send(:_merge_lang_orig, art1, priority: :self)

      art0.reload
      art1.reload
      assert_equal 2, art0.translations.size  # only orig-translation is transferred.
      assert_equal 2, art1.translations.size, "Should have decreased by 1, becoming 3-1=2"
      assert_equal 0, art1.translations.where(langcode: "en").count  # en in art1 has disappeared.
      assert_equal tras[0][:en].title, art0.orig_translation.title
      assert_equal Float::INFINITY, art0.orig_translation.weight
      assert_nil                       art1.orig_translation  # en translation (orig_translation) in art1 has disappeared.
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_lang_orig01" do

  test "_merge_lang_orig02" do
    ## Same as above but for "priority: :other".
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art1.best_translation("fr").update!(is_orig: nil)
      tras0_ids = tras.map{|i| i[:en].id}  # English(is_orig=true) translation IDs

      art0.send(:_merge_lang_orig, art1, priority: :other)

      art0.reload
      art1.reload
      assert_equal false, Translation.exists?(tras0_ids[0]), "The original translation in self should have disappeared b/c of priority=:other."
      assert_equal tras0_ids[1], art0.orig_translation.id
      assert_equal 2, art0.translations.size, "Though the original EN has disappeared, a new one is transferred from other (is_rig=true)"  # only orig-translation is transferred.
      assert_equal 2, art1.translations.size, "Should have decreased by 1, becoming 3-1=2"
      assert_equal 0, art1.translations.where(langcode: "en").count  # en in art1 has disappeared (transferred).
      assert_equal tras[1][:en].title, art0.orig_translation.title, "orig-trans should have been transferred"
      assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset; this only sometime fails strangely....."  # See get_unique_weight() for the number (where priority==:highest is given, because of orig_translation): = 100000
      assert_nil                       art1.orig_translation  # en translation (orig_translation) in art1 has disappeared.
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_lang_orig02" do

  test "_merge_lang_orig03" do
    ## Test of "priority: :self". art0:(ja)is_orig, art1:(en)is_orig, different ja&en
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art1.best_translation("fr").update!(is_orig: nil)
      art0.reset_orig_langcode("ja")
      art0.reload
      art1_orig_tr = art1.orig_translation 

      assert_equal 2, art0.translations.size
      assert_equal 3, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal Float::INFINITY, art0.orig_translation.weight  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)
      assert_equal true, art1_orig_tr.is_orig

      art0.send(:_merge_lang_orig, art1, priority: :self)

      art0.reload
      art1.reload
      assert_equal 2, art0.translations.size  # only orig-translation is transferred.
      assert_equal 3, art1.translations.size, "No change"
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal tras[0][:ja].title, art0.orig_translation.title
      assert_equal Float::INFINITY, art0.orig_translation.weight
      assert_nil                       art1.orig_translation  # is_orig becomes false.
      art1_orig_tr.reload
      assert_equal false,  art1_orig_tr.is_orig
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_lang_orig03" do

  test "_merge_lang_orig04" do
    ## Same as above but for "priority: :other".
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art1.best_translation("fr").update!(is_orig: nil)
      art0.reset_orig_langcode("ja")

      art0.send(:_merge_lang_orig, art1, priority: :other)

      art0.reload
      art1.reload
      assert_equal 3, art0.translations.size, "Should have increased by 1"
      assert_equal 2, art1.translations.size, "Should have decreased by 1, becoming 3-1=2"
      assert_equal 0, art1.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal tras[1][:en].title, art0.orig_translation.title, "inspect="+art0.translations.where(is_orig: true).inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset.  For some reason, this sometimes fails but only sometimes..... ('setup do' should circumvent it now) art0.orig_translation="+art0.orig_translation.inspect  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_lang_orig04" do

  test "_merge_lang_orig05" do
    ## Test where none has is_orig=true
    ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0.translations.update_all(is_orig: false)
      art1.translations.update_all(is_orig: false)
      art1.best_translation("fr").update!(is_orig: nil)

      ret = art0.send(:_merge_lang_orig, art1, priority: :other)

      art0.reload
      art1.reload
      assert_empty    ret.values.flatten.compact
      assert_empty    art0.translations.where(is_orig: true)
      assert_empty    art1.translations.where(is_orig: nil)

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end  # test "_merge_lang_orig05" do

  test "_merge_lang_orig06" do
    ## Test of "priority: :self". self has no is_orig=true but other has. :other has multiple is_orig=true (it is uncertain which of the is_orig=true Translations is selected; the following test takes it into account).
    ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0.translations.update_all(is_orig: false)
      art1.best_translation("fr").update!(is_orig: nil)
      art1.orig_translation.update!(weight: 67)
      art1.with_translation(langcode: "en", title: "Something011", is_orig: true, weight: 89)
      art1.reload
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 4, art1.translations.size
      assert_equal 2, art1.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(langcode: "en").count
      assert_equal 0, art0.translations.where(is_orig: true).count

      art0.send(:_merge_lang_orig, art1, priority: :self)

      art0.reload
      art1.reload
      assert_equal 3, art0.translations.size  # 2+1
      assert_equal 3, art1.translations.size, "Should have decreased by 1, becoming 4-1=2"
      assert_equal 1, art1.translations.where(langcode: "en").count  # An en in art1 has disappeared.
      assert([tras[1][:en].title, "Something011"].include?(art0.orig_translation.title))  # It is uncertain which Translation is selected, the original is_orig=true one or a new duplicate.
      assert([67, 89].include?(art0.orig_translation.weight), "For some reason, this sometimes fails but only sometimes..... ('setup do' should circumvent it now)")
      assert_equal 2, art0.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_nil                       art1.orig_translation  # en translation (orig_translation) in art1 has disappeared.
      assert_empty    art1.translations.where.not(is_orig: false)

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end  # test "_merge_lang_orig06" do

  test "_merge_lang_orig07" do
    ## Test of "priority: :other". self has is_orig=true for ja&en and other has it for two en. (it is uncertain which of the is_orig=true Translations is selected; the following test takes it into account).
    ## In base_with_translation.rb: "# Condition: Both have orig && langcode-s differ && priority==:other"
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0.best_translations["ja"].update!(is_orig: true)
      art0.best_translations["en"].update!(is_orig: true)
      art1.best_translation("fr").update!(is_orig: nil)
      art1.orig_translation.update!(weight: 67)  # :en
      art1.with_translation(langcode: "en", title: "Something011", is_orig: true, weight: 89)

      ## Sanity checks
      art0.reload
      art1.reload
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 4, art1.translations.size
      assert_equal 2, art1.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(langcode: "en").count
      assert_equal 2, art0.translations.where(is_orig: true).count

      # Run
      art0.send(:_merge_lang_orig, art1, priority: :other)

      art0.reload
      art1.reload
#      assert_equal 3, art0.translations.size, "art0.trans="+art0.translations.inspect   # 2+1
      assert_equal 3, art1.translations.size, "Should have decreased by 1, becoming 4-1=2"
      assert_equal 1, art1.translations.where(langcode: "en").count  # An en in art1 has disappeared.
      assert([tras[1][:en].title, "Something011"].include?(art0.orig_translation.title))  # It is uncertain which Translation is selected, the original is_orig=true one or a new duplicate.
      assert([67, 89].include?(art0.orig_translation.weight))
#      assert_equal 2, art0.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_nil                       art1.orig_translation  # en translation-s (orig_translation) in art1 have disappeared.
      assert_empty    art1.translations.where.not(is_orig: false)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_lang_orig2" do


  test "_merge_trans01" do
    ## Test of "priority: :self". Both have different ja&en, is_orig=true(en)
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      #art0.reset_orig_langcode("ja")
      art1.best_translation("fr").update!(is_orig: nil)
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 3, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal Float::INFINITY, art0.orig_translation.weight  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      art0.send(:_merge_trans, art1, priority_orig: :self, priority_others: :self)
      # An English disappers. Japanese is added.

      art0.reload
      art1.reload
      assert_equal 4, art0.translations.size, "Should have increased by 2 (ja and fr): "+art0.translations.inspect
      assert_equal 0, art1.translations.size  #, "Should have decreased by 1, becoming 3-1=2"
      assert_equal 1, art0.translations.where(langcode: "en").count
      assert_equal 2, art0.translations.where(langcode: "ja").count
      assert_equal 1, art0.translations.where(langcode: "fr").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal tras[0][:en].title, art0.orig_translation.title, "inspect="+art0.translations.where(is_orig: true).inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Float::INFINITY, art0.orig_translation.weight  ## This is the case (b/c untouched?).
      #assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset"  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end # test "_merge_trans01" do

  test "_merge_trans02" do
    ## Test of "priority(ies): :self". self(en-is_orig, ja), other(en, ja-is_orig-identical_to_self)
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0.reset_orig_langcode("en")
      art1.reset_orig_langcode("ja")
      art1_ja = art1.best_translation("ja")
      art1_ja.update!(title: tras[0][:ja].title)
      art1.best_translation("fr").update!(is_orig: nil)
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 3, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal Float::INFINITY, art0.orig_translation.weight, "Strangely fails sometimes ('setup do' should circumvent it now): ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} orig="+art0.orig_translation.inspect  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      reths = art0.send(:_merge_trans, art1, priority_orig: :self, priority_others: :self)
      # An English disappers. Japanese is added.

      art0.reload
      art1.reload
      assert_equal 4, art0.translations.size, "Should have increased by 2 (ja and fr)"
      assert reths[:destroy].include?(art1_ja) 
      assert((0..1).cover?(art1.translations.size))  # reths[:destroy].first is currently not destroyed, but the specification may change.
      assert_equal 2, art0.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(langcode: "ja").count
      assert_equal 1, art0.translations.where(langcode: "fr").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal tras[0][:en].title, art0.orig_translation.title, "inspect="+art0.translations.where(is_orig: true).inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Float::INFINITY, art0.orig_translation.weight
      #assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset"  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end # test "_merge_trans02" do

  test "_merge_trans03" do
    ## Same but Test of "priority_other: :other". self(en-is_orig, ja), other(en, ja-is_orig-identical_to_self)
    #ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0.reset_orig_langcode("en")
      art1.reset_orig_langcode("ja")
      art0_ja = art0.best_translation("ja")
      art1_ja = art1.best_translation("ja")
      art1_ja.update!(title: tras[0][:ja].title)
      art1.best_translation("fr").update!(is_orig: nil)
      assert_equal 1, art1.translations.where(is_orig: nil).count
      assert_equal 2, art0.translations.size
      assert_equal 3, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal Float::INFINITY, art0.orig_translation.weight, "Strangely fails sometimes ('setup do' should circumvent it now): ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} orig="+art0.orig_translation.inspect  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      reths = art0.send(:_merge_trans, art1, priority_orig: :self, priority_others: :other)

      art0.reload
      art1.reload
      assert_equal 4, art0.translations.size, "Should have increased by 2 (ja and fr)"
      assert reths[:destroy].include?(art0_ja), "        art0_ja=#{art0_ja.inspect}\n        art1_ja=#{art1_ja.inspect}\nreths[:destroy]="+reths[:destroy].inspect
      assert_equal 0, art1.translations.where(langcode: "en").count  # All translations should have been transferred.
      assert_equal 2, art0.translations.where(langcode: "en").count
      assert_equal 1, art0.translations.where(langcode: "ja").count
      assert_equal 1, art0.translations.where(langcode: "fr").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal tras[0][:en].title, art0.orig_translation.title, "inspect="+art0.translations.where(is_orig: true).inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Float::INFINITY, art0.orig_translation.weight
      #assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset"  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end  # test "_merge_trans03" do

  test "_merge_trans04" do
    ## Test of "priority_orig,other: :self,:other". self(en-is_orig, ja), other(en-is_orig-alt_title, ja1, ja2-identical_to_self)
    ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0_ja = art0.best_translation("ja")
      art0_en = art0.best_translation("en")
      art0_ja.update!(weight: 200)
      new_self_tit = tras[0][:ja].title
      art1_ja1= art1.best_translation("ja")
      art1_en = art1.best_translation("en")
      art1_en.update!(alt_title: "brand-new")
      art1_ja1.update!(weight: 100)
      art1.with_translation(title: new_self_tit, langcode: "ja", weight: 20000)
      art1_ja2 = art1.translations.where(langcode: "ja", weight: 20000).first  # This conflicts with art0_ja (for self)
      art1.best_translation("fr").update!(is_orig: nil)
      art0.reload
      art1.reload
      assert_equal 2, art1.translations.where(is_orig: nil).count, "art1.tras="+art1.translations.where(is_orig: nil).inspect # with fr and new ja
      assert_equal 2, art0.translations.size # jax2, en
      assert_equal 4, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal 2, art1.translations.where(langcode: "ja").count
      assert_equal "brand-new", art1.orig_translation.alt_title
      assert_equal Float::INFINITY, art0.orig_translation.weight, "Strangely fails sometimes ('setup do' should circumvent it now): ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} orig="+art0.orig_translation.inspect  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      reths = art0.send(:_merge_trans, art1, priority_orig: :self, priority_others: :other)

      art0.reload
      art1.reload
      assert_equal 4, art0.translations.size, "Should have increased by 2 (new ja and fr): "+art0.translations.order(:langcode).inspect
      assert reths[:destroy].include?(art0_ja), "        art0_ja=#{art0_ja.inspect}\n       art1_ja2=#{art1_ja2.inspect}\nreths[:destroy]="+reths[:destroy].inspect
      assert_equal 0, art1.translations.where(langcode: "en").count  # All translations should have been transferred.
      assert_equal 1, art0.translations.where(langcode: "en").count
      assert_equal tras[0][:en].title, art0.orig_translation.title, "Unchanged."
      assert_equal "brand-new",        art0.orig_translation.alt_title, "alt added"
      assert_equal 2, art0.translations.where(langcode: "ja").count
      assert_equal 1, art0.translations.where(langcode: "fr").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal art1_ja1, art0.best_translations[:ja]
      assert_equal art1_ja2, art0.translations.where(langcode: "ja", title: new_self_tit).first, "to_compare=#{tras[0][:ja].inspect} tras="+art0.translations.where(langcode: "ja").inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Float::INFINITY, art0.orig_translation.weight
      #assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset"  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end # test "_merge_trans04" do

  test "_merge_trans05" do
    ## Test of "priority_orig,other: :self,:other". self(en-is_orig, ja, ja), other(en-is_orig-alt_title, ja1, ja2-identical_to_self_2)
    ActiveRecord::Base.transaction(requires_new: true) do
      art0, art1, tras = _prepare_artists_with_trans
      art0_ja = art0.best_translation("ja")
      art0_en = art0.best_translation("en")
      art0_ja.update!(weight: 200)
      new_self_tit = "新しいselfタイトル"
      art0.with_translation(title: new_self_tit, langcode: "ja", weight: 300)
      art0_ja2 = art0.translations.where(langcode: "ja", weight: 300).first
      art1_ja1= art1.best_translation("ja")
      art1_en = art1.best_translation("en")
      art1_en.update!(alt_title: "brand-new")
      art1_ja1.update!(weight: 100)
      art1.with_translation(title: new_self_tit, langcode: "ja", weight: 20000)
      art1_ja2 = art1.translations.where(langcode: "ja", weight: 20000).first  # This conflicts with art0_ja2 (for self)
        # Here we have craeted new Japanese Translations with a common titl for both art0 and art1.
        # Because they are newly added, they will be evaluated AFTER the first one when that in art1 is added to art0.
        # This means the unrelated first JA Translation in art0 was test-destroyed.
        # Thus, this tests _attempt_add_other_trans()

      art1.best_translation("fr").update!(is_orig: nil)
      art0.reload
      art1.reload
      assert_equal 2, art1.translations.where(is_orig: nil).count, "art1.tras="+art1.translations.where(is_orig: nil).inspect # with fr and new ja
      assert_equal 3, art0.translations.size # jax2, en
      assert_equal 4, art1.translations.size
      assert_equal 1, art1.translations.where(langcode: "en").count
      assert_equal 2, art1.translations.where(langcode: "ja").count
      assert_equal "brand-new", art1.orig_translation.alt_title
      assert_equal Float::INFINITY, art0.orig_translation.weight  # nil weight is automatically reset at Infinity (for system (no current_user); see Translation#set_create_user)

      reths = art0.send(:_merge_trans, art1, priority_orig: :self, priority_others: :other)

      art0.reload
      art1.reload
      assert_equal 5, art0.translations.size, "Should have increased by 2 (new ja and fr): "+art0.translations.order(:langcode).inspect
      assert reths[:destroy].include?(art0_ja2), "        art0_ja2=#{art0_ja2.inspect}\n        art1_ja2=#{art1_ja2.inspect}\nreths[:destroy]="+reths[:destroy].inspect
      assert_equal 0, art1.translations.where(langcode: "en").count  # All translations should have been transferred.
      assert_equal 1, art0.translations.where(langcode: "en").count
      assert_equal tras[0][:en].title, art0.orig_translation.title, "Unchanged."
      assert_equal "brand-new",        art0.orig_translation.alt_title, "alt added"
      assert_equal 3, art0.translations.where(langcode: "ja").count
      assert_equal 1, art0.translations.where(langcode: "fr").count
      assert_equal 1, art0.translations.where(is_orig: true).count
      assert_equal art1_ja1, art0.best_translations[:ja]
      assert_equal art1_ja2, art0.translations.where(langcode: "ja", title: new_self_tit).first, "to_compare=#{tras[0][:ja].inspect} tras="+art0.translations.where(langcode: "ja").inspect
      assert_equal false, art0.best_translations[:ja].is_orig
      assert_equal Float::INFINITY, art0.orig_translation.weight
      #assert_equal Role::DEF_WEIGHT.values.max, art0.orig_translation.weight, "weight should have been reset"  # See above
      assert_nil                       art1.orig_translation  # orig_translation should have disappeared
      assert_empty    art1.translations.where(is_orig: nil)

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end # test "_merge_trans05" do

  test "merge_other overwrite, note, created_at" do
    iho1 = musics(:music_ihojin1) # year: 1969
    iho2 = musics(:music_ihojin2) # year: 1981
    m_un = musics(:music_unknown)

    iho1_year_orig = iho1.year
    iho2_year_orig = iho2.year

    iho1.send(:_merge_overwrite, iho2, :naiyo)
    assert_equal iho1_year_orig, iho1.year, ":naiyo should be skipped."
    iho1.reload

    iho1.send(:_merge_overwrite, iho2, :year, priority: :self)
    assert_equal iho1_year_orig, iho1.year, "Test of priority: :self."
    assert_equal iho2_year_orig, iho2.year
    iho1.reload

    iho1.send(:_merge_overwrite, iho2, :year, priority: :other)
    assert_equal iho2.year,      iho1.year, "Test of priority: :other."
    assert_equal iho2_year_orig, iho2.year
    iho1.reload

    iho1.send(:_merge_overwrite, m_un, :year, priority: :other)
    assert_equal iho1_year_orig, iho1.year, "nil should have the lowest priority (1)"
    assert_nil  m_un.year
    iho1.reload

    m_un.send(:_merge_overwrite, iho2, :year, priority: :self)
    assert_equal iho2_year_orig, m_un.year, "nil should have the lowest priority (2)"
    assert_equal iho2_year_orig, iho2.year
    m_un.reload

    ## merge-note

    iho1_note_orig = iho1.note
    iho2_note_orig = iho2.note

    iho1.note = "  " + iho1_note_orig + "  "  # should be stripped.
    iho1.send(:_merge_note, iho2, priority: :self)
    assert_equal iho1_note_orig+" "+iho2_note_orig, iho1.note
    assert_equal iho2_note_orig,                    iho2.note
    iho1.reload

    iho1.send(:_merge_note, iho2, priority: :other)
    assert_equal iho2_note_orig+" "+iho1_note_orig, iho1.note
    assert_equal iho2_note_orig,                    iho2.note
    iho1.reload

    m_un.note = nil
    iho1.send(:_merge_note, m_un, priority: :other)
    assert_equal iho1_note_orig, iho1.note, "if one of them is blank, it should be ignored (1)"
    iho1.reload
    m_un.reload

    m_un.note = nil
    m_un.send(:_merge_note, iho2, priority: :self)
    assert_equal iho2_note_orig, m_un.note, "if one of them is blank, it should be ignored (2)"
    m_un.reload

    m_un.note = nil
    iho2.note = ""
    m_un.send(:_merge_note, iho2, priority: :self)
    assert  m_un.note.blank?, "if both are blank, the result should be blank, too"
    m_un.reload
    iho2.reload

    ## created_at

    iho1.created_at = DateTime.now
    iho1_created_at_orig = iho1.created_at
    iho2_created_at_orig = iho2.created_at
    iho1.send(:_merge_created_at, iho2)
    assert_equal iho2_created_at_orig, iho1.created_at
    assert_equal iho2_created_at_orig, iho2.created_at
    iho1.reload

    iho2.created_at = DateTime.now
    iho1_created_at_orig = iho1.created_at
    iho2_created_at_orig = iho2.created_at
    iho1.send(:_merge_created_at, iho2)
    assert_equal iho1_created_at_orig, iho1.created_at
    assert_equal iho2_created_at_orig, iho2.created_at
    iho1.reload
    iho2.reload
  end

  test "merge_birthday" do
    art2 = artists(:artist2)
    art3 = artists(:artist3)

    art2.birth_year  = 1980
    art2.birth_month =   12
    art2.birth_day   =  nil
    art3.birth_year  =  nil
    art3.birth_month =    9
    art3.birth_day   =  nil

    art2.send(:_merge_birthday, art3, priority: :self)
    assert_equal 1980, art2.birth_year
    assert_equal   12, art2.birth_month
    assert_nil         art2.birth_day
    art2.reload

    art2.birth_year  = 1980
    art2.birth_month =   12
    art2.birth_day   =  nil
    art2.send(:_merge_birthday, art3, priority: :other)
    assert_equal 1980, art2.birth_year
    assert_equal    9, art2.birth_month
    assert_nil         art2.birth_day
    art2.reload
  end

  test "merge_engages" do
    # cf. test "create_manual"  in harami1129_test.rb

    ## Test of "priority: :self"
    ActiveRecord::Base.transaction(requires_new: true) do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1
      # Sanity checks...
      assert_equal 2, hsmdl[:engages].map{|em| em ? em.id : nil}.compact.uniq.size, 'Sanity check...'
      assert_equal hsmdl[:musics][0], hsmdl[:engages][0].music, 'Sanity check.'
      assert_equal hsmdl[:musics][1], hsmdl[:engages][1].music, 'Sanity check.'
      assert_equal h1129_prms[:song][0], hsmdl[:engages][0].music.best_translation.title
      assert_equal h1129_prms[:song][1], hsmdl[:engages][1].music.best_translation.title
      assert       assc_prms[:mu_year][0], 'Sanity check.'
      assert_equal assc_prms[:mu_year][0],  hsmdl[:musics][0].year
      assert_nil   hsmdl[:musics][1].year
      assert_nil   assc_prms[:mu_genre][0], 'Sanity check.'
      assert_equal Genre.default,  hsmdl[:musics][0].genre
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution

      # Adjust created_at for Engage to destroy eventually
      new_time = DateTime.now - 1000
      hsmdl[:engages][1].update!(created_at: new_time)

      ## merge Engage for Music and modify Harami1129
      hs2 = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :self)

      hsret = hs2[:engage]
      assert_equal 2, hsret[:remained].size
      assert_empty    hsret[:destroy]
      assert_equal Engage, hsret[:remained].first.class

      hsret = hs2[:harami1129]
      assert_equal 0, hsret[:remained].size, "Given that the original two have completely separate singer (Artist) and song (Music), when either Artist or Music is merged, two existing Engages will survive, meaning no change in Harami1129-s."
      assert_empty    hsret[:destroy]

      #assert_equal assc_prms[:mu_genre][1], hsmdl[:musics][0].genre, 'should have been merged.'
      #assert_equal assc_prms[:mu_place][0], hsmdl[:musics][0].place, 'should stay the same.'
      hsmdl[:engages][0].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][0].music
      assert_equal hsmdl[:artists][0], hsmdl[:engages][0].artist, 'Sanity check.'
      hsmdl[:engages][1].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][1].music, 'Engage#music_id should have been merged. eng_id='+hsmdl[:engages].map(&:id).inspect
      assert_equal hsmdl[:artists][1], hsmdl[:engages][1].artist, 'Sanity check. no change.'
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution

      ## Further, merge Engage for Artist  -- this should merge Engage
      hs2 = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      hsret = hs2[:engage]
      assert_equal 1, hsret[:remained].size, "engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 1, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size
      assert_equal hsret[:destroy].first.id, hsmdl[:engages][1].id
      assert_equal  new_time, hsret[:destroy].first.created_at

      hsret = hs2[:harami1129]
      assert_equal 1, hsret[:remained].size
      assert_empty    hsret[:destroy], "always empty"
      assert_equal Harami1129, hsret[:remained].first.class
      assert  hsret[:remained].map(&:id).include?(hsret[:remained].first.id)

      eng_remains.first.reload
      assert_equal     assc_prms[:eng_contribution][1], eng_remains.first.contribution
      assert_not_equal assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution
      hsmdl[:engages][0].reload
      assert_equal     assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution, "Engage#contribution should have changed."
      assert_equal  new_time, hsmdl[:engages][0].created_at

      hsmdl[:h1129s][1].reload
      assert_equal  hsmdl[:artists][0], hsmdl[:h1129s][1].engage.artist
      assert_equal  hsmdl[:musics][0],  hsmdl[:h1129s][1].engage.music

      raise ActiveRecord::Rollback, "Force rollback."
    end

    ## Test of "priority: :other"
    ActiveRecord::Base.transaction(requires_new: true) do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1

      # Adjust year for Engage
      new_year = 1945
      hsmdl[:engages][1].update!(year: new_year)

      # Adjust created_at for Engage to destroy eventually
      new_time = DateTime.now - 1000
      hsmdl[:engages][1].update!(created_at: new_time)

      ## merge Engage for Music,  priority: :other
      hs2 = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :other)

      hsret = hs2[:engage]
      assert_equal 2, hsret[:remained].size
      assert_empty    hsret[:destroy]
      assert_equal Engage, hsret[:remained].first.class

      hsret = hs2[:harami1129]
      assert_equal 0, hsret[:remained].size
      assert_empty    hsret[:destroy]

      hsmdl[:engages][0].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][0].music
      assert_equal hsmdl[:artists][0], hsmdl[:engages][0].artist, 'Sanity check.'
      hsmdl[:engages][1].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][1].music, 'Engage#music_id should have been merged. eng_id='+hsmdl[:engages].map(&:id).inspect
      assert_equal hsmdl[:artists][1], hsmdl[:engages][1].artist, 'Sanity check. no change.'
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution
      assert_equal assc_prms[:eng_year][0],         hsmdl[:engages][0].year  # 1994

      ## Further, merge Engage for Artist  -- this should merge Engage
      hs2 = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :other)

      hsret = hs2[:engage]
      assert_equal 1, hsret[:remained].size, "engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 1, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size
      assert_equal hsret[:destroy].first.id, hsmdl[:engages][1].id
      assert_equal  new_time, hsret[:destroy].first.created_at

      hsret = hs2[:harami1129]
      assert_equal 1, hsret[:remained].size
      assert_empty    hsret[:destroy], "always empty"
      assert_equal Harami1129, hsret[:remained].first.class
      assert  hsret[:remained].map(&:id).include?(hsret[:remained].first.id)

      eng_remains.first.reload
      assert_equal     assc_prms[:eng_contribution][1], eng_remains.first.contribution
      assert_not_equal assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution
      hsmdl[:engages][0].reload
      assert_equal     assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution, "Engage#contribution should have changed."
      assert_equal  new_year, hsmdl[:engages][0].year  # 1945
      assert_equal  new_time, hsmdl[:engages][0].created_at

      hsmdl[:h1129s][1].reload
      assert_equal  hsmdl[:artists][0], hsmdl[:h1129s][1].engage.artist
      assert_equal  hsmdl[:musics][0],  hsmdl[:h1129s][1].engage.music

      raise ActiveRecord::Rollback, "Force rollback."
    end

    ## Test of different EngageHow: both Engages should survive.
    ActiveRecord::Base.transaction(requires_new: true) do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1

      # Adjust created_at for Engage to destroy eventually
      new_time = DateTime.now - 1000
      hsmdl[:engages][1].update!(engage_how: engage_hows(:engage_how_assistant))

      ## RUN: merge Engage for Music
      hsret = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :self)

      # Sanity check
      engage_how0_orig = hsmdl[:engages][0].engage_how
      assert_equal engage_hows(:engage_how_singer_original), engage_how0_orig

      hsmdl[:engages][0].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][0].music
      hsmdl[:engages][1].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][1].music, 'Engage#music_id should have been merged. eng_id='+hsmdl[:engages].map(&:id).inspect
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution

      ## RUN: Further, merge Engage for Artist  -- this still will not merge Engage
      hs2 = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      hsret = hs2[:engage]
      assert_equal 2, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      assert_equal 0, hsret[:destroy].size

      hsret = hs2[:harami1129]
      assert_equal 0, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      assert_empty    hsret[:destroy]

      hsmdl[:engages][0].reload
      assert_not_equal assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution, "Engage#contribution should not change."
      assert_not_equal new_time, hsmdl[:engages][0].created_at
      assert_equal engage_how0_orig, hsmdl[:engages][0].engage_how

      hsmdl[:h1129s][1].reload
      assert_equal  hsmdl[:artists][0], hsmdl[:h1129s][1].engage.artist
      assert_equal  hsmdl[:musics][0],  hsmdl[:h1129s][1].engage.music

      raise ActiveRecord::Rollback, "Force rollback."
    end

    ## Test of multiple EngageHow: one of them disappear.
    ActiveRecord::Base.transaction(requires_new: true) do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1

      # Adjust created_at for Engage to destroy eventually
      new_time = DateTime.now - 1000
      hsmdl[:engages][1].update!(created_at: new_time)

      # Adjusts EngageHow. Also adds another Engage
      # The first two should be merged
      # Harami1129 that now belong_to the second one should come to belong_to the third one
      # (because of EngageHow#weight).
      hsmdl[:engages][0].update!(engage_how: engage_hows(:engage_how_producer))
      hsmdl[:engages][1].update!(engage_how: engage_hows(:engage_how_producer))
      hsmdl[:engages][2] = Engage.create!(music: hsmdl[:engages][1].music, artist: hsmdl[:engages][1].artist, engage_how: engage_hows(:engage_how_composer), contribution: 0.4)

      ## RUN: merge Engage for Music
      hsret = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :self)

      hsmdl[:engages][0].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][0].music
      hsmdl[:engages][1].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][1].music, 'Engage#music_id should have been merged. eng_id='+hsmdl[:engages].map(&:id).inspect
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution

      ## RUN: Further, merge Engage for Artist  -- this still will not merge Engage
      hs2 = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      hsret = hs2[:engage]
      assert_equal 2, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size
      assert_equal hsmdl[:engages][1].id, hsret[:destroy].first.id

      hsret = hs2[:harami1129]
      assert_equal 1, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      assert_empty    hsret[:destroy]
      assert hs2[:engage][:remained].map(&:id).include?(hsret[:remained].first.engage_id)

      hsmdl[:engages][0].reload
      assert_equal assc_prms[:eng_contribution][1], hsmdl[:engages][0].contribution, "Engage#contribution should be updated."
      assert_equal new_time, hsmdl[:engages][0].created_at, "created_at should be updated."
      hsmdl[:h1129s][1].reload
      assert_equal hsmdl[:engages][2], hsmdl[:h1129s][1].engage, "exp(#{hsmdl[:engages][2].engage_how.title}) <=> act(#{hsmdl[:h1129s][1].engage.engage_how.title})"

      hsmdl[:h1129s][1].reload
      assert_equal  hsmdl[:artists][0], hsmdl[:h1129s][1].engage.artist
      assert_equal  hsmdl[:musics][0],  hsmdl[:h1129s][1].engage.music

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end

  test "merge_other all" do
    iho1 = musics(:music_ihojin1) # year: 1969
    iho2 = musics(:music_ihojin2) # year: 1981

    iho1_year_orig = iho1.year
    iho2_year_orig = iho2.year

    iho1_hvmas_size = iho1.harami_vid_music_assocs.count
    iho2_hvmas_size = iho2.harami_vid_music_assocs.count
    assert_operator iho1_hvmas_size, '>', 0, 'Sanity check failed...'
    assert_operator iho2_hvmas_size, '>', 0, 'Sanity check failed...'
    iho1_hvma1 = iho1.harami_vid_music_assocs.first
    assert_not iho2.harami_vid_music_assocs.include?(iho1_hvma1), 'Sanity check failed...'

    ActiveRecord::Base.transaction(requires_new: true) do
      hspri = {default: :self, year: :self, note: :self}
      iho1.update!(created_at: DateTime.now)
      hsmodel = iho1.merge_other iho2, priorities: hspri, save_destroy: false
      assert_equal iho1_year_orig, iho1.year, "Test of _merge_overwrite with 'priority: :self'."
      assert_equal iho2_year_orig, iho2.year
      hsarys = hsmodel[:harami_vid_music_assocs]
      assert_equal iho1_hvmas_size+iho2_hvmas_size, hsarys[:remained].size+hsarys[:destroy].size, "Failed: #{hsmodel[:harami_vid_music_assocs].inspect}"
      assert_equal iho2.created_at, iho1.created_at, "Test of _merge_created_at"
      assert     Music.exists?(iho2.id)
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload

    ## Test of updating "timing" only, where both Musics have a similar HaramiVidMusicAssoc with
    ## a only difference of timing.  A positive timing would be always adopted.
    ActiveRecord::Base.transaction(requires_new: true) do
      hspri = {default: :self, year: :self, note: :self}
      # Check of updating "timing"
      iho1_hvma1.reload  # This does not exist in iho2 (according to Fixture; see a sanity check above)
      hvma_collide = HaramiVidMusicAssoc.new(iho1_hvma1.attributes)
      hvma_collide.music = iho2
      hvma_collide.id = nil
      hvma_collide.timing = 77
      hvma_collide.save!
      iho2.save!
      iho2.reload
      assert_equal iho2_hvmas_size+1, iho2.harami_vid_music_assocs.count, 'Sanity check failed...'

      iho1_hvma1.timing = nil
      iho1_hvma1.save!
      hsmodel = iho1.merge_other iho2, priorities: hspri, save_destroy: true

      assert_equal iho1_hvmas_size+iho2_hvmas_size, hsmodel[:harami_vid_music_assocs].size, "Failed: #{hsmodel[:harami_vid_music_assocs].inspect}"
      
      assert_equal 77, iho1_hvma1.reload.timing
      assert_not Music.exists?(iho2.id)
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload

    ActiveRecord::Base.transaction(requires_new: true) do
      hspri = {default: :other, year: :other, note: :other}
      iho1.merge_other iho2, priorities: hspri
      assert_equal iho2.year,      iho1.year, "Test of priority: :other."
      assert_equal iho2_year_orig, iho2.year
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload
  end

  test "merge_other music trans-engage01" do
    # cf. test "create_manual"  in harami1129_test.rb

    #ActiveRecord::Base.transaction(requires_new: true) do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1
      assert_equal Place.unknown, hsmdl[:artists][0].place, 'Sanity check...'
      assert_equal h1129_prms[:song][0],    hsmdl[:musics][0].title, 'Sanity check...'
      tras = [0, 1].map{|i| hsmdl[:musics][i].best_translation}
      engss= [0, 1].map{|i| hsmdl[:musics][i].engages}
      assert_equal [true, true], tras.map(&:is_orig), 'Sanity check...'
      assert_equal [1, 1],      engss.map(&:size), 'Sanity check...'
      engs = engss.map(&:first)
      arts = [0, 1].map{|i| hsmdl[:musics][i].artists}
      assert_equal "en", tras[0].best_translation.langcode, 'Sanity check...'
      assert_equal "en", tras[1].best_translation.langcode, 'Sanity check...'
      refute_equal hsmdl[:hvmas][0].music, hsmdl[:hvmas][1].music, 'Sanity check...'
      assert_equal hsmdl[:musics][1],      hsmdl[:hvmas][1].music, 'Sanity check...'

    #  ActiveRecord::Base.transaction(requires_new: true) do
        genre_org = hsmdl[:musics][0].genre
        hspri = {default: :other, genre: :self, year: :other, note: :other}
        ## Run
        hsret = hsmdl[:musics][0].merge_other(hsmdl[:musics][1], priorities: hspri, save_destroy: true)
        new_mu = hsmdl[:musics][0].reload
#puts "DEBUG(orig901): music-ID="+new_mu.id.to_s

        assert_equal 1, hsret[:destroyed].find_all{|i| Translation === i}.size
        assert_equal 1, hsret[:destroyed].find_all{|i| Music === i}.size
        assert_equal 2, hsret[:destroyed].size, '1 Music and 1 Translation destroyed'
        assert_equal 1, hsret[:trans][ :remained].size,     '1 Translation remains'
        assert_equal 2, hsret[:engage][:remained].size
        assert_equal 2, hsret[:harami_vid_music_assocs][ :remained].size
        assert_equal hsret[:trans][:remained].first, hsret[:trans][:original]
        assert_equal tras[1],                        hsret[:trans][:original]
        assert_empty hsret[:trans][:destroy]
        assert_empty hsret[:engage][:destroy]
        refute  hsmdl[:musics][0].db_destroyed?  # db_destroyed? defined in application_record.rb
        assert  hsmdl[:musics][1].db_destroyed?
        assert  tras[0].db_destroyed?, "is_orig=true for the same language should have been destroyed."
        refute  tras[1].db_destroyed?, "tras="+tras.inspect
        tras[1].reload
        assert_equal new_mu, tras[1].translatable, "Translation should have been transferred."
        engs[0].reload
        engs[1].reload
        assert_equal 2, new_mu.engages.size,       "Engage should have been merged."
        assert_equal new_mu, engs[0].music
        assert_equal new_mu, engs[1].music,   "This Engage should have been merged."
        refute_equal engs[0].artist, engs[1].artist,  "Now Music should have two Artists."
        hsmdl[:hvmas][1].reload
        assert_equal new_mu, hsmdl[:hvmas][1].music,  "Now HaramiVidMusicAssoc should have been updated (its Music should have been transferred)."

        ## The two association of Harami1129, which should have not changed (in terms of ID)
        [0,1].each do |i|
          hsmdl[:h1129s][i].reload
          assert_equal engs[i],          hsmdl[:h1129s][i].engage, "Went wrong in #{i}."
          assert_equal hsmdl[:hvmas][i], hsmdl[:h1129s][i].harami_vid_music_assoc, "Went wrong in #{i}."
        end

        assert_equal assc_prms[:mu_year][0],  hsmdl[:musics][0].year
        assert_equal genres(:genre_classic),  assc_prms[:mu_genre][1], 'Sanity check'
        assert_equal genres(:genre_classic),  hsmdl[:musics][1].genre, 'Sanity check'
        hsmdl[:musics][0].reload
        assert_equal h1129_prms[:song][1],    hsmdl[:musics][0].title
        assert_not_equal           genre_org, hsmdl[:musics][0].genre, "Genre changed"
        assert_equal hsmdl[:musics][1].genre, hsmdl[:musics][0].genre, "Genre sorted"
        assert_equal assc_prms[:mu_place][0], hsmdl[:musics][0].place, "b/c Place encompass-ing despite priority=:other"

        #raise ActiveRecord::Rollback, "Force rollback."
    #  end
      #raise ActiveRecord::Rollback, "Force rollback."
    #end
  end

  # Testing merging two Artists associated to separate Music-s, where orig-translations differ in language,
  # and they have identical non-original-language Translations.
  #
  # @todo Try merging two Musics associated to the same Artist.  You can continue merging Musics after all the processes of this test!
  test "merge_other Artist trans-engage01" do
    # cf. test "create_manual"  in harami1129_test.rb

    h1129_prms, assc_prms, hsmdl = _prepare_h1129s1
    assert_equal h1129_prms[:singer][0], hsmdl[:artists][0].title, 'Sanity check...'

    # Modifying some associated records
    hsmdl[:artists][0].update!(sex: Sex[1], birth_year: 1990, birth_month:   5, place: places(:liverpool_street))
    hsmdl[:artists][1].update!(sex: Sex[0], birth_year: 1985, birth_month: nil, place: places(:perth_uk))

    assert_equal 1985, hsmdl[:artists][1].birth_year
    assert_nil hsmdl[:artists][1].birth_day, 'Sanity check...'
    assert                                   hsmdl[:artists][0].wiki_en, 'Sanity check...'
    assert_equal assc_prms[:art_wiki_en][0], hsmdl[:artists][0].wiki_en, 'Sanity check...'
    assert_nil hsmdl[:artists][1].wiki_ja,   'Sanity check...'
    assert_nil hsmdl[:artists][1].birth_day, 'Sanity check...'

    # Initial values
    [0, 1].each do |i|
      %w(sex birth_year birth_month birth_day place wiki_en wiki_ja).each do |ek|
        # e.g., hsmdl[:sexes][0-1],  hsmdl[:places][0-1] 
        hsmdl[ek.pluralize.to_sym] ||= []
        hsmdl[ek.pluralize.to_sym][i] = hsmdl[:artists][i].send ek
      end
    end

    # Modifying Translations
    #
    # Artist0: 1ja, is_orig=ja, different-En     (2ja, 1en)
    # Artist1:      Same ja(0), is_orig=en,  1fr (1ja, 1en, 1fr)
    assert_equal(%w(en en), [0, 1].map{|i| hsmdl[:artists][i].best_translation.langcode}, 'Sanity check...')
    hsmdl[:artists][0].with_translation(title: "オーーア", langcode: "ja", weight: 22, note: "Added dummy Japanese Trans for 0")
    t0_0 = hsmdl[:artists][0].translations.find_by(title: "オーーア")
    hsmdl[:artists][0].with_translation(title: "オアシス", langcode: "ja", note: "Added Japanese Trans for 0")
    t0_1 = hsmdl[:artists][0].translations.find_by(title: "オアシス")
    hsmdl[:artists][1].with_translation(title: "オアシス", langcode: "ja", is_orig: false, weight: 11, note: "Added Japanese Trans for 1")
    t1_1 = hsmdl[:artists][1].translations.find_by(title: "オアシス")  # => will be destroyed
    hsmdl[:artists][0].reset_orig_langcode(t0_1)
    hsmdl[:artists][1].with_translation(title: "Oaiis", langcode: "fr", note: "Added French Trans for 1")
    assert_equal(%w(ja en), [0, 1].map{|i| hsmdl[:artists][i].best_translation.langcode}, 'Sanity check...')

    e1_1 = Engage.create!(artist: hsmdl[:artists][1], music: hsmdl[:musics][1], engage_how: engage_hows(:engage_how_arranger), contribution: 0.55, year: 1999) # Artist engages in a different EngageHow
    e1_2 = Engage.create!(artist: hsmdl[:artists][1], music: musics(:music_light), engage_how: engage_hows(:engage_how_singer_original), contribution: 0.6, year: 1950) # Artist engages in a different Music

    best_tras = [0, 1].map{|i| hsmdl[:artists][i].best_translation}
    trass= [0, 1].map{|i| hsmdl[:artists][i].translations.to_a}  # to_a so that Models are loaded.
    engss= [0, 1].map{|i| hsmdl[:artists][i].engages.to_a}
    assert_equal [3, 3],      trass.map(&:size), 'Sanity check...'
    assert_equal [1, 3],      engss.map(&:size), 'Sanity check...'

    hsmdl[:artists][0].reload
    hsmdl[:artists][1].reload

    hspri = {default: :other, lang_orig: :other, lang_trans: :self, engages: :self, sex: :self, prefecture_place: :self, note: :other}
      # =>Selected: Orig(:other(Specified)), Trans(:self(Def)), engage(:self(Def)), sex(:self(Forced)), birth(:other(Def)), place(:self(Specified)), wiki_en(:self(Forced)), wiki_ja(None)

    ## Run (dryrun) - merging Artists
    hsret = nil
    #ActiveRecord::Base.transaction(requires_new: true) do
      hsret = hsmdl[:artists][0].merge_other(hsmdl[:artists][1], priorities: hspri, save_destroy: false)

      new_art = hsmdl[:artists][0] #.reload  # self not yet saved!
#puts "DEBUG(orig-art901): artist-ID="+new_art.id.to_s

      assert_empty hsret[:destroyed]
      assert_equal 5, hsret[:trans][ :remained].size,    '5 Translations remain (2en, 2ja, fr)'
      assert_equal 4, hsret[:engage][:remained].size
      assert_equal 1, hsret[:trans][ :destroy].size,     '1 Translation  destroyed'
      assert_equal 0, hsret[:engage][:destroy].size
      refute         (hsret.has_key?(:harami_vid_music_assocs) && hsret[:harami_vid_music_assocs]), "keys = #{hsret.keys.inspect} / hvma = #{hsret[:harami_vid_music_assocs].inspect}"

      assert_equal hsret[:trans][:remained].first, hsret[:trans][:original]
      assert_equal best_tras[1],                   hsret[:trans][:original]
      assert_equal h1129_prms[:singer][1],         hsret[:trans][:original].title
      refute  t0_1.db_destroyed?  # db_destroyed? defined in application_record.rb
     #assert  t1_1.db_destroyed?  # not yet destroyed (which may change in future)
      assert_equal t1_1, hsret[:trans][:destroy].first, "Conflicting (non-orig) Translation will be destroyed."

      assert_equal new_art, Engage.find(engss[1][0].id).artist  # Music-s differ; hence Engages are NOT destroyed/merged.
      assert_equal new_art, Engage.find(engss[1][2].id).artist

      assert_equal hsmdl[:sexes][0],       hsret[:sex]
      assert_equal hsmdl[:birth_years][1], hsret[:bday3s][:birth_year]
      assert_equal hsmdl[:birth_months][0],hsret[:bday3s][:birth_month]
      assert_equal hsmdl[:places][0],      hsret[:prefecture_place]
      assert_equal hsmdl[:wiki_ens][0],    hsret[:wiki_en]
      assert_nil                           hsret[:wiki_ja]
      assert_equal hsmdl[:sexes][0],       new_art.sex
      assert_equal hsmdl[:birth_years][1], new_art.birth_year
      assert_equal hsmdl[:birth_months][0],new_art.birth_month
      assert_equal hsmdl[:places][0],      new_art.place
      assert_equal hsmdl[:wiki_ens][0],    new_art.wiki_en
      assert_nil                           new_art.wiki_ja

      #### save! ####

      new_art.merge_save_destroy(hsret[:other], hsret)
      new_art.reload

      assert  hsret[:other].db_destroyed?
      assert  hsret[:other].destroyed?
      assert  t1_1.db_destroyed?

      assert_equal 5, new_art.translations.size,    '4 Translations remain'
      assert_equal 2, new_art.translations.where(langcode: "en").size
      assert_equal 2, new_art.translations.where(langcode: "ja").size
      assert_equal 1, new_art.translations.where(langcode: "fr").size
      assert_equal 4, new_art.engages.size
      assert_equal best_tras[1],           new_art.orig_translation
      assert_equal h1129_prms[:singer][1], new_art.orig_translation.title

      assert_equal hsmdl[:sexes][0],       new_art.sex
      assert_equal hsmdl[:birth_years][1], new_art.birth_year
      assert_equal hsmdl[:birth_months][0],new_art.birth_month
      assert_equal hsmdl[:places][0],      new_art.place
      assert_equal hsmdl[:wiki_ens][0],    new_art.wiki_en
      assert_nil                           new_art.wiki_ja

    ## Prepares for merging Musics

    # Modifying Translations
    #
    # Music0: 0ja, is_orig=en, (0ja, 1en)
    # Music1: 2ja, is_orig=ja, (2ja, 1en)
    hsmdl[:musics][0].reload
    hsmdl[:musics][1].reload
    assert_equal(%w(en en), [0, 1].map{|i| hsmdl[:musics][i].best_translation.langcode}, 'Sanity check...')
    t1_0 = hsmdl[:musics][1].best_translation
    hsmdl[:musics][1].with_translation(title: "ディグジーX", langcode: "ja", is_orig: false, weight: 11, note: "Added Japanese Trans for 1 (not is_orig)")
    t1_1 = hsmdl[:musics][1].translations.find_by(title: "ディグジーX")
    hsmdl[:musics][1].with_translation(title: "ディグジーA", langcode: "ja", is_orig: true, weight: 9, note: "Added Japanese Trans for 1 (is_orig=true)")
    t1_2 = hsmdl[:musics][1].translations.find_by(title: "ディグジーA")
    hsmdl[:musics][1].reset_orig_langcode(t1_2)
    assert_equal(%w(en ja), [0, 1].map{|i| hsmdl[:musics][i].best_translation.langcode}, 'Sanity check...')

    best_tras = [0, 1].map{|i| hsmdl[:musics][i].best_translation}
    mu_trass= [0, 1].map{|i| hsmdl[:musics][i].translations.to_a}  # to_a so that Models are loaded.
    mu_engss= [0, 1].map{|i| hsmdl[:musics][i].engages.to_a}
    assert_equal [1, 3],   mu_trass.map(&:size), 'Sanity check...: '+mu_trass.inspect
    assert_equal [1, 2],   mu_engss.map(&:size), 'Sanity check...: '+mu_engss.inspect
    assert                 mu_engss[1].include?(e1_1), 'Sanity check: should include (EngageHow: Arranger)...'

    hsmdl[:musics][0].reload
    hsmdl[:musics][1].reload

    genre_org = hsmdl[:musics][0].genre
    hspri = {default: :self, engages: :other, genre: :self, year: :other, prefecture_place: :other, note: :other} # i.e., lang_orig: :self, lang_trans: :self, harami_vid_music_assocs: self
      # =>Selected: Orig(:self(Def)), Trans(:self(Def)), engage(:other(Specified)), genre(:other(Forced)), year(:self(Forced)), place(:self(Forced)), note(:other+:self(Concatnated in this order))

    ## Run - merging Musics

    hsret = hsmdl[:musics][0].merge_other(hsmdl[:musics][1], priorities: hspri, save_destroy: true)
    new_mu = hsmdl[:musics][0].reload

    assert  hsret[:other].db_destroyed?
    assert  hsret[:other].destroyed?
    refute  t1_0.db_destroyed?

    assert_equal 4, new_mu.translations.size,    '4 Translations remain'
    assert_equal 2, new_mu.translations.where(langcode: "en").size, "other's EN translation remains b/c is_orig=false"
    assert_equal 2, new_mu.translations.where(langcode: "ja").size
    assert_equal 0, new_mu.translations.where(langcode: "fr").size
    assert_equal 2, new_mu.engages.size, 'should decrease by 1 to become 2'
    assert_equal best_tras[0],           new_mu.orig_translation
    assert_equal h1129_prms[:song][0],   new_mu.orig_translation.title
    assert_equal false,                  new_mu.best_translations[:ja].is_orig

    assert_equal assc_prms[:mu_genre][1],      new_mu.genre
    assert_equal assc_prms[:mu_year][0],       new_mu.year
    assert_equal assc_prms[:mu_place][0],      new_mu.place
    assert_equal [assc_prms[:mu_note][1], assc_prms[:mu_note][0]].join(" "), new_mu.note
    #puts "DEBUG: "+new_mu.inspect  # => #<Music id: 999, year: 1994, place_id: 888, genre_id: 777, note: "mu-note1 mu-note0", created_at...; Translation(id=666/L=2/N=4): "Digsy's Dinner0" (en)>
    #puts "DEBUG: "+Translation.sort(new_mu.translations).inspect  # => #<ActiveRecord::AssociationRelation [#<Translation title: "Digsy's Dinner0", is_orig: true>, #<Translation "ディグジーA", is_orig: false>, #<Translation "ディグジーX">, #<Translation "Digsy's Dinner1">]>
    #  raise ActiveRecord::Rollback, "Force rollback."
    #end
  end # test "merge_other artist trans-engage01" do

  private

  # Prepare Array of Harami1129
  #
  # @example
  #   h1129_prms, assc_prms, hsmdl = _prepare_h1129s1
  #   # hsmdl.keys == %i(h1129s musics artists hvmas engages)
  #
  # @return [Array] h1129_prms(Hash(Array[0..1])), assc_prms(Hash(Array[0..1])), hsmdl(Hash(Array[0..1]))
  def _prepare_h1129s1
    # cf. test "create_manual"  in harami1129_test.rb
    h1129_prms = {
      title:  ["A video 0", "A video 1"],
      singer: ["OasIs", "OasYs"],
      song:   ["Digsy's Dinner0", "Digsy's Dinner1"],
      release_date: [Date.new(2010, 2, 5), Date.new(2011, 3, 6)],
      link_root:    ["youtu.be/oasis_0", "youtu.be/oasis_1"],
      link_time:    [nil, 134],
    }
    assc_prms = {
      eng_year: [1994, nil],
      eng_contribution: [0, 0.9],
      mu_year:  [1994, nil],
      mu_genre: [nil, genres(:genre_classic)],  # Genre.default: Pops (nil means unchange, i.e., Pops)
      mu_place: [places(:unknown_place_liverpool_uk),              places(:unknown_place_unknown_prefecture_uk)],
      mu_note: ['mu-note0', 'mu-note1'],
      art_sex: [Sex[:male], nil],
      art_place: [places(:unknown_place_unknown_prefecture_world), places(:unknown_place_unknown_prefecture_uk)],
      art_birth_year:  [1975, nil],
      art_birth_month: [nil, 11],
      art_birth_day:   [nil, nil],
      art_wiki_en: ["en.wikipedia.org/wiki/Oasis_%28band%29", nil],
      art_wiki_ja: [nil, nil],
      art_note: [nil, nil],
    }

    arprev = []
    arhsin = (0..1).map{|i|
      idr = _get_unique_id_remote(*arprev)   # defined in test_helper.rb
      arprev.push idr
      hs = {
        id_remote: idr,
        last_downloaded_at: DateTime.now-1000,
      }
      h1129_prms.each_pair do |ek, ea|
        hs[ek] = ea[i]
      end
      hs
    }  # Array of Hash

    hsmdl = {
      h1129s: [],
      musics:  [],
      artists: [],
      hvmas: [],
      engages: [],
    }
      
    # Create two Harami1129
    hsmdl[:h1129s] = (0..1).map{|i|
      Harami1129.create_manual!(**(arhsin[i]))
    }

    (0..1).each do |i|
      msg = []
      hsmdl[:h1129s][i].insert_populate(messages: msg, dryrun: false)
      # insert_populate_true_dryrun(messages: [], allow_null_engage: true, dryrun: nil)
    end

    hsmdl[:h1129s].each_with_index do |eh, i|
      hsmdl[:engages][i] = eh.engage
      %w(year contribution).each do |es|
        val = assc_prms[("eng_"+es).to_sym][i]
        hsmdl[:engages][i].update!(es => val) if val
      end
      hsmdl[:musics][i]  = hsmdl[:engages][i].music
      hsmdl[:artists][i] = hsmdl[:engages][i].artist
      hsmdl[:hvmas][i] = eh.harami_vid.harami_vid_music_assocs.find_by(music: hsmdl[:musics][i])

      %w(year genre place note).each do |es|
        val = assc_prms[("mu_"+es).to_sym][i]
        hsmdl[:musics][i].update!(es => val) if val
      end
      %w(sex place birth_year birth_month birth_day wiki_en wiki_ja note).each do |es|
        val = assc_prms[("art_"+es).to_sym][i]
        hsmdl[:artists][i].update!(es => val) if val
      end
    end

    [h1129_prms, assc_prms, hsmdl]
  end
end

