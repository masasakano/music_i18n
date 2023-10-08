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
    ActiveRecord::Base.transaction do
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

      ## merge Engage for Music
      hsret = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :self)

      assert_equal 2, hsret[:remained].size
      assert_empty    hsret[:destroy]
      assert_equal Engage, hsret[:remained].first.class
      assert_equal 2, hsret[:remained].size
      assert_equal 0, hsret[:destroy].size

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
      hsret = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      assert_equal 2, hsret[:remained].size, "engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 1, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size

      assert_equal hsret[:destroy].first.id, hsmdl[:engages][1].id
      assert_equal  new_time, hsret[:destroy].first.created_at
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
    ActiveRecord::Base.transaction do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1

      # Adjust year for Engage
      new_year = 1945
      hsmdl[:engages][1].update!(year: new_year)

      # Adjust created_at for Engage to destroy eventually
      new_time = DateTime.now - 1000
      hsmdl[:engages][1].update!(created_at: new_time)

      ## merge Engage for Music,  priority: :other
      hsret = hsmdl[:musics][0].send(:_merge_engages, hsmdl[:musics][1], priority: :other)

      assert_equal 2, hsret[:remained].size
      assert_empty    hsret[:destroy]
      assert_equal Engage, hsret[:remained].first.class
      assert_equal 2, hsret[:remained].size
      assert_equal 0, hsret[:destroy].size

      hsmdl[:engages][0].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][0].music
      assert_equal hsmdl[:artists][0], hsmdl[:engages][0].artist, 'Sanity check.'
      hsmdl[:engages][1].reload
      assert_equal hsmdl[:musics][0],  hsmdl[:engages][1].music, 'Engage#music_id should have been merged. eng_id='+hsmdl[:engages].map(&:id).inspect
      assert_equal hsmdl[:artists][1], hsmdl[:engages][1].artist, 'Sanity check. no change.'
      assert_equal assc_prms[:eng_contribution][0], hsmdl[:engages][0].contribution
      assert_equal assc_prms[:eng_year][0],         hsmdl[:engages][0].year  # 1994

      ## Further, merge Engage for Artist  -- this should merge Engage
      hsret = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :other)

      assert_equal 2, hsret[:remained].size, "engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 1, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size

      assert_equal hsret[:destroy].first.id, hsmdl[:engages][1].id
      assert_equal  new_time, hsret[:destroy].first.created_at
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
    ActiveRecord::Base.transaction do
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
      hsret = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      assert_equal 2, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 2, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 0, hsret[:destroy].size

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
    ActiveRecord::Base.transaction do
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
      hsret = hsmdl[:artists][0].send(:_merge_engages, hsmdl[:artists][1], priority: :self)

      assert_equal 3, hsret[:remained].size, "No change in Harami1129 b/c no Engages disappear. engages="+hsret[:remained].inspect
      eng_remains = hsret[:remained].select{|i| "Engage" == i.class.name}
      assert_equal 2, eng_remains.size, "engages="+hsret[:remained].inspect
      assert_equal 1, hsret[:destroy].size

      assert_equal hsmdl[:engages][1].id, hsret[:destroy].first.id
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

    ActiveRecord::Base.transaction do
      hspri = {default: :self, year: :self, note: :self}
      iho1.update!(created_at: DateTime.now)
      iho1.merge_other iho2, priorities: hspri, save_destroy: false
      assert_equal iho1_year_orig, iho1.year, "Test of _merge_overwrite with 'priority: :self'."
      assert_equal iho2_year_orig, iho2.year
      hsarys = iho1.ar_assoc[:harami_vid_music_assocs]
      assert_equal iho1_hvmas_size+iho2_hvmas_size, hsarys[:remained].size+hsarys[:destroy].size, "Failed: #{iho1.ar_assoc[:harami_vid_music_assocs].inspect}"
      assert_equal iho2.created_at, iho1.created_at, "Test of _merge_created_at"
      assert     Music.exists?(iho2.id)
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload

    ## Test of updating "timing" only, where both Musics have a similar HaramiVidMusicAssoc with
    ## a only difference of timing.  A positive timing would be always adopted.
    ActiveRecord::Base.transaction do
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
      iho1.merge_other iho2, priorities: hspri, save_destroy: true

      assert_equal iho1_hvmas_size+iho2_hvmas_size, iho1.ar_assoc[:harami_vid_music_assocs].size, "Failed: #{iho1.ar_assoc[:harami_vid_music_assocs].inspect}"
      
      assert_equal 77, iho1_hvma1.reload.timing
      assert_not Music.exists?(iho2.id)
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload

    ActiveRecord::Base.transaction do
      hspri = {default: :other, year: :other, note: :other}
      iho1.merge_other iho2, priorities: hspri
      assert_equal iho2.year,      iho1.year, "Test of priority: :other."
      assert_equal iho2_year_orig, iho2.year
      raise ActiveRecord::Rollback, "Force rollback."
    end
    iho1.reload
    iho2.reload
  end

  test "merge_other trans-engage" do
    # cf. test "create_manual"  in harami1129_test.rb

    ActiveRecord::Base.transaction do
      h1129_prms, assc_prms, hsmdl = _prepare_h1129s1
      assert_equal Place.unknown, hsmdl[:artists][0].place, 'Sanity check...'

      ActiveRecord::Base.transaction do
        genre_org = hsmdl[:musics][0].genre
        hspri = {default: :other, year: :other, note: :other}
        hsmdl[:musics][0].merge_other(hsmdl[:musics][1], priorities: hspri, save_destroy: true)

        assert_equal assc_prms[:mu_year][0],  hsmdl[:musics][0].year
#### Check out!
        hsmdl[:musics][0].reload
        assert_equal genre_org,               hsmdl[:musics][0].genre
        raise ActiveRecord::Rollback, "Force rollback."
      end

      raise ActiveRecord::Rollback, "Force rollback."
    end
  end

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
      mu_genre: [nil, Genre.default],  # Default genre: Pops (nil means unchange, i.e., Pops)  genres(:genre_classic)
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
      hsmdl[:hvmas][i] = eh.harami_vid.musics.find(hsmdl[:musics][i].id)

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

