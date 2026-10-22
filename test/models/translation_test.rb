# coding: utf-8

# == Schema Information
#
# Table name: translations
#
#  id                                  :bigint           not null, primary key
#  alt_romaji                          :text
#  alt_ruby                            :text
#  alt_title                           :text
#  end_year                            :integer
#  is_for_record(Rarely used)          :boolean          default(FALSE), not null
#  is_formal(Most formal for langcode) :boolean
#  is_internal(Internal use only)      :boolean          default(FALSE), not null
#  is_literal(Literan translation)     :boolean          default(FALSE), not null
#  is_official(Ofiicial translation)   :boolean
#  is_orig                             :boolean
#  is_true_name(Person's true name)    :boolean
#  kind                                :string           default("alt"), not null
#  langcode                            :string           not null
#  memo_editor                         :text
#  note                                :text
#  romaji                              :text
#  ruby                                :text
#  start_year                          :integer
#  title                               :text
#  translatable_type                   :string           not null
#  weight                              :float
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  create_user_id                      :bigint
#  sync_translation_id                 :bigint
#  translatable_id                     :bigint           not null
#  update_user_id                      :bigint
#
# Indexes
#
#  index_translations_on_9_cols                                 (translatable_id,translatable_type,langcode,title,alt_title,ruby,alt_ruby,romaji,alt_romaji) UNIQUE
#  index_translations_on_alt_romaji                             (alt_romaji)
#  index_translations_on_alt_ruby                               (alt_ruby)
#  index_translations_on_alt_title                              (alt_title)
#  index_translations_on_create_user_id                         (create_user_id)
#  index_translations_on_create_user_id_and_update_user_id      (create_user_id,update_user_id)
#  index_translations_on_end_year                               (end_year)
#  index_translations_on_is_for_record                          (is_for_record)
#  index_translations_on_is_formal                              (is_formal)
#  index_translations_on_is_internal                            (is_internal)
#  index_translations_on_is_literal                             (is_literal)
#  index_translations_on_is_official                            (is_official)
#  index_translations_on_is_orig                                (is_orig)
#  index_translations_on_is_true_name                           (is_true_name)
#  index_translations_on_kind                                   (kind)
#  index_translations_on_langcode                               (langcode)
#  index_translations_on_memo_editor                            (memo_editor)
#  index_translations_on_note                                   (note)
#  index_translations_on_romaji                                 (romaji)
#  index_translations_on_ruby                                   (ruby)
#  index_translations_on_start_year                             (start_year)
#  index_translations_on_sync_translation_id                    (sync_translation_id) UNIQUE
#  index_translations_on_title                                  (title)
#  index_translations_on_translatable_id                        (translatable_id)
#  index_translations_on_translatable_type                      (translatable_type)
#  index_translations_on_translatable_type_and_translatable_id  (translatable_type,translatable_id)
#  index_translations_on_update_user_id                         (update_user_id)
#  index_translations_on_weight                                 (weight)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id)
#  fk_rails_...  (sync_translation_id => translations.id) ON DELETE => cascade
#  fk_rails_...  (update_user_id => users.id)
#
require 'test_helper'

class TranslationTest < ActiveSupport::TestCase
  setup do
    ## Without this, current_user may(!) exist if you run Controller or Integration tests at the same time.
    # ModuleWhodunnit.whodunnit = nil  # now, moved to test_helper.rb

    @trans_moderator = users(:user_moderator_translation)
    @title_counter = 0
    @sex = Sex[0]
    @artist = Artist.create!(
      orig_locale: nil,
      sex: @sex,
      translations_attributes: [
        {
          title: "Initial Artist Name",
          langcode: "ja",
          is_orig: nil,
          weight: 47.0,
          kind: "full"
        }
      ]
    )
  end

  test "has_many" do
    assert Translation.column_names.include?('translatable_type')
    assert Translation.column_names.include?('translatable_id')
    assert_equal 'Country',            translations(:japan_ja).translatable_type
    assert_equal countries(:japan).id, translations(:japan_ja).translatable_id
    assert_equal 'MyTextJapan',        translations(:japan_ja).translatable.note
    assert_equal 'b@example.com', translations(:japan_en).update_user.email
    assert_nil                    translations(:japan_ja).create_user
    assert_equal 1,               translations(:perth_aus_en).create_user.id
  end

  test "constraints various" do
    collation_name = ApplicationRecord.utf8collation  # "und-x-icu" (more general than "C.UTF-8" (BSD) or "C.utf8" (Linux))
    if /darwin|bsd/i =~ RUBY_PLATFORM
      assert_equal "und-x-icu", collation_name
      loc = "en"
      assert_equal loc+"-x-icu", ApplicationRecord.utf8collation_for(loc)
    end

    t_jp_sql= Translation.select_regex(:title, 'Japan', langcode: 'en', translatable_type: Country, debug_return_sql: true)
    assert_equal("SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Country' AND (\"translations\".\"title\" COLLATE \"#{collation_name}\" = 'Japan')", t_jp_sql)

    t_jp_en = Translation.select_regex(:title, 'Japan', langcode: 'en', translatable_type: Country)[0]
    assert_equal 'Japan',    t_jp_en.title
    assert_equal 'ジャパン', t_jp_en.ruby

    t_jp_en.alt_title = 'JPN'
    t_jp_en.alt_ruby  = 'ジェイピーエヌ'
    t_jp_en.romaji     = 'japan'
    t_jp_en.alt_romaji = 'jeipienu'
    t_jp_en.save!

    hsdef = {
      langcode: 'en',
      title: 'Japan',
      ruby: 'ジャパン',
    }
    hs = hsdef.merge({
      alt_title: 'JPN',
      alt_ruby: 'ジェイピーエヌ',
      romaji: 'japan',
      alt_romaji: 'jeipienu',
    })

    # Unique violation for a set of 7 significant values (langcode, title, alt_title, ruby, etc).
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
      p Translation.create!(translatable_type: "Country", translatable_id: countries(:japan).id, **hs)
    }  # PG::NotNullViolation (though it is caught by Rails validation before passed to the DB)

    t_jp_en.reload
    t_jp_en.alt_title = nil
    t_jp_en.alt_ruby  = nil
    t_jp_en.romaji     = nil
    t_jp_en.alt_romaji = nil
    t_jp_en.save!
    hs = hsdef

    # Rails validation for unique violation for a set of "nil-inclusive" 7 significant values
    assert_raises(ActiveRecord::RecordInvalid){
      p Translation.create!(translatable: countries(:japan), **hs)
    }  # PG::NotNullViolation (ActiveRecord::RecordNotUnique) is NEVER RAISED because the record contains nil (which could be validated with the DB by setting a partial unique indexes in PostgreSQL).

    # Unique violation
    artist = Artist.first
    hsbase = { langcode: "en", translatable: artist }
    tit     = 'Abc'
    alt_tit = 'Xyz'
    trans1 = Translation.create!(title: tit, alt_title: alt_tit, **hsbase)
    # Translation.create!(title: "", alt_title: nil, romaji: "something", **hsbase)  # This combination used to be allowed up to circa v.1.22
    refute Translation.new(title: "", alt_title: nil, romaji: "something", **hsbase).valid?  # This combination is prohibited after circa v.1.22
    assert_raises(ActiveRecord::RecordInvalid){
      Translation.create!(title: tit, alt_title: alt_tit, romaji: "something", **hsbase)
    }
    assert_raises(ActiveRecord::RecordInvalid, "Reverse Translation pair should fail, but..."){
      Translation.create!(title: alt_tit, alt_title: tit, romaji: "different", **hsbase)
    }

#if is_env_set_positive?('TEST_STRICT')  # defined in application_helper.rb
    # nil and empty string "" should be treated as identical.
    trans1.update!(alt_title: nil) 
    assert_raises(ActiveRecord::RecordInvalid, "Reverse Translation pair should fail, but..."){
      Translation.create!(title: "", alt_title: tit, romaji: "different", **hsbase)
    }
#end

    # Unique violation for title-alt_title
    sex1 = Sex[1]
    tit1 = "AbcDef1"
    tit2 = "VwuXyz2"
    art1 = Artist.new(sex: sex1)
    tra1 = art1.translations.build(langcode: "en", is_orig: true, title: tit1, alt_title: tit2, weight: 100)
    art1.save!

    art2 = Artist.new(sex: sex1)
    prms = art1.best_translation.attributes.slice(*%w(langcode is_orig title alt_title))  # copied from Artist-1's translation
    prms[:weight] = 200
    tra2 = Translation.new( prms )
    art2.translations << tra2
    refute art2.valid?, "Identical Translations but weight should be disallowed"

    art2 = Artist.new(sex: sex1)
    tra2 = Translation.new( prms )
    tra2.title     = tit2
    tra2.alt_title = tit1
    art2.translations << tra2
    refute art2.valid?, "Identical Translations except reverse title<->alt_title (and weight) should be disallowed"

    art2 = Artist.new
    tra2 = Translation.new( prms )
    tra2.title     = tit2
    tra2.alt_title = tit1
    art2.sex = Sex[2]
    art2.translations << tra2
    assert art2.valid?, "Should allow, if Sexes differ, identical Translations except reverse title<->alt_title (and weight), but..."
  end

  test "validations" do
    mdl = translations(:gare_lyon_france_fr)
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb

    assert mdl.title.present?, 'checking fixtures'
    mdl.ruby   = "りよんえき"
    assert_equal "リヨンエキ", mdl.ruby  # testing: normalizes

    hs_common = {title: "#{__method__}-1-#{rand}", langcode: "it", kind: Translation::KIND_FULL, weight: 2.0,
                 is_official: true }
    translation = @sex.translations.build(**hs_common)
    assert @sex.valid?

    translation.kind = "naiyo"
    refute @sex.valid?
    assert_equal 1, @sex.errors.size
    assert          @sex.errors.where("translations.kind", :inclusion)  # modern Rails way to test an error

    ## traditional tests...
      assert_equal ActiveRecord::Associations::NestedError, @sex.errors.first.class
      assert_equal :"translations.kind", @sex.errors.first.attribute
      assert_equal :inclusion,           @sex.errors.first.type
      assert_equal "naiyo",              @sex.errors.first.options[:value]
      assert_equal "naiyo",              @sex.errors.first.details[:value]
      assert_includes @sex.errors.first.message,      "is not included in the list"
      assert_includes @sex.errors.first.full_message, "is not included in the list"
      assert @sex.errors["translations.kind"].any? { |msg| msg.include?("is not included in the list") }, @sex.errors.inspect
      assert @sex.errors.messages_for("translations.kind").any? { |msg| msg.include?("is not included in the list") }, @sex.errors.inspect

    translation.kind = Translation::KIND_FULL
    assert @sex.valid?

    translation.is_true_name = true
    refute @sex.valid?, "Translations for Sex should not define is_true_name, but..."
    assert @sex.errors["translations.is_true_name"].any? { |msg| msg.include?("set positive") }, @sex.errors.inspect
    translation.is_true_name = nil
    assert @sex.valid?, "sanity check"
    translation.is_for_record = true
    refute @sex.valid?
    assert @sex.errors["translations.is_for_record"].any? { |msg| msg.include?("set positive") }, @sex.errors.inspect
    translation.is_for_record = false
    assert @sex.valid?, "sanity check"

    translation = @artist.translations.build(**hs_common)
    assert @artist.valid?, "sanity check"

    translation.is_true_name = true
    assert @artist.valid?
    translation.is_for_record = true
    assert @artist.valid?
    assert_difference('Translation.count'){
      @artist.save!
    }
  end

  test "class method preprocessed_6params" do
    hs = {:title => "\tＡi  \u3000", 'alt_title' => " Lｕnch   time", :alt_ruby => "ﾗｼﾞ･ｵ\n"}
    exp= {:title => "Ai", 'alt_title' => "Lunch time", :alt_ruby => "ラジ・オ"}
    assert_equal exp, Translation.send(:preprocessed_6params, **hs)

    tra = Translation.preprocessed_new(**hs)
    [:title, 'alt_title', :alt_ruby].each do |ek|
      assert_equal exp[ek], tra.send(ek), "Failed in (#{ek})"
    end

    hs = {:title => "\tTＨe  Ａi  \u3000", 'alt_title' => " Lｕnch   time", :alt_ruby => "ﾗｼﾞ･ｵ\n"}
    exp= {:title => "Ai, THe", 'alt_title' => "Lunch time", :alt_ruby => "ラジ・オ"}

    tra = Translation.preprocessed_new(**hs)
    assert_not_equal exp[:title], tra.send(:title)
    assert_equal     'THe Ai',    tra.send(:title)
    assert_equal exp['alt_title'], tra.send(:alt_title)

    hs2add = {translatable_type: 'Artist'}
    hs2 = hs.merge(hs2add)
    assert_equal exp.merge(hs2add), Translation.send(:preprocessed_6params, **hs2)
    tra = Translation.preprocessed_new(**hs2)
    assert_equal exp[:title], tra.send(:title)
    assert_equal exp['alt_title'], tra.send(:alt_title)
  end

  test "callbacks with skip_preprocess_callback = true" do
    tra = Translation.preprocessed_new(langcode: 'en', title: "TＨe  Ａi")
    assert_equal "THe Ai", tra.title  # only zenkaku conversion with "the" still being at the head
    tra.translatable = Sex.first
    tra.skip_preprocess_callback = true
    tra.save!
    assert_equal "THe Ai", tra.title  # b/c skip-callback
    tra.preprocess_6params article_to_tail: :check  # "the"=>Tail, b/c of Sex::ARTICLE_TO_TAIL == true
    tra.save!
    assert_equal "Ai, THe", tra.title
  end

  test "callbacks for zenkakku handling" do
    hs = {:title => "\tＡi  \u3000", 'alt_title' => " Lｕnch   time", :alt_ruby => "ﾗｼﾞ･ｵ\n"}
    exp= {:title => "Ai", 'alt_title' => "Lunch time", :alt_ruby => "ラジ・オ"}

    tra = Translation.create!(**(hs.merge({langcode: 'fr', translatable: Sex.first})))
    [:title, 'alt_title', :alt_ruby].each do |ek|
      assert_equal exp[ek], tra.send(ek), "Failed in (#{ek})"
    end

    # validation and update with zenkaku
    tra.title = hs[:title]
    assert_equal     hs[:title], tra.title
    assert tra.valid?
    assert_equal     hs[:title], tra.title
    tra.save!
    assert_not_equal hs[:title], tra.title
    assert_equal    exp[:title], tra.title

    tra.update!(title: hs[:title])
    assert_equal    exp[:title], tra.title
  end

  test "validate asian characters" do
    sex5 = Sex.create!(iso5218: 55)
    tra = Translation.new(title: 'new with あ', langcode: 'en', translatable: sex5)
    assert_not tra.valid?, 'Hiragana should not be allowed for EN, but?'
    tra = Translation.new(title: 'new with 漢字', langcode: 'fr', translatable: sex5)
    assert_not tra.valid?
    tra = Translation.new(alt_title: 'new with 。', langcode: 'it', translatable: sex5)
    assert_not tra.valid?
    tra = Translation.new(title: 'new with 漢字', langcode: 'ja', translatable: sex5)
    assert     tra.valid?
    tra = Translation.new(title: 'new with 漢字', langcode: 'ko', translatable: sex5)
    assert     tra.valid?
    tra = Translation.new(title: 'あ', ruby: 'イロハ漢字', langcode: 'ja', translatable: sex5)
    assert_not tra.valid?
    tra = Translation.new(title: 'あ', romaji: 'aイロハ', langcode: 'ja', translatable: sex5)
    assert_not tra.valid?
  end

  test "create_translations (also testing title)" do
    def_no_role_weight = (Translation::MAX_WEIGHT_LOWEST_ROLE + Translation::MAX_WEIGHT_NO_ROLE)/2  # =15000 # used to be (up to v.2.14.2) Float::INFINITY
    sex5 = Sex.create!(iso5218: 55)
    hs = {
      en: {title: 'new', is_orig: true},
      ja: [{title: '新規', is_orig: false}, {title: 'テスト', is_orig: false, weight: 4},],
    }
    sex5.create_translations!(**hs)
    # sex5.reload  # somehow worked without, but should be ncecessary (upto Ver.0.6)...
    assert_equal 'new', sex5.orig_translation.title
    assert_equal 'new', sex5.title
    ja_trans = sex5.translations_with_lang('ja')
    assert_equal def_no_role_weight, ja_trans.find{|i| '新規' == i.title}.weight, "(NOTE: It seems sometimes current_user is set non-nil while executing this in model-testing and as a result the weight for Translation['新規'] is set less than 4 because the user has a high-rank role! ('setup do' should circumvent it now)): weight=#{ja_trans.find{|i| '新規' == i.title}.weight} User.display_name=#{ModuleWhodunnit.whodunnit.display_name rescue ModuleWhodunnit.whodunnit.inspect}, translations_with_lang('ja'): #{ja_trans.inspect}"
    assert_equal '新規', ja_trans[1].title, "(NOTE: For some reason, incorrect) translations_with_lang('ja'): #{ja_trans.inspect}"
    assert_equal def_no_role_weight, ja_trans[1].weight
    assert_equal 'テスト', sex5.title(langcode: 'ja')

    sex6 = Sex.create!(iso5218: 66)
    assert_raise(ActiveRecord::RecordInvalid, "should be Validation failed: title|alt_title=('new') ('en') already exists in Translation") { #  followed by: [(new, )(ID=1060188813)] for Sex(ID=12)
      sex6.create_translations!(**hs) }

    lalala = "La La La Age"
    hs2 = {
      en: {title: 'The Age', is_orig: true, weight: 1},
      fr: {title: lalala, is_orig: false},
    }
    sex6.create_translations!(**hs2)
    # sex6.reload  # key!!
    bests = sex6.best_translations  # => empty...
    assert_equal "Age, The", Array(bests['en']).compact.first.title
    assert_equal lalala,     Array(bests['fr']).compact.first.title, "special case"
  end

  test "Rails-level unique constraints on title*alt_title" do
    hs = {title: 'male', langcode: 'en', is_orig: false}
    sex6 = Sex.create!(iso5218: 66)
    assert_raises(ActiveRecord::RecordInvalid){
      sex_male = sex6.with_translation(**hs) }

    ntrans_be4 = Translation.count
    assert_nothing_raised{
      sex_male = Sex['male'].with_updated_translation(**hs) }
    assert_raises(ActiveRecord::RecordInvalid){
      sex_male = Sex['male'].with_translation(**hs) }
    assert_raises(ActiveRecord::RecordInvalid){
      sex_male = Sex['male'].with_translation(**(hs.merge({title: nil, alt_title: 'female'}))) }
    assert_equal ntrans_be4, Translation.count
  end

  test "unit-testing Translation.tuple_collate_equal" do
    collation_name = ApplicationRecord.utf8collation  # "und-x-icu" (more general than "C.UTF-8" (BSD) or "C.utf8" (Linux))
    exp = ['"translations"."tit" COLLATE "'+collation_name+'" = ?', "v1"]
    act = Translation.tuple_collate_equal(:tit, "v1", space_sensitive: true)
    assert_equal exp, act
    act = Translation.tuple_collate_equal(["tit", "v1"], space_sensitive: true)
    assert_equal exp, act
    exp = ['"ta"."tit" COLLATE "C" = ?', "v1"]
    act = Translation.tuple_collate_equal({tit: "v1"}, t_alias: "ta", collate_to: "C", space_sensitive: true)
    assert_equal exp, act
    exp = ["REGEXP_REPLACE(\"translations\".\"tit\", '[ -]', '', 'g') COLLATE \"#{collation_name}\" = ?", "v1"]
    act = Translation.tuple_collate_equal(:tit, "v1", space_sensitive: false)
    assert_equal exp, act
  end

  test "Translation.select_regex and matched_string" do
    assert_equal 8, Translation.select_regex(nil, nil, translatable_type: Sex).size
    assert_equal 0, Translation.select_regex([:title, :alt_title, :ruby], 'naiyo', translatable_type: Sex).count

    assert_equal translations(:sextrans1en), Translation.select_regex(:title, 'male', translatable_type: Sex).first
    assert_equal translations(:sextrans1ja), Translation.select_regex(:title, '男', translatable_type: Sex).first
    assert_equal translations(:tokyo_ja), Translation.select_regex(:title, '東京都', translatable_type: Prefecture).first
    out_sql = Translation.select_regex(nil, nil, translatable_type: Sex, debug_return_sql: true)
    assert_equal("SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"translatable_type\" = 'Sex'", out_sql)
    out_sql = Translation.select_regex([:title, :alt_title, :ruby], 'naiyo', translatable_type: Sex, debug_return_sql: true)
    collation_name = ApplicationRecord.utf8collation  # "und-x-icu" (more general than "C.UTF-8" (BSD) or "C.utf8" (Linux))
    # exp="SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"translatable_type\" = 'Sex' AND (\"translations\".\"title\" COLLATE \"#{collation_name}\" = 'naiyo' OR \"translations\".\"alt_title\" COLLATE \"#{collation_name}\" = 'naiyo' OR \"translations\".\"ruby\" COLLATE \"#{collation_name}\" = 'naiyo')"  # Rails-7.1 or earlier
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"translatable_type\" = 'Sex' AND ((\"translations\".\"title\" COLLATE \"#{collation_name}\" = 'naiyo') OR (\"translations\".\"alt_title\" COLLATE \"#{collation_name}\" = 'naiyo') OR (\"translations\".\"ruby\" COLLATE \"#{collation_name}\" = 'naiyo'))"  # Rails-7.2 or later
    assert_equal exp, out_sql

    ## find_by_regex
    trans = Translation.find_by_regex(:all, /naiyo/, translatable_type: Sex)
    assert_nil trans

    female_id = Sex[2].id  # or Sex['female'].id
    trans = Translation.find_by_regex(:all, /aLe/i, langcode: 'en', translatable_type: Sex,
              where: ['id <> ?', female_id])
    assert_equal :title, trans.matched_attribute
    assert_equal 'male', trans.matched_string

    ## select_regex (which does not set matched_string)
    trans = Translation.select_regex(:all, /aLe/i, langcode: 'en', translatable_type: Sex,
              where: ['id <> ?', female_id]).first
    assert_nil           trans.matched_attribute
    assert_raises(HaramiMusicI18n::MultiTranslationError::AmbiguousError){ trans.matched_string } # (kwd, value) must be explicitly specified in Translation#matched_string because matched_attribute has not been defined. Note Translation was likely created by {Translation.select_regex} as opposed to by {Translation.find_by_regex}, which would set matched_attribute.
    assert_equal 'male', trans.matched_string(:all, /aLe/i)
    assert_equal :title, trans.get_matched_attribute(:all, /aLe/i)
    assert_equal :title, trans.set_matched_attribute(:all, /aLe/i)
    assert_equal 'male', trans.matched_string  # Now matched_attribute is set.

    # With Ruby Regexp
    out_sql = Translation.select_regex(:titles, /aLe/i, langcode: 'en', translatable_type: Sex, where: ['id <> ?', female_id], debug_return_sql: true)
    assert_equal(%i(title alt_title), out_sql.keys)
    assert_equal("SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (id <> 2)", out_sql[:title])
    assert_equal(*(out_sql.values))

    # With Postgres Regexp
    out_sql = Translation.select_regex(:titles, /aLe/i, langcode: 'en', translatable_type: Sex, where: ['id <> ?', female_id], sql_regexp: true, debug_return_sql: true)
    # exp="SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (id <> 2) AND (regexp_match(translations.title, 'aLe', 'in') IS NOT NULL OR regexp_match(translations.alt_title, 'aLe', 'in') IS NOT NULL)"  # Rails-7.1 or earlier
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (id <> 2) AND ((regexp_match(translations.title, 'aLe', 'in') IS NOT NULL) OR (regexp_match(translations.alt_title, 'aLe', 'in') IS NOT NULL))"  # Rails-7.2 or later
    assert_equal exp, out_sql
  end

  test "Translation.select_regex for ILIKE" do
    female = Sex[2]
    tra_female = female.translations.where(langcode: "en")

    trans_main_opts   = { langcode: 'en', translatable_type: 'Sex' }
    common_run___opts = trans_main_opts.merge({ sql_regexp: true })
    common_debug_opts = common_run___opts.merge({ debug_return_sql: true })

    ## Exact match
    kwd = "female"
    opts = {exact_match: true, case_sensitive: true}.merge(common_run___opts)
    rela    = Translation.select_regex(:titles, kwd, **opts)
    assert_equal tra_female.ids.sort, rela.ids.sort
    out_sql = Translation.select_regex(:titles, kwd, debug_return_sql: true, **opts)
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND ((\"translations\".\"title\" COLLATE \"und-x-icu\" = '#{kwd}') OR (\"translations\".\"alt_title\" COLLATE \"und-x-icu\" = '#{kwd}'))"  # Rails-7.2 or later
    assert_equal exp, out_sql

    %w(Female fema Fema).each do |kwd|
      rela  = Translation.select_regex(:titles, kwd, **opts)
      assert_empty  rela
    end

    ## Case-insensitive exact match
    kwd = "Female"
    opts = {exact_match: true, case_sensitive: false}.merge(common_run___opts)
    rela    = Translation.select_regex(:titles, kwd, **opts)
    assert_equal tra_female.ids.sort, rela.ids.sort
    out_sql = Translation.select_regex(:titles, kwd, debug_return_sql: true, **opts)
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (\"translations\".\"title\" COLLATE \"und-x-icu\" ILIKE '#{kwd}' OR \"translations\".\"alt_title\" COLLATE \"und-x-icu\" ILIKE '#{kwd}')"  # Rails-8.0 or later
    assert_equal exp, out_sql

    %w(fema Fema).each do |kwd|
      rela  = Translation.select_regex(:titles, kwd, **opts)
      assert_empty  rela
    end

    ## Partial match
    kwd = "fema"
    opts = {exact_match: false, case_sensitive: true}.merge(common_run___opts)
    rela    = Translation.select_regex(:titles, kwd, **opts)
    assert_equal tra_female.ids.sort, rela.ids.sort
    out_sql = Translation.select_regex(:titles, kwd, debug_return_sql: true, **opts)
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (\"translations\".\"title\" COLLATE \"und-x-icu\" LIKE '%#{kwd}%' OR \"translations\".\"alt_title\" COLLATE \"und-x-icu\" LIKE '%#{kwd}%')"  # Rails-8.0 or later
    assert_equal exp, out_sql

    %w(Female Fema).each do |kwd|
      rela  = Translation.select_regex(:titles, kwd, **opts)
      assert_empty  rela
    end

    ## Case-insensitive Partial match
    kwd = "Fema"
    opts = {exact_match: false, case_sensitive: false}.merge(common_run___opts)
    rela    = Translation.select_regex(:titles, kwd, **opts)
    assert_equal tra_female.ids.sort, rela.ids.sort
    out_sql = Translation.select_regex(:titles, kwd, debug_return_sql: true, **opts)
    exp = "SELECT \"translations\".* FROM \"translations\" WHERE \"translations\".\"langcode\" = 'en' AND \"translations\".\"translatable_type\" = 'Sex' AND (\"translations\".\"title\" COLLATE \"und-x-icu\" ILIKE '%#{kwd}%' OR \"translations\".\"alt_title\" COLLATE \"und-x-icu\" ILIKE '%#{kwd}%')"  # Rails-8.0 or later
    assert_equal exp, out_sql

    %w(female emal Female Fema).each do |kwd|
      rela  = Translation.select_regex(:titles, kwd, **opts)
      refute_empty  rela
    end

    ## Case-insensitive Partial match (returning multiple)
    kwd = "aLe"  # should match 'male' and 'female'
    rela = rela_male_female = Translation.select_regex(:titles, kwd, **opts)
    assert_equal 2, rela.count

    ## Space-hyphen-ignored Case-insensitive Partial match (returning multiple)
    kwd = "-a-L e -"  # should match 'male' and 'female'
    rela    = Translation.select_regex(:titles, kwd, space_sensitive: false, **opts)
    assert_equal rela_male_female.ids.sort, rela.ids.sort

    kwd = "NotKnown"
    rela    = Translation.select_regex(:titles, kwd, space_sensitive: false, **opts)
    assert_equal 1,      rela.count
    assert_equal Sex[0], rela.first.translatable, "lack of a space and wrong cases in the search keyword should not affect the result, but..."

    kwd = "Ale"
    parent = Translation.select_regex(:titles, kwd, space_sensitive: false, **opts)
    sq = Translation.find_all_by_affinity([:title, :alt_title, :romaji, :alt_romaji], kwd, parent: parent, order_or_where: :order, debug_return_content_sql: true)
#print "DEBUG:5 \n"
#pp sq
    assert_equal [Sex[1], Sex[2]].map{|i| i.title(langcode: :en)}, parent.order(Arel.sql sq).pluck(:title)

    ActiveRecord::Base.transaction(requires_new: true) do
      tmptit = "ALE"
      tra = Translation.new(title: tmptit, langcode: "en", weight: 100)
      Sex[2].translations << tra
      rela = Translation.find_all_by_affinity([:title, :alt_title, :romaji, :alt_romaji], kwd, order_or_where: :both).where(**trans_main_opts)
      assert_equal 3,      rela.count, rela.inspect
      assert_equal tmptit, rela.pluck(:title).first
    end
  end

  test "Translation.select_partial_str" do
    defopts = {ignore_case: true, translatable_type: Artist}
    proclaimers_en = translations(:artist_proclaimers_en)
    assert_equal "Proclaimers, The", proclaimers_en.title, "Sanity check"
    assert_equal "en",               proclaimers_en.langcode, "Sanity check"
    str = "proc"
    assert_equal 1, Translation.select_partial_str(:title,  "Proclaimers, The", **defopts).count, 'Sanity check for fixtures'
    assert_equal 0, Translation.select_partial_str(:titles, "proclaimers, The", **(defopts.merge({ignore_case: false}))).count, 'ignore_case should ignore, but...'
    male = Sex['male']
    process    = Artist.create_with_orig_translation!({sex: male, note: 'TransModel-temp-creation1'}, translation: {title: "Process, The", langcode: 'en'})  # Artist
    #proc_space = Artist.create_with_orig_translation!({sex: male, note: 'TransModel-temp-creation2'}, translation: {title: "Proc Espace, The", langcode: 'en'})  # Artist
    proc_space = Artist.create_with_orig_translation!({sex: male, note: 'TransModel-temp-creation2'}, translation: {title: "tekitogokko", alt_title: "Proc Espace, The", langcode: 'en'})  # Artist

    str = "proc"
    assert_equal 3, Translation.select_partial_str(:titles, str, **defopts).count

    ### The following is commeted out because
    ### this condition becomes a bit too complicated to test in Rails-7.2, where
    ### a pair of parentheses are introduced for every component in an OR clause in SQL;
    ### i.e., in Rails-7.1 or earlier, it was like "WHERE 1 AND (B = C OR D = E)", but
    ### it is now "WHERE 1 AND ((B = C) OR (D = E))"
    #
    # # checking SQL to confirm the OR clause is enclosed with parentheses
    # # so AND-OR conditions are correct.
    # rela = Translation.select_partial_str(:titles, str, not_clause: {id: [proclaimers_en.id, process.translations.first.id]}, **defopts)
    # str_after_or = /.*?(?=\(regexp_match)/.match(rela.to_sql.sub(/\s+ORDER BY\s.+/m, "")).post_match  # "(regexp_match(translate(title, ' ', ''), 'proc', 'in') IS NOT NULL OR regexp_match(translate(alt_title, ' ', ''), 'proc', 'in') IS NOT NULL)  ORDER BY LEAST(NULLIF(LENGTH(TRIM(title)), 0), NULLIF(LENGTH(TRIM(alt_title)), 0)) ASC NULLS LAST"
    # mat = /(\((?>[^()]+|(\g<1>))*\))/m.match(str_after_or)  # matching strings inside matched parentheses
    # assert_equal str_after_or.length, mat[0].length, "the entier OR clause should be inside the parentheses, but..."
    # assert_equal 1, rela.count, "NOT clause should work, but..."

    str = "pr\u3000oc"
    assert_equal 3, Translation.select_partial_str(:titles, str, **defopts).count
    str = "ＰＲoce"
    assert_equal 2, Translation.select_partial_str(:titles, str, **defopts).count
    str = "The Pro"
    assert_equal 3, Translation.select_partial_str(:titles, str, **defopts).count, "'The Pro' should be converted into /pro.*,the/i"

    str = "Madonna"
    assert_equal 1, Translation.select_partial_str(:titles, str, **defopts).count, "sanity check of fixtures"
    assert_equal 1, Translation.select_partial_str(:titles, [str], **defopts).count
    ary = [str, "The Pro"]
    assert_equal 4, Translation.select_partial_str(:titles, ary, **defopts).count, "Proclaimers + Madonna"

    str = "  ai  "
    assert_operator 1, :<, Translation.select_partial_str(:titles, str, min_en_chars: 0, **defopts).pluck(:title).uniq.size, "sanity check of fixtures #{Translation.select_partial_str(:titles, str, **defopts).pluck(:title).uniq.inspect}" # at least Ai (Ja, En), "Proclaimers, The" 
    assert_operator 1, :<, Translation.select_partial_str(:titles, "Ａi", min_en_chars: 0, **defopts).pluck(:title).uniq.size, "sanity check of fixtures #{Translation.select_partial_str(:titles, str, **defopts).pluck(:title).uniq.inspect}" # at least Ai (Ja, En), "Proclaimers, The" 
    assert_equal 1, Translation.select_partial_str(:titles, str, min_en_chars: 3, **defopts).pluck(:title).uniq.size, "exact match only"
    assert_equal 1, Translation.select_partial_str(:titles, "Ａi", min_en_chars: 3, **defopts).pluck(:title).uniq.size, "exact match only"
    assert_equal 1, Translation.select_partial_str(:titles, str, **defopts).pluck(:title).uniq.size, "Default: exact match only"
  end

  test "Translation.find_all_by_partial_str" do
    parent = Sex.joins(:translations)
    assert_equal [Sex[1], Sex[2]], Translation.find_all_by_partial_str("MALE", parent: parent).to_a
    assert_equal [Sex[1], Sex[2]], Translation.find_all_by_partial_str("MALE", parent: parent).order(iso5218: :desc).to_a
    assert_equal [Sex[1], Sex[2]], Translation.find_all_by_partial_str( "ale", parent: parent).order(iso5218: :desc).to_a
    assert_equal [Sex[2], Sex[1]], Translation.find_all_by_partial_str("MALE", parent: parent).reorder(iso5218: :desc).to_a

    assert_equal [Sex[1], Sex[2]], Translation.find_all_by_partial_str( "ale", parent: parent, best_matches_only: false).to_a
    assert_equal [Sex[1]],         Translation.find_all_by_partial_str("MALE", parent: parent, best_matches_only: true).to_a
    assert_equal [Sex[2]],         Translation.find_all_by_partial_str("MALE", parent: parent).where("iso5218 > ?", 1).to_a  # NOTE: Float (like 1.5) would raise ActiveRecord::StatementInvalid: PG::InvalidTextRepresentation
    assert_equal %w(male female),  Translation.find_all_by_partial_str("MALE", parent: parent).pluck("translations.title")
  end

  test "self.find_all_titles_by_partial_str" do
    ary = Translation.find_all_titles_by_partial_str("male", where: nil)
    assert_equal Sex[1].title(langcode: :en), ary.first
    assert_includes ary, "female"
    ary = Translation.find_all_titles_by_partial_str("male", where: {translatable_type: "Sex"})
    assert_equal Sex[1].title(langcode: :en), ary.first
    assert_includes ary, "female"

    ary = Translation.find_all_titles_by_partial_str("Proclaimers", where: {translatable_type: "Artist"})
    tra_exp = translations(:artist_proclaimers_en)
    tra_exp.update!(alt_title: "Proclaimers")
    assert_equal definite_article_to_head(tra_exp.title), ary.first
    ary = Translation.find_all_titles_by_partial_str("Proclaimers", where: {translatable_type: "Artist"}, definite_article_to_head: false)
    assert_equal tra_exp.title, ary.first
    ary = Translation.find_all_titles_by_partial_str("The Proclaimers", where: {translatable_type: "Artist"}, definite_article_to_head: false)
    assert_equal tra_exp.title, ary.first
    ary = Translation.find_all_titles_by_partial_str("Proclaimers, The", where: {translatable_type: "Artist"}, definite_article_to_head: false)
    assert_equal tra_exp.title, ary.first
  end

  test "update_or_create_regex! (and _by!)" do
    trans_tmpl = translations :artist1_en
    tid = trans_tmpl.id
    translatable_tmpl = trans_tmpl.translatable

    ## Succeed (update)
    hs2pass = %i(langcode translatable).map{ |ek| [ek, trans_tmpl.send(ek)]}.to_h
    tra1 = Translation.update_or_create_regex!(:title, trans_tmpl.title, alt_title: 'Alt01', note: 'test01', **hs2pass)
    tra1 = Translation.update_or_create_regex!(:title, trans_tmpl.title, alt_title: 'Alt01', note: 'test01', **hs2pass)  # update twice! (it failed first due to the hand-made unique constraint...)
    assert_equal tid,      tra1.id
    assert_equal 'Alt01',  tra1.alt_title
    assert_equal 'test01', tra1.note
    tra1 = Translation.update_or_create_regex!(:title, trans_tmpl.title, note: 'Test01', **hs2pass)
    assert_equal 'Test01', tra1.note
    no_change = Translation.update_or_create_regex!(:title, trans_tmpl.title, **hs2pass)
    assert_not no_change.saved_changes?  # Because it is identical with an existing one and cannot be saved.

    ## Succeed (new); search non-existent title
    tra2 = Translation.update_or_create_regex!(:title, 'quelque fre', alt_title: 'Alt02', note: 'test02', langcode: 'fr', translatable: hs2pass[:translatable])
    assert_not_equal tid,  tra2.id
    assert_equal 'quelque fre', tra2.title
    assert_equal 'Alt02',  tra2.alt_title
    assert_equal 'test02', tra2.note
    assert_equal translatable_tmpl, tra2.translatable

    ## Succeed (update); search existent title, update alt_tilte
    tra3 = Translation.update_or_create_regex!(:titles, 'quelque fre', alt_title: 'Alt03', note: 'test03', langcode: 'fr', translatable: hs2pass[:translatable])
    assert_equal tra2.id,  tra3.id
    assert_equal 'quelque fre', tra3.title
    assert_equal 'Alt03',  tra3.alt_title
    assert_equal 'test03', tra3.note
    assert_equal translatable_tmpl, tra3.translatable

    ## Succeed (update); search with title's' (practically alt_title), UPDATE alt_tilte
    tra4 = Translation.update_or_create_regex!(:titles, 'Alt03', title: 'quelque fr4', alt_title: 'Alt04', note: 'test04', langcode: 'fr', translatable: hs2pass[:translatable])
    assert_equal tra2.id,  tra4.id
    assert_equal 'quelque fr4', tra4.title
    assert_equal 'Alt04',  tra4.alt_title
    assert_equal 'test04', tra4.note
    assert_equal translatable_tmpl, tra4.translatable

    ## Succeed (new); search with title's', fail, UPDATE title as the first arg
    tra5 = Translation.update_or_create_regex!(:titles, 'Fran05', alt_title: 'Alt05', note: 'test05', langcode: 'fr', translatable: hs2pass[:translatable])
    assert_not_equal tra2.id,  tra5.id
    assert_equal 'Fran05', tra5.title
    assert_equal 'Alt05',  tra5.alt_title
    assert_equal 'test05', tra5.note
    assert_equal translatable_tmpl, tra5.translatable

    ## Succeed (new); search with title's', fail, UPDATE title with a later arg
    tra6 = Translation.update_or_create_regex!(:titles, 'Fran06', title: 'quelque fr6', alt_title: 'Alt06', note: 'test06', langcode: 'fr', translatable: hs2pass[:translatable])
    assert_not_equal tra2.id,  tra6.id
    assert_equal 'quelque fr6', tra6.title
    assert_equal 'Alt06',  tra6.alt_title
    assert_equal 'test06', tra6.note
    assert_equal translatable_tmpl, tra6.translatable

    ## Succeed (update); search with title's', fail, UPDATE title with a later arg
    tra7 = Translation.update_or_create_regex!(:titles, 'quelque fr6', title: 'quelque fr7', alt_title: 'Alt07', note: 'test07', langcode: 'fr', translatable_id: translatable_tmpl.id, translatable_type: translatable_tmpl.class.name)
    assert_equal tra6.id,  tra7.id
    assert_equal 'quelque fr7', tra7.title
    assert_equal 'Alt07',  tra7.alt_title
    assert_equal 'test07', tra7.note
    assert_equal translatable_tmpl, tra7.translatable

    ## Succeed (create); search with title's' with Regexp, fail, UPDATE tilte with a later arg
    tra8 = Translation.update_or_create_regex!(:titles, /naiyo/, alt_title: 'Alt08', note: 'test08', langcode: 'fr', translatable: hs2pass[:translatable]){ |record|
      record.title = 'quelque fr8'
    }
    assert_not_equal tra6.id,  tra8.id
    assert_equal 'quelque fr8', tra8.title
    assert_equal 'Alt08',  tra8.alt_title
    assert_equal 'test08', tra8.note
    assert_equal translatable_tmpl, tra8.translatable

    assert_raises(HaramiMusicI18n::MultiTranslationError::AmbiguousError){
      p Translation.update_or_create_regex!(:title, 'naiyo', langcode: 'ja') }
    assert_raises(HaramiMusicI18n::MultiTranslationError::AmbiguousError){
      p Translation.update_or_create_regex!(:title, 'naiyo', translatable: hs2pass[:translatable]) }
    assert_raises(ActiveModel::UnknownAttributeError){
      p tra1 = Translation.update_or_create_regex!(:title, trans_tmpl.title, alt_title: 'Alt01', note: 'test01', naiyo: 'err', **hs2pass) }

    ## new
    trb1 = Translation.update_or_create_by!(title: 'this e1', alt_title: 'Alt11', note: 'test11', langcode: 'en', translatable: hs2pass[:translatable])
    assert_equal 'this e1', trb1.title
    assert_equal 'Alt11',  trb1.alt_title
    assert_equal 'test11', trb1.note
    assert_equal translatable_tmpl, trb1.translatable

    ## update
    trb2 = Translation.update_or_create_by!(                 alt_title: 'Alt11', note: 'test12', langcode: 'en', translatable: hs2pass[:translatable])
    assert_equal trb1.id,  trb2.id
    assert_equal 'this e1', trb2.title
    assert_equal 'Alt11',  trb2.alt_title
    assert_equal 'test12', trb2.note
    assert_equal translatable_tmpl, trb2.translatable

    ## new (b/c of combination of title and alt_title) -- this generally violates the uniquness validation, but Artist is an exception because Artist::TRANSLATION_STRICTLY_UNIQUE_TITLES==false
    trb3 = Translation.update_or_create_by!(title: 'this e1', alt_title: 'Alt13', note: 'test13', langcode: 'en', translatable: hs2pass[:translatable])
    assert_not_equal trb1.id,  trb3.id
    assert_equal 'this e1', trb3.title
    assert_equal 'Alt13',  trb3.alt_title
    assert_equal 'test13', trb3.note
    assert_equal translatable_tmpl, trb3.translatable

    ## update (b/c of combination of title and alt_title)
    trb4 = Translation.update_or_create_by!(title: 'this e1', alt_title: 'Alt11', note: 'test14', langcode: 'en', translatable: hs2pass[:translatable])
    assert_equal trb1.id,  trb4.id
    assert_equal 'this e1', trb4.title
    assert_equal 'Alt11',  trb4.alt_title
    assert_equal 'test14', trb4.note
    assert_equal translatable_tmpl, trb4.translatable
  end

  test "titles" do
    uk_title = "United Kingdom of Great Britain and Northern Ireland, the"
    uk_title2= "the United Kingdom of Great Britain and Northern Ireland"
    tra = translations(:uk_en)
    assert_equal [uk_title, 'UK'], tra.titles
    assert_equal uk_title,         tra.title_or_alt
    assert_equal 'UK',             tra.title_or_alt(prefer_alt: true)
    assert_equal [uk_title2,'UK'], tra.titles(      article_to_head: true)
    assert_equal  uk_title2,       tra.title_or_alt(article_to_head: true)
    assert_equal  uk_title2,       tra.translatable.title_or_alt(article_to_head: true, langcode: "en")  # BaseWithTranslation
  end

  test "siblings" do
    tra_ja1 = translations(:music_kampai_ja1)
    tra_en1 = translations(:music_kampai_en1)
    tra_en2 = translations(:music_kampai_en2)
    tra_en3 = translations(:music_kampai_en3)
    tra_en4 = translations(:music_kampai_en4)  # weight=nil (this should come last)
    ar = tra_en1.siblings exclude_self: true
    assert_equal [tra_en3, tra_en2, tra_en4], ar.to_a
    assert_equal [tra_ja1], tra_en1.siblings(langcode: 'ja').to_a
    assert_equal 4, tra_en1.siblings(exclude_self: false).size
    assert_equal 3, tra_en1.siblings(exclude_self: true).size
    assert_equal 3, tra_en1.siblings.size
    assert_equal 4, tra_en1.siblings(:all).size
    assert_equal 4, tra_en1.siblings(langcode: :all).size
    assert_equal 0, tra_ja1.siblings.size
    assert_equal 1, tra_ja1.siblings(exclude_self: false).size
    assert_equal [tra_ja1, 0],              tra_ja1.best_translation_with_weight
    assert_equal [tra_en3, tra_en3.weight], tra_en1.best_translation_with_weight
    assert_equal [tra_ja1, 0],              tra_en1.best_translation_with_weight(locale: 'ja')
    assert_equal [tra_ja1, 0],              tra_en1.best_translation_with_weight(locale: :all)
    tra_ja1.update!(weight: Float::INFINITY)
    assert_equal [tra_ja1, 0],              tra_en1.best_translation_with_weight(locale: :all)
    # assert_equal [tra_ja1, Float::INFINITY],tra_en1.best_translation_with_weight(locale: :all, raw_weight: true)  # `raw_weight` matters only with is_orig=true, which is used only in app/controllers/translations/promotes_controller.rb
  end

  test "valid_main_params?" do
    assert_not Translation.valid_main_params?({})
    assert_not Translation.valid_main_params?({ title: 'abc', 'alt_title' => 'abc', ruby: 'xyz'}) # no langcode
    assert_not Translation.valid_main_params?({langcode: 'ja', romaji: 'vha'})
    assert_not Translation.valid_main_params?({langcode: 'ja', title: '  '})
    assert     Translation.valid_main_params?({langcode: 'ja', title: 'abc'})
    assert     Translation.valid_main_params?({langcode: 'ja', 'alt_title' => 'def'})
    assert     Translation.valid_main_params?({langcode: 'ja', title: 'abc', 'alt_title' => 'def', ruby: 'xyz'})
    assert_not Translation.valid_main_params?({langcode: 'ja', title: 'abc', 'alt_title' => 'abc', ruby: 'xyz'})
    assert     Translation.valid_main_params?({langcode: 'ja', title: 'abc', 'alt_title' => 'abX', ruby: 'xyz'})

    ary = []
    assert_not Translation.new.valid_main_params?(kwd_messages: ary)
    assert_equal 2, ary.size
    assert_equal %i(langcode title), ary.map{|ea| ea[0]}
    assert_match(/\btitle (and|or) alt_?title must exist\b/i, ary.find{|ea| :title == ea[0]}[1])

    tra = Translation.new(langcode: "kr", title: "xyz", alt_title: "xyz")
    ary = []
    assert_not tra.valid_main_params?(kwd_messages: ary)  # kwd_messages => [:base, "message"] etc in general; in this case, :alt_title (to indicate :alt_title was wrong.
    assert_equal 1, ary.size, "ary=#{ary.inspect}"
    kwd = :alt_title
    assert_equal [kwd], ary.map{|ea| ea[0]}
    assert_match(/\bmust differ\b/i, ary.find{|ea| kwd == ea[0]}[1])
  end

  test "of_title" do
    artist_ai = artists :artist_ai
    music_story = musics :music_story
    assert_equal 'Story', music_story.title
    assert_equal 1, Translation.of_title('Story').count
    trans_story1  = Translation.of_title('Story').first
    assert_equal 'Story', trans_story1.title
    assert_equal 1, Translation.of_title(" Story\n", exact: true).count
    assert_equal 1, Translation.of_title(" Ｓtory\n", exact: true).count # zenkaku
    assert_equal 0, Translation.of_title(" story\n", exact: true).count
    assert_equal 1, Translation.of_title(" stORY\n", exact: false, case_sensitive: false).count
    assert_equal 0, Translation.of_title(" story\n", exact: false, case_sensitive: true).count

    # alt_title selection
    tmpalt = 'tmp alt'
    trans_story1.alt_title = tmpalt
    trans_story1.save!
    assert_equal 'Story', Translation.of_title(tmpalt).first.title

    # translatable_type constraint
    Sex.first.translations.create!(langcode: 'XX', title: 'Story')
    assert_equal 2, Translation.of_title('Story').count
    assert_equal 1, Translation.of_title('Story', translatable_type: 'Music').count

    # scoped constraint
    mux = Music.create!()
    mux.translations.create!(langcode: 'XX', title: 'Story')
    mux.translations.create!(langcode: 'en', title: 'Story')
    assert_equal 4, Translation.of_title('Story').count
    assert_equal 3, Translation.of_title('Story', translatable_type: 'Music').count
    assert_equal 2, Translation.of_title('Story', translatable_type: 'Music', langcode: 'en').count
    assert_equal 1, Translation.of_title('Story', scoped: artist_ai.musics.map(&:translations).flatten).count
  end

  test "find_all_by_a_title" do
    assert_raises(ArgumentError){
      p Translation.find_all_by_a_title(:titles, "  ") }
    tras = Translation.find_all_by_a_title(:titles, 'o', translatable_type: Artist)
    assert_operator 1, '<', tras.where(is_orig: true).count  # multiple Artists

    tras = Translation.find_all_by_a_title(:titles, 'x'*70, translatable_type: Artist)
    assert_not tras.exists?
  end

  test "find_by_a_title" do
    key = :title
    value = 'abc'
    exp = "\"translations\".title = 'abc'"
    assert_equal exp, Translation.send(:build_sql_match_one, :exact, key, value)
    exp = "\"translations\".title ILIKE 'abc'"
    assert_equal exp, Translation.send(:build_sql_match_one, :exact_ilike, key, value)
    assert_equal 'regexp_replace("translations".title,', Translation.send(:build_sql_match_one, :include_ilike, key, value+", The").sub(/ .*/, '')
    exp = " ILIKE '%abc%'"
    assert_equal exp, Translation.send(:build_sql_match_one, :include_ilike, key, value+", The")[-14..-1]

    ### DB entry contains 'The'
    tit = 'Proclaimers, The'
    assert_raises(ArgumentError){
      p Translation.find_by_a_title(:titles, "  ") }

    tra = Translation.find_by_a_title(:titles, tit)
    assert_equal tit, tra.title
    assert_equal :exact, tra.match_method

    tra = Translation.find_by_a_title(:titles, tit, accept_match_methods: [:exact_absolute], translatable_type: Artist)
    assert_equal tit, tra.title  # Test of accept_match_methods and method of :exact_absolute
    assert_equal :exact_absolute, tra.match_method

    tra = Translation.find_by_a_title(:titles, 'Proclaimers, THE', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :exact_ilike, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'Proclaimers', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :optional_article_ilike, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'roclaimer', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :include, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'Roclaimer', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :include_ilike, tra.match_method
    assert_equal :title, tra.matched_attribute  ## matched_attribute
    assert_equal tra.title, tra.matched_string  ## matched_string
    tra = Translation.find_by_a_title(:titles, 'Roclaimer', translatable_type: Artist, langcode: 'de')
    assert_nil  tra

    # DB entry does not contain 'The'
    tit = 'John Lennon'
    tra = Translation.find_by_a_title(:titles, tit, translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :exact, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'John LENNON', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :exact_ilike, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'John Lennon, THE', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :optional_article_ilike, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'ennon', translatable_type: Artist)
    assert_equal tit, tra.title
    assert_equal :include, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'ENNON', translatable_type: 'Artist')
    assert_equal tit, tra.title
    assert_equal :include_ilike, tra.match_method

    # accept_match_methods
    acs = [:exact, :exact_ilike]
    opts = {translatable_type: Artist, accept_match_methods: acs}
    tra = Translation.find_by_a_title(:titles, 'John LENNON', **opts)
    assert_equal tit, tra.title
    assert_equal :exact_ilike, tra.match_method
    tra = Translation.find_by_a_title(:titles, 'John Lennon, THE', **opts)
    assert_nil  tra

    # zenkaku and extra spaces
    exp_tr = translations( :artist_ai_en ) # title: 'Ai'
    opts = {translatable_type: Artist}
    tra = Translation.find_by_a_title(:titles, "\tＡi  \u3000", accept_match_methods: [:exact], **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :exact, tra.match_method

    # match_method_from, match_method_upto
    exp_tr = translations( :artist_proclaimers_en ) # title: 'Proclaimers, The'
    assert_raises(ArgumentError){
      p Translation.find_by_a_title(:titles, "Proclaimers", match_method_upto: :naiyo) }

    tra = Translation.find_by_a_title(:titles, "Proclaimers, The", match_method_upto: :exact_ilike, **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :exact,       tra.match_method

    tra = Translation.find_by_a_title(:titles, "proclaimers, the", match_method_upto: :exact_ilike, **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :exact_ilike, tra.match_method

    tra = Translation.find_by_a_title(:titles, "Proclaimers", match_method_upto: :exact_ilike, **opts)
    assert_nil  tra

    tra = Translation.find_by_a_title(:titles, "Proclaimers", match_method_upto: :optional_article_ilike, **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :optional_article_ilike, tra.match_method

    tra = Translation.find_by_a_title(:titles, 'The Proclaimers', match_method_upto: :exact_ilike, **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :exact, tra.match_method

    tra = Translation.find_by_a_title(:titles, 'The Proclaimers', match_method_from: :exact_ilike, match_method_upto: :exact_ilike, **opts)
    assert_equal exp_tr.title, tra.title, "exp_tr=#{exp_tr}, tra=#{tra.inspect}"
    assert_equal :exact_ilike, tra.match_method
  end

  test "forbid an empty string" do
    tra = Translation.new(langcode: 'en', title: "\u3000"+"\n"*2, alt_title: "\t"*4, ruby: "  ")
    tra.translatable = Artist.last
    assert_not tra.valid?

    tra.translatable = nil
    eh = EngageHow.new
    eh.unsaved_translations << tra
    assert_not eh.valid?
  end

  test "last_remaining?" do
    mus1 = Music.create_basic!(title: "tmp music-test1", langcode: "en", is_orig: nil)
    mus1.translations.reset
    tra1 = mus1.translations.first
    assert_equal [tra1], tra1.siblings(:all, exclude_self: false).to_a
    assert_empty tra1.siblings(:all).to_a
    assert tra1.last_remaining?(:all)

    mus1.translations << Translation.new(title: "tmp music-テスト2", langcode: "ja", is_orig: nil)
    mus1.translations.reset
    tra2 = mus1.translations.find_by(langcode: "ja")
    assert_equal [tra2], tra1.siblings(:all).to_a
    tra1.reload
    refute tra1.last_remaining?(:all)
    refute tra2.last_remaining?(:all)
    refute tra2.last_remaining_in_any_languages?

    tra1.destroy!
    assert tra2.last_remaining?(:all)
    assert tra2.last_remaining_in_any_languages?
  end

  test "sort with is_orig" do
    assert_empty Translation.build_sql_order(langcode: nil).grep(/langcode/)

    sex = Sex.create!(iso5218: 99)

    # Creating many so that it would not pick up the right one just by chance.
    ts = []
    (0..9).each do |i|
      ori = ((rand(0..1) == 0) ? false : nil)
      ts[i] = Translation.create!(translatable: sex, langcode: 'en', is_orig: ori, title: 'T'+i.to_s, weight: rand, skip_singularize_is_orig_callback: true)
    end
    ts[10] = Translation.create!(translatable: sex, langcode: 'en', is_orig: true, title: 'T10', weight: rand, skip_singularize_is_orig_callback: true)
    assert ts[10].is_orig
    (11..20).each do |i|
      ori = ((rand(0..1) == 0) ? false : nil)
      ts[i] = Translation.create!(translatable: sex, langcode: 'en', is_orig: ori, title: 'T'+i.to_s, weight: rand, skip_singularize_is_orig_callback: true)
    end
    sex.translations.reset
    assert_equal 21, sex.translations.count
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_equal     ts[10], tra, Translation.sort(sex.translations).pluck(:title, :is_orig, :weight).inspect
    assert_equal     ts[10], Translation.sort(sex.translations).first, Translation.sort(sex.translations).pluck(:title, :is_orig, :weight).inspect
    ## NOTE: the above will become irrelevant once is_orig is removed

    t_alias = "tras"
    tmpjoins = "INNER JOIN translations #{t_alias} ON #{t_alias}.translatable_type = 'Sex' AND #{t_alias}.translatable_id = #{sex.id}"
    assert_raises(ActiveRecord::StatementInvalid){
      ## Test of NOT specifying the table_alias when it is necessary — this should raise an error.
      ActiveRecord::Base.transaction(requires_new: true) do
        # transaction is needed; otherwise raises: ActiveRecord::StatementInvalid: PG::InFailedSqlTransaction: ERROR:  current transaction is aborted, commands ignored until end of transaction block
        Translation.sort(Sex.joins(tmpjoins), langcode: "en").select(:title).first
          # Translation.sort(Sex.joins(tmpjoins), langcode: "en").select(:title).explain  # for debugging
        # ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR:  invalid reference to FROM-clause entry for table "translations"
        # LINE 1: ... AND tras.translatable_id = 10 ORDER BY CASE WHEN translatio...
        #                                                              ^
        # In the PostgreSQL log:
        # 2025-11-02 12:34:12.345 GMT [4544] ERROR:  invalid reference to FROM-clause entry for table "translations" at character 141
        # 2025-11-02 12:34:12.345 GMT [4544] HINT:  Perhaps you meant to reference the table alias "tras".
      end
    }
    res = Translation.sort(Sex.joins(tmpjoins), langcode: "en", t_alias: t_alias)
    assert_equal ts[10].title, res.select(t_alias+".title AS tra_title").limit(1).first.tra_title, "res=#{res.inspect}"

    ActiveRecord::Base.transaction(requires_new: true) do
      # Tests of consider_is_orig and also Array of Translations.
      # temporarily changes ts[10].weight
      ts[10].update!(weight: sex.translations.order(weight: :desc).first.weight+10)
      sex.translations.reset
      assert_equal   ts[10], Translation.sort(sex.translations).first, Translation.sort(sex.translations).pluck(:title, :is_orig, :weight).inspect
      refute_equal   ts[10], (tra1st=Translation.sort(sex.translations, consider_is_orig: false).first)
      assert_equal   ts[10], Translation.sort(ts, consider_is_orig: true).first
      assert_equal   tra1st, Translation.sort(ts, consider_is_orig: false).first
      raise ActiveRecord::Rollback, "Force rollback."
    end
    sex.translations.reset

    # weight
    ts[10].update! is_orig: false, weight: 2
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_not_equal ts[10], tra

    ts[10].update! is_orig: false, weight: 0
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_equal     ts[10], tra

    # infinity and nil weight 
    kampai = musics(:music_kampai)
    entrans = kampai.translations_with_lang(langcode: "en")
    assert_operator entrans.count, :>, 3, 'sanity check'
    kampai_worst = entrans.last
    assert_nil     kampai_worst.weight, 'sanity check'

    # for testing sake, no other weight=nil in the siblings
    kampai_worst.update!(weight: 10e5)
    entrans = kampai.translations_with_lang(langcode: "en")
    assert_operator entrans.second.weight, :<, kampai_worst.weight, 'sanity check'

    ts[21] = Translation.create!(translatable: sex, langcode: 'en', is_orig: nil, title: 'W', weight: Float::INFINITY, skip_singularize_is_orig_callback: true)
    ts[22] = Translation.create!(translatable: sex, langcode: 'en', is_orig: nil, title: 'X', weight: nil, skip_singularize_is_orig_callback: true)
    ts[22].reload
    # assert_equal Float::INFINITY, ts[22].weight, 'NOTE: This only sometimes fails for an unknown reason ("setup do" should circumvent it now). ts[22]='+ts[22].inspect  # because of set_create_user callback
    refute_nil ts[22].weight   # set_create_user callback sets a weight
    refute_equal Float::INFINITY, ts[22].weight, 'NOTE: Used to be Infinity but not anymore. ts[22]='+ts[22].inspect
    ts[22].weight = nil
    ts[22].save!(validate: false)
    # assert_nil ts[22].weight
    assert_operator 0, :<, ts[22].weight
    ts[23] = Translation.create!(translatable: sex, langcode: 'en', is_orig: nil, title: 'Y', weight: nil, skip_singularize_is_orig_callback: true)
    ts[24] = Translation.create!(translatable: sex, langcode: 'en', is_orig: nil, title: 'Z', weight: Float::INFINITY, skip_singularize_is_orig_callback: true)
    t_sibs = ts[20].siblings(exclude_self: false)
    assert_equal 25, t_sibs.count
   #assert_equal ts[22], t_sibs[-1] # X  # *TODO* tests of sorting should be reexamined...
   #assert_equal ts[21], t_sibs[-2] # Y  # *TODO* tests of sorting should be reexamined...
   #assert_equal ts[23], t_sibs[-3] # W  # *TODO* tests of sorting should be reexamined...
   #assert_equal ts[24], t_sibs[-4] # Z  # *TODO* tests of sorting should be reexamined...

    # testing weight=10, Infinity for both is_orig=true
    mus = Music.create!(note: 'new Mu')
    mtras = []
    mtras[0] = Translation.create!(translatable: mus, langcode: 'ja', is_orig: true, title: "日本語音楽00", weight: Float::INFINITY, skip_singularize_is_orig_callback: true)
    mtras[1] = Translation.create!(translatable: mus, langcode: 'ja', is_orig: true, title: "日本語音楽01", weight: 10, skip_singularize_is_orig_callback: true)
    assert_equal mtras[1], Translation.sort(mtras).first


    ############
    # Translation should have "title != alt_title".
    #
    # However, this is actually allowed, partly because
    #   Translation.where('title = alt_title')
    # find a few Countries; e.g., "Canada" in :ja has an identical title and alt_title.
    # At least, at a form level, this should be prohibited...
    ############
    #
    #s = "The RubyRail"
    #tra = Translation.new(langcode: "en", title: s, alt_title: s, translatable: kampai)
    #refute tra.save, "title==alt_title should not be allowed, but... (TODO!)"
    #tra = Translation.new(langcode: "en", title: "The RubyRail", alt_title: "RubyRail, The", translatable: kampai)
    #refute tra.save, "title==alt_title should not be allowed, but..."
  end

  test "ALLOW_IDENTICAL_TITLE_ALT" do
    sex = Sex.create_basic!(iso5218: 999, title: "A・RA・SHI", langcode: "en", is_orig: true)
    sex.translations << (tra=Translation.new(title: "A.Ra.Shi", langcode: "ja", is_orig: false))
    result = nil
    assert_nothing_raised{
      result = tra.update(title: "A・RA・SHI", alt_title:  "A・RA・SHI") }
    refute result
    Sex.const_set(:ALLOW_IDENTICAL_TITLE_ALT, true)
    assert tra.update(title: "A・RA・SHI", alt_title:  "A・RA・SHI")
  end


  # --- Official-Literal Requirements ---
  test "is_official=true permits falsy is_literal" do
    t1 = _build_translation(is_official: true, is_literal: false)
    t2 = _build_translation(is_official: true, is_literal: nil)

    assert t1.valid?, t1.errors.full_messages.join(", ")
    assert t2.valid?, t2.errors.full_messages.join(", ")
  end

  test "is_official=true fails when is_literal is true" do
    translation = _build_translation(is_official: true, is_literal: true)

    assert_not translation.valid?
    assert_includes translation.errors[:is_literal], "must be false or nil when is_official is true"
  end

  # --- "Formal" Requirements ---
  test "is_formal=true passes with valid formal attributes" do
    translation = _build_translation(
      is_formal: true,
      is_official: true,
      is_literal: false,
      kind: "full"
    )

    assert translation.valid?, translation.errors.full_messages.join(", ")
  end

  test "is_formal=true fails when required conditions are violated" do
    translation = _build_translation(
      is_formal: true,
      is_official: false,
      is_literal: true,
      kind: "alt"
    )

    assert_not translation.valid?
    assert_includes translation.errors[:is_official], "must be true when is_formal is true"
    assert_includes translation.errors[:is_literal], "must be false or nil when is_formal is true"
    assert_includes translation.errors[:kind], "must be 'full' when is_formal is true"
  end

  # --- Start Year <= End Year ---
  test "start_year must not be later than end_year" do
    valid_range   = _build_translation(start_year: 2010, end_year: 2020)
    same_year     = _build_translation(start_year: 2020, end_year: 2020)
    invalid_range = _build_translation(start_year: 2021, end_year: 2020)

    assert valid_range.valid?
    assert same_year.valid?

    assert_not invalid_range.valid?
    assert_includes invalid_range.errors[:start_year], "cannot be later than end_year"
  end

  # --- Overlapping Formal Periods ---
  test "rejects overlapping formal periods for the same translatable and language" do
    hscommon = {
      is_formal: true,
      is_official: true,
      is_literal: false,
      kind: "full",
      langcode: "en"
    }

    _build_translation(
      start_year: 2000,
      end_year: 2010,
      **hscommon
    ).save!

    overlapping = _build_translation(
      start_year: 2005,
      end_year: 2015,
      **hscommon
    )

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:is_formal], "period overlaps with another formal translation for the same language"
  end

  test "allows boundary touching where start_year equals previous end_year (switching year)" do
    hscommon = {
      is_formal: true,
      is_official: true,
      is_literal: false,
      kind: "full",
      langcode: "en"
    }

    _build_translation(
      start_year: 2000,
      end_year: 2010,
      **hscommon
    ).save!

    switching = _build_translation(
      start_year: 2010,
      end_year: 2020,
      **hscommon
    )

    assert switching.valid?, switching.errors.full_messages.join(", ")
  end

  test "allows overlapping formal periods when langcodes are different" do
    hscommon = {
      is_formal: true,
      is_official: true,
      is_literal: false,
      kind: "full",
    }

    _build_translation(
      langcode: "en",
      start_year: 2000,
      end_year: 2010,
      **hscommon
    ).save!

    different_lang = _build_translation(
      langcode: "ja",
      start_year: 2005,
      end_year: 2015,
      **hscommon
    )

    assert different_lang.valid?, different_lang.errors.full_messages.join(", ")
  end

  test "def_weight" do
    trans_moderator = users(:user_moderator_translation)
    trans_editor    = users(:user_translator)
    user_syshelper  = users(:user_syshelper)

    assert_operator Role.all.pluck(:weight).max,     :<, Translation::MAX_WEIGHT_NO_ROLE, "sanity-check of constants"
    assert_operator Translation::MAX_WEIGHT_NO_ROLE, :<, Translation::MAX_WEIGHT_USED,    "sanity-check of constants"
    assert_operator Translation::MAX_WEIGHT_USED,    :<, Translation::MAX_WEIGHT_VISIBLE, "sanity-check of constants"

    artist = Artist.new(sex: @sex, orig_locale: "ja")

    weight_init = 50.0
    trass = {
      ja_1:          Translation.new(langcode: "ja", kind: Translation::KIND_FULL, is_orig: true, weight: weight_init, title: "title-ja_1"),
      ja_2:          Translation.new(langcode: "ja", kind: Translation::KIND_FULL, is_orig: false, weight: nil, title: "title-ja_2"),
      ja_internal_1: Translation.new(langcode: "ja", kind: Translation::KIND_ALT, is_orig: false, title: "title-internal_1"),
      ja_record_1:   Translation.new(langcode: "ja", kind: Translation::KIND_ALT, is_orig: false, title: "title-record_1"),
      ja_nickname_1: Translation.new(langcode: "ja", kind: Translation::KIND_NICKNAME, is_orig: false, title: "title-nickname_1"),
      ja_alt_1:      Translation.new(langcode: "ja", kind: Translation::KIND_ALT, is_orig: false, title: "title-alt_1"),
      en_1:          Translation.new(langcode: "en", kind: Translation::KIND_FULL, is_orig: false, weight: nil, title: "title-en_1"),
      en_2:          Translation.new(langcode: "en", kind: Translation::KIND_FULL, is_orig: false, weight: nil, title: "title-en_2"),
      en_alt_1:      Translation.new(langcode: "en", kind: Translation::KIND_ALT,  is_orig: false, weight: nil, title: "title-en_alt_1"),
      en_alt_2:      Translation.new(langcode: "en", kind: Translation::KIND_ALT,  is_orig: false, weight: nil, title: "title-en_alt_2"),
      en_alt_3:      Translation.new(langcode: "en", kind: Translation::KIND_ALT,  is_orig: false, weight: nil, title: "title-en_alt_3"),
      en_alt_4:      Translation.new(langcode: "en", kind: Translation::KIND_ALT,  is_orig: false, weight: nil, title: "title-en_alt_4"),
    }.with_indifferent_access
    trass.each_value do |etra|
      artist.translations << etra
    end

    ## 1. If {#is_internal}=true
    tra1 = trass[:ja_internal_1]
    tra1.is_internal = true
    assert_in_epsilon Translation::MAX_WEIGHT_VISIBLE*1.1, (w=tra1.def_weight(exclude_self: false)), 0.000001
    tra1.weight = w
    # weights(ja): [50(Full), 110000(:internal)]

    ## 2. If {#is_for_record}=true
    tra1 = trass[:ja_record_1]
    tra1.is_internal = true
    tra1.is_for_record = true
#debugger
    assert_in_epsilon Translation::MAX_WEIGHT_VISIBLE*1.2, tra1.def_weight(exclude_self: false), 0.000001
    tra1.is_internal = false
    assert_in_epsilon Translation::MAX_WEIGHT_USED/8*8.2, (w=tra1.def_weight(exclude_self: false)), 0.000001  # 80000+(20000*5-20000)/10
    tra1.weight = w
    # weights(ja): [50(Full), 82000(:record), 110000(:internal)]

    ## 3. If {#kind}=="nickname"
    tra1 = trass[:ja_nickname_1]
    tra1.is_for_record = true
    assert_in_epsilon Translation::MAX_WEIGHT_USED/8*8.4, tra1.def_weight(exclude_self: false), 0.000001
    tra1.is_for_record = false
    assert_in_epsilon Translation::MAX_WEIGHT_NO_ROLE/2*2.6, (w=tra1.def_weight(exclude_self: false)), 0.000001  # 20000+(20000*4-20000)/10
    tra1.weight = w
    # weights(ja): [50(ja_1=Full), 26000(ja_nickname_1), 82000(:record), 110000(:internal)]

    ## 4. Any other's weight should fall between...
    ## 5. if {#langcode}==+translatable.orig_locale+
    ## 5.1. if {#kind}=="full",
    tra1 = trass[:ja_2]
    tra1.is_literal = true  # This should be ignored for original language.
    assert_in_epsilon weight_init*0.8, (w40=tra1.def_weight(exclude_self: false)), 0.000001  # 50*0.8 = 50-100/10 (but 45 should be also fine...)  # regardless of User
    tra1.weight = w40  # == 40
    tra1.is_orig = true          # just to ensure the consistency among in-memory Translation
    trass[:ja_2].is_orig = false # just to ensure the consistency among in-memory Translation
    assert_in_epsilon weight_init*0.8, tra1.def_weight(exclude_self: true),  0.000001
    assert_in_epsilon weight_init*0.6, tra1.def_weight(exclude_self: false), 0.000001
    assert_equal 2, user_syshelper.highest_role_in(RoleCategory[RoleCategory::MNAME_TRANSLATION]).weight, "checking fixuture - for the superior's weight"
    assert             (39..46).cover?(tra1.def_weight(trans_moderator, exclude_self: false))  # =~ 45
    assert         (1.49..1.51).cover?(tra1.def_weight(user_syshelper,  exclude_self: false))
    assert_in_epsilon 1.5,             tra1.def_weight(user_syshelper,  exclude_self: false), 0.000001
    tra1.weight = 2.6
    assert_in_epsilon 2.3, tra1.def_weight(exclude_self: false), 0.000001  # higher than 2 (syshelper's default weight)
    tra1.weight = 1.4
    # assert_in_epsilon 1.2,    tra1.def_weight(exclude_self: false), 0.000001  # higher than 1 (sysadmin's default weight)
    assert  (1.0...1.4).cover?(tra1.def_weight(exclude_self: false))        # higher than 1 (sysadmin's default weight)
    tra1.weight = 0.6
    # assert_in_epsilon 0.3,  tra1.def_weight(exclude_self: false), 0.000001  # 0.5(???) higher than 0 (absolute lower limit)
    assert  (0...0.6).cover?(tra1.def_weight(exclude_self: false))        # higher than 0 (absolute lower limit)
    tra1.weight = 0
    assert_in_epsilon 0.1, tra1.def_weight(exclude_self: false), 0.000001  # Delta of (1-0)/10=0.1 is added.
    tra1.weight = nil
    trass[:ja_2].is_orig = true # just to ensure the consistency among in-memory Translation
    tra1.is_orig = false        # just to ensure the consistency among in-memory Translation
    # weights(ja): [50(ja_1=Full), 26000(ja_nickname_1), 82000(:record), 110000(:internal), nil(ja_2)]

    ## 5.2. if {#kind}=="alt"  / if {#langcode}==+translatable.orig_locale+

    tra1 = trass[:ja_alt_1]
    tra1.is_literal = true  # This should be ignored for original language.
    assert_operator weight_init, :<, tra1.def_weight(exclude_self: false), 0.000001  # => 60 (50+100/10) # regardless of User
    assert_in_epsilon weight_init*1.2, (w60=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # 50*0.8 = 50-100/10 (but 45 should be also fine...)  # regardless of User
    tra1.weight = w60  # == 60
    assert_equal        w60,           tra1.def_weight(exclude_self: true)
    assert_in_epsilon weight_init*1.4, tra1.def_weight(exclude_self: false),  0.000001
    assert           (64...71).cover?( tra1.def_weight(trans_moderator, exclude_self: false))
    assert_in_epsilon weight_init*1.4, tra1.def_weight(user_syshelper,  exclude_self: false),  0.000001  # should be the same for even admin
    tra1.weight = 16000
    assert_in_epsilon 17000, tra1.def_weight(exclude_self: false),  0.000001
    assert_in_epsilon 17000, tra1.def_weight(trans_moderator, exclude_self: false),  0.000001  # should be higher than any existing "alt"
    tra1.weight = Translation::MAX_WEIGHT_USED + 80
    assert_equal w60, tra1.def_weight(exclude_self: false)  # unreasonably high ones should be ignored.
    assert_equal w60, tra1.def_weight(trans_moderator, exclude_self: false)
    tra1.weight = Float::INFINITY
    assert_equal w60, tra1.def_weight(exclude_self: false)  # Infinity should be ignored.
    assert_equal w60, tra1.def_weight(trans_moderator, exclude_self: false)
    tra1.weight = w60
    # weights(ja): [50(ja_1=Full), 60(alt), 26000(ja_nickname_1), 82000(:record), 110000(:internal), nil(ja_2)]

    ## 6. else (i.e., if langcode != translatable.orig_locale (where always lower than (1)(2)(3))
    #  6.1 {#is_literal}=(falsy|true), {#is_official}=(true|falsy), {#kind}==["full", "alt"]
    #  6.2. If {#is_literal}=false,
    #       1. if {#is_official}=true,
    #          and if {#kind}=="full"

    tra1 = trass[:en_1]
    assert_equal Translation::KIND_FULL, tra1.kind, "sanity-check" 
    tra1.is_literal = false
    tra1.is_official = true
    tra1.weight = weight_init
    # weights(ja): [50(en_1=Full), nil, nil, nil]

    w = tra1.def_weight(exclude_self: true)  # firt weight in langcode (b/c exclude_self: true)
    refute_equal 0, w
    assert  (0...Translation::MAX_WEIGHT_NO_ROLE).cover?(w), "Weight=#{w.inspect} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # 15000 = (10000+20000)/2

    # new is_official=true should follow existing ones:
    assert_in_epsilon weight_init*1.2, tra1.def_weight(exclude_self: false), 0.000001  # 50*1.2 = 50+100/10  # regardless of User

    trass[:en_alt_2].weight = (w90=weight_init*1.8)  # =90
    trass[:en_alt_2].is_literal = false
    trass[:en_alt_2].is_official = true
    # weights(ja): [50(en_1=Full), nil, 90(en_alt_2), nil] (all-official)

    trass[:en_alt_2].weight = nil
    trass[:en_alt_1].weight = weight_init/2.0
    trass[:en_alt_1].is_literal = false
    trass[:en_alt_1].is_official = true  # This would contradict tra1's default weight but well accepted
    # weights(ja): [50(en_1=Full;official), 25(en_alt_1;official), nil, nil]

    w = tra1.def_weight(exclude_self: false)
    assert  (weight_init*1.09...Translation::MAX_WEIGHT_NO_ROLE).cover?(w)
    assert  (weight_init*1.09...100                            ).cover?(w)  # existing_max weight 50 falls between 2 (sys-helper's weight) and 100 (Moderator's weight)
    assert_in_epsilon weight_init*1.2, w, 0.000001  # = 50+10
    assert_in_epsilon weight_init*1.2, tra1.def_weight(trans_moderator, exclude_self: false), 0.000001  # = 50+10

    trass[:en_alt_2].weight = (w90=weight_init*1.8)  # =90
    trass[:en_alt_2].is_literal = false
    trass[:en_alt_2].is_official = true
    # weights(ja): [50(en_1=Full), 25(en_alt_1), 90(en_alt_2), nil] (all-official)

    # new is_official=true,kind="full" should not be affected with is_official=true,kind="alt"
    assert_in_epsilon weight_init*1.2, tra1.def_weight(exclude_self: false), 0.000001  # 50*1.2 = 50+100/10  # regardless of User

    ## 6.2.1.2  if {#kind}=="alt"  (AND the same conditions: ({#is_literal}==false && {#is_official}==true))

    tra1 = trass[:en_alt_1]
      # No upper limit so far; i.e., no combination of :alt, either is_literal=true or is_official=false
    assert  (weight_init*1.81...100).cover?(val=tra1.def_weight(exclude_self: false)), "Weight=#{val} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"
    assert_in_epsilon weight_init*1.9, tra1.def_weight(exclude_self: false), 0.000001  # = 95
    assert_in_epsilon weight_init*1.9, tra1.def_weight(trans_moderator, exclude_self: false), 0.000001  # = 95

    trass[:en_alt_3].weight = (w110=weight_init*2.2)  # This weight is the upper limit
    trass[:en_alt_3].is_literal = false
    trass[:en_alt_3].is_official = false  # false !
    # weights(ja): [50(en_1=Full), 25(en_alt_1), 90(en_alt_2), 110(en_alt_3(only-non_official)] (all-official)

    assert  (weight_init*1.9...w110).cover?(w=tra1.def_weight(exclude_self: false)), "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =95 (though 105 would be fine)
    assert  (weight_init*1.9...100).cover?(w=tra1.def_weight(trans_moderator, exclude_self: false))  # =(90+100)/2
    assert_in_epsilon  95, w, 0.000001  # = 50+10

    #  6.2.2 If langcode != translatable.orig_locale && {#is_literal}=false && {#is_official}=false,
    #          and if {#kind}=="full"
    #          1. higher than any ({#is_literal}=false && {#is_official}=true), and
    #          2. if {#kind}=="full",
    #             1. higher than the identical category, but
    #             2. lower than any others.
    #          3. else (i.e., if {#kind}=="alt"),
    #             1. higher than {#kind}=="full" ({#is_literal}=false), but
    # Checking {#kind}=="full"
    tra1 = trass[:en_2]
    trass[:en_alt_1].is_literal  = false
    trass[:en_alt_1].is_official = false
    trass[:en_alt_2].weight = (w70=weight_init*1.4)  # =70
    trass[:en_alt_3].weight = (w130=weight_init*2.6) # =130
    tra1.is_literal = false
    tra1.is_official = false
    tra1.weight = (w120=120)

    w_en_1 = trass[:en_1].weight
    trass[:en_1].weight = 78
    trass[:en_1].is_literal = true
    trass[:en_1].is_official = true  # this literal/official combination is iinvalid, but for testing sake...
    trass[:en_2].weight = nil
    # weights(en): [78(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), nil(en_2/unofficial), 130(en_alt_3(unofficial)]

    assert  (w70...w120).cover?(w=tra1.def_weight(exclude_self: false)), "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =95 (though 105 would be fine)
    assert  (w70...100).cover?(w=tra1.def_weight(trans_moderator, exclude_self: false))  # =(90+100)/2
    assert_in_epsilon  74, w, 0.000001, "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # = 70+10  # Full/unofficial is higher than (is_NOT_literal&&is_official)

    trass[:en_1].weight = w_en_1
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), nil(en_2/unofficial), 130(en_alt_3(only-unofficial)]
    assert  (w70...w120).cover?(w=tra1.def_weight(exclude_self: false)), "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =95 (though 105 would be fine)
    assert  (w70...100).cover?(w=tra1.def_weight(trans_moderator, exclude_self: false))  # =(90+100)/2
    assert_in_epsilon  80, w, 0.000001  # = 70+10  # Full/unofficial is higher than (is_NOT_literal&&is_official)

    ## checking the case with no is_official=true
    assert tra1.translatable.translations.select{_1.langcode == 'en'}.any?{_1.official? && !_1.literal?}, "sanity-check"
    trass[:en_alt_1].is_official = false
    trass[:en_alt_2].is_official = false
    refute tra1.translatable.translations.select{_1.langcode == 'en'}.any?{_1.official? && !_1.literal?}, "sanity-check"
    trass[:en_1].weight = 24
    # weights(ja): [24(en_1=Full/Official/Literal), 25(en_alt_1/unofficial), 70(en_alt_2;unofficial),nil(en_2/unofficial), 130(en_alt_3(unofficial)]
    assert_equal 24, tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).compact.min, "sanity-check"
    assert_in_epsilon 14, (w=tra1.def_weight(                 exclude_self: false)), 0.000001, "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =(50-10)
    assert_in_epsilon 14, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(50-10)

    trass[:en_1].weight = nil
    # weights(en): [nil(en_1=Full/Official/Literal), 25(en_alt_1/unofficial), 70(en_alt_2;unofficial), 120(en_2/unofficial), 130(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 15, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(120+130)/2

    trass[:en_alt_1].is_official = true
    trass[:en_alt_2].is_official = true
    trass[:en_1].weight = w_en_1

    trass[:en_2].weight = 120
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), 130(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 125, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(120+130)/2

    trass[:en_alt_3].is_literal = true
    refute tra1.is_official, "sanity-check"
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), 130(en_alt_3(unofficial/Literal)]

    # Checking {#kind}=="alt"
    tra1 = trass[:en_alt_4]
    trass[:en_alt_4].is_literal  = false
    trass[:en_alt_4].is_official = false
    trass[:en_alt_4].weight = nil
    assert_in_epsilon 125, (w=tra1.def_weight(                 exclude_self: false)), 0.000001, "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =(50-10)
    assert_in_epsilon 125, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(50-10)

    ## checking the case with no is_official=true
    trass[:en_alt_1].is_official = false
    trass[:en_alt_2].is_official = false
    trass[:en_alt_3].is_official = false  # already the case.
    w_en_2  = trass[:en_2].weight
    w_alt_1 = trass[:en_alt_1].weight
    w_alt_2 = trass[:en_alt_2].weight
    w_alt_3 = trass[:en_alt_3].weight
    trass[:en_alt_3].weight = nil
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), nil(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 220, (w=tra1.def_weight(                 exclude_self: false)), 0.000001, "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =(120+10)
    assert_in_epsilon 220, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(120+10)

    trass[:en_2].weight = nil
    trass[:en_alt_1].weight = nil
    trass[:en_alt_2].weight = nil
    # weights(en): [50(en_1=Full/Official/Literal), nil(en_alt_1/official), nil(en_alt_2;official), nil(en_2/unofficial), nil(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 40, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =(120+10)
    trass[:en_alt_1].is_official = true
    trass[:en_alt_2].is_official = true
    trass[:en_2].weight     = w_en_2
    trass[:en_alt_1].weight = w_alt_1
    trass[:en_alt_2].weight = w_alt_2
    trass[:en_alt_3].weight = w_alt_3
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), 130(en_alt_3(unofficial/Literal)]

    ## 6.3. else (i.e., if langcode != translatable.orig_locale && {#is_literal}=true)
    #       1. higher than any {#is_literal}=false,
    #       2. lower than any {#is_literal}=true in the default weight range by User's Translation Role ({Translation.low_high_role_weight_thresholds}).
    #       3. If none satisfies (2), Role's default weight is used, meaning the weight may be neither lowest nor highest, although it will be the lowest among the same Role's Translation with {#is_literal}=true.
    #       4. {#kind}=="full"/"alt" is not considered(!)  (*TODO*)
    #
    trass[:en_alt_4].is_literal = true
    trass[:en_alt_4].is_official = false
    tra1 = trass[:en_alt_4]
#debugger
    assert_in_epsilon 15000, (w=tra1.def_weight(                 exclude_self: false)), 0.000001  # =(120+130)/2
    assert_in_epsilon   125, (w=tra1.def_weight(trans_editor,    exclude_self: false)), 0.000001
    assert_in_epsilon   125, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001

    trass[:en_alt_3].weight = nil
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), nil(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 15000, (w=tra1.def_weight(                 exclude_self: false)), 0.000001  # =(10000+20000)/2
    assert_in_epsilon   500, (w=tra1.def_weight(trans_editor,    exclude_self: false)), 0.000001  # =1000/2
    assert_in_epsilon   500, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =1000/2

    trass[:en_alt_3].weight = 94  # unusually low weight is irrelevant
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 120(en_2/unofficial), 94(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 15000, (w=tra1.def_weight(                 exclude_self: false)), 0.000001  # =(10000+20000)/2
    assert_in_epsilon   500, (w=tra1.def_weight(trans_editor,    exclude_self: false)), 0.000001  # =
    assert_in_epsilon   500, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001  # =

    trass[:en_2].is_literal = true
    trass[:en_2].weight = 130
    # weights(en): [50(en_1=Full/Official/Literal), 25(en_alt_1/official), 70(en_alt_2;official), 130(en_2/unofficial/Literal), 94(en_alt_3(unofficial/Literal)]
    assert_in_epsilon 15000, (w=tra1.def_weight(                 exclude_self: false)), 0.000001  # =(10000+20000)/2
    assert_in_epsilon   115, (w=tra1.def_weight(trans_editor,    exclude_self: false)), 0.000001  # =(100+130)/2  # The code does NOT take into account kind="full"/"alt".  If it does, this result will differ and will be 500!
   #assert_in_epsilon    85, (w=tra1.def_weight(trans_moderator, exclude_self: false)), 0.000001, "Weight=#{w} <=> #{tra1.translatable.translations.select{_1.langcode == 'en'}.map(&:weight).inspect}"  # =(120+10) 
    assert_includes  (83.9...90.1), (w=tra1.def_weight(trans_moderator, exclude_self: false))     # =84  (not sure why...)

    ####
    trass[:en_2].is_literal = false
    trass[:en_alt_3].weight = w_alt_3
    trass[:en_1].is_official = false
    artist.save!  ## should succeed...
    assert_equal trass.size, artist.translations.count
  end

  test "assign_fallback_weight" do
    ModuleWhodunnit.whodunnit = users(:user_translator)
    tra = Translation.new(title: "newtest", langcode: "en", weight: nil, is_orig: nil, is_literal: true, translatable_type: @sex.class.name, translatable_id: @sex.id)
    assert_nil tra.weight
    tra.save!
    assert_equal 500, tra.reload.weight  # Translator's role
    tra.weight = nil
    tra.title = tra.title+"2"
    tra.save!
    assert_equal 500, tra.reload.weight  # on :update
  end

  test "self.range_weight_and_increment" do
    range, increment, nominal_weight = Translation.range_weight_and_increment(120)
    assert_equal (100...1000), range
    assert_in_epsilon 100, increment, 0.00001
    assert_in_epsilon 500, nominal_weight, 0.00001

    range, increment, nominal_weight = Translation.range_weight_and_increment(12000)
    assert_equal (10000...20000), range
    assert_in_epsilon  1000, increment, 0.00001
    assert_in_epsilon 15000, nominal_weight, 0.00001

    range, increment, nominal_weight = Translation.range_weight_and_increment(30000)
    assert_equal (20000...80000), range
    assert_in_epsilon  6000, increment, 0.00001
    assert_in_epsilon 26000, nominal_weight, 0.00001

    range, increment, nominal_weight = Translation.range_weight_and_increment(90000)
    assert_equal (80000...100000), range
    assert_in_epsilon  2000, increment, 0.00001
    assert_in_epsilon 82000, nominal_weight, 0.00001

    range, increment, nominal_weight = Translation.range_weight_and_increment(2500000)
    assert_equal (100000..Float::INFINITY), range  # !exclude_end?  (see Translation::WEIGHT_UPPER_END_RANGES)
    assert_in_epsilon  10000, increment, 0.00001
    assert_in_epsilon 110000, nominal_weight, 0.00001
  end

  test "next_unique_weight" do
    artist = Artist.new(sex: @sex, orig_locale: "ja")
    trass = {
      ja_0: Translation.new(langcode: "ja", kind: Translation::KIND_FULL, is_orig:  true, weight:     0, title: "title-ja_0", is_formal: true),
      ja_1: Translation.new(langcode: "ja", kind: Translation::KIND_ALT,  is_orig: false, weight: 500.0, title: "title-ja_1"),
      ja_2: Translation.new(langcode: "ja", kind: Translation::KIND_ALT,  is_orig: false, weight: 800.0, title: "title-ja_2"),
      ja_inf: Translation.new(langcode: "ja", kind: Translation::KIND_ALT,is_orig: false, weight: Float::INFINITY, title: "title-ja_inf"),
      en_1: Translation.new(langcode: "en", kind: Translation::KIND_FULL, is_orig: false, weight:  50.0, title: "title-en_1"),
    }.with_indifferent_access
    trass.each_value do |etra|
      artist.translations << etra
    end

    etra = trass[:ja_1]
    assert_equal 400, etra.next_unique_weight(400, def_increment: 100, upper_threshold: 10000, try_reference: true)
    assert_equal 450, etra.next_unique_weight(400, def_increment: 100, upper_threshold: 10000, try_reference: false) # b/c weight=500 is attempted, which exists
    assert_equal 500, etra.next_unique_weight(400, def_increment: 100, upper_threshold: 10000, try_reference: false, exclude_self: true)
    assert_equal 410, etra.next_unique_weight(400, def_increment: 100, upper_threshold:   420, try_reference: false)
    assert_equal 900, etra.next_unique_weight(800, def_increment: 100, upper_threshold: Float::INFINITY, try_reference: true) # only 1st try fails.
    assert_equal 850, etra.next_unique_weight(800, def_increment: 100, upper_threshold:   900, try_reference: false)
    assert_equal 850, etra.next_unique_weight(800, def_increment: 100, upper_threshold:   900, try_reference: true) # 2nd try reaches the upper-threshold
    assert_equal 650, etra.next_unique_weight(500, def_increment: 300, upper_threshold: 10000, try_reference: true) # both 500 and 800 unfit
    assert_equal 650, etra.next_unique_weight(500, def_increment: 300, lower_threshold: 500, upper_threshold: 10000, try_reference: true) # an edge case! both 500 and 800 unfit AND lower_threshold agrees with 500
    assert_equal 1100,etra.next_unique_weight(500, def_increment: 300, lower_threshold: 800, upper_threshold: 10000, try_reference: true) # an edge case! both 500 and 800 unfit AND lower_threshold agrees with 800
    assert_equal Translation::MAX_WEIGHT_VISIBLE+300, etra.next_unique_weight(500, def_increment: 300, lower_threshold: Translation::MAX_WEIGHT_VISIBLE, upper_threshold: Float::INFINITY, try_reference: false)  # initial trial value is lower than lower_threshold.
    assert_equal Float::INFINITY, etra.next_unique_weight(Float::INFINITY, def_increment: 300, upper_threshold: 1000, try_reference: true)

    assert_equal 390, etra.next_unique_weight(400, def_increment: -100, lower_threshold: 380,   try_reference: false)
    assert_equal   5, etra.next_unique_weight(  0, def_increment:  -5, lower_threshold: 0, upper_threshold: Float::INFINITY, try_reference: true)
    assert_equal 250, etra.next_unique_weight(  0, def_increment: -500,lower_threshold: 0, upper_threshold: Float::INFINITY, try_reference: true)
    assert_equal 250, etra.next_unique_weight(  0, def_increment: -900,lower_threshold: 0, upper_threshold: Float::INFINITY, try_reference: true)
    assert_equal 950, etra.next_unique_weight(Float::INFINITY, def_increment:  -50, lower_threshold: 0, upper_threshold: 1000, try_reference: true)
    assert_equal 900, etra.next_unique_weight(Float::INFINITY, def_increment: -500, lower_threshold: 0, upper_threshold: 1000, try_reference: true)

    etra = trass[:en_1]
    assert_equal 400, etra.next_unique_weight(400, def_increment: 100, upper_threshold: 10000, try_reference: true)
    assert_equal 500, etra.next_unique_weight(400, def_increment: 100, upper_threshold: 10000, try_reference: false) # b/c langcode differs
    assert_equal  40, etra.next_unique_weight( 50, def_increment: -10, lower_threshold:     1, try_reference: true)
    assert_equal   5, etra.next_unique_weight( 10, def_increment: -90, lower_threshold:     0, try_reference: false) # Unreasonable def_increment is allowed because lower_threshold anyway gives a hard lower limit.
    assert_equal   0, etra.next_unique_weight(  0, def_increment: -90, lower_threshold:     0, try_reference: true)  # an edge case
    assert_equal  25, etra.next_unique_weight(  0, def_increment: -90, lower_threshold:     0, try_reference: false) # Unreasonable def_increment is allowed because lower_threshold anyway gives a hard lower limit.

    tra_it1 = artist.translations.build(title: "naiyo", langcode: "it", kind: Translation::KIND_ALT,
                                        weight: nil, is_internal: true, is_orig: false)
    act = tra_it1.next_unique_weight(0, def_increment: Translation::MAX_WEIGHT_VISIBLE/10.0,
                                     lower_threshold: Translation::MAX_WEIGHT_VISIBLE,
                                     upper_threshold: Float::INFINITY, try_reference: false)
    assert_in_epsilon Translation::MAX_WEIGHT_VISIBLE*1.1, act, 0.000001
    tra_it1.weight = act

    tra_it2 = artist.translations.build(title: "naiyo", langcode: "it", kind: Translation::KIND_ALT,
                                        weight: nil, is_internal: true, is_orig: false)
    act = tra_it1.next_unique_weight(0, def_increment: Translation::MAX_WEIGHT_VISIBLE/10.0,
                                     lower_threshold: Translation::MAX_WEIGHT_VISIBLE,
                                     upper_threshold: Float::INFINITY, try_reference: true)  # try_reference is irrelevant.
    assert_in_epsilon Translation::MAX_WEIGHT_VISIBLE*1.05, act, 0.000001
    tra_it2.weight = act

    existing_max = tra_it1.translatable.translations.select{_1.langcode == tra_it1.langcode}.map(&:weight).compact.reject{_1 == Float::INFINITY}.max
    act = tra_it1.next_unique_weight(existing_max, def_increment: Translation::MAX_WEIGHT_VISIBLE/10.0,
                                     lower_threshold: Translation::MAX_WEIGHT_VISIBLE,
                                     upper_threshold: Float::INFINITY, try_reference: false)
    assert_in_epsilon Translation::MAX_WEIGHT_VISIBLE*1.2, act, 0.000001
  end

  test "validates formal overlap when passing nested attributes on parent Artist" do
    hscommon = {
          langcode: "en",
          is_orig: nil,
          is_formal: true,
          is_official: true,
          is_literal: false,
          kind: "full",
    }
    artist = Artist.new(
      orig_locale: nil,
      sex: @sex,
      translations_attributes: [
        {
          title: "Period 1",
          weight: 2.0,
          start_year: 2000,
          end_year: 2010,
          **hscommon
        },
        {
          title: "Period 2 Overlapping",
          weight: 3.0,
          kind: "full",
          start_year: 2005,
          end_year: 2015,
          **hscommon
        }
      ]
    )

    assert_not artist.valid?
    assert artist.errors["translations.is_formal"].any? { |msg| msg.include?("period overlaps") }
  end

  test "singularize_is_orig callback" do
    sex = Sex.create_basic!(iso5218: 999, title: "abc", langcode: "en", is_orig: true)
    tra_en1 = sex.translations.first
    tra_en1.update!(weight: 100)
    assert_equal "en", sex.orig_locale

    sex.translations << Translation.new(title: "日本語の1", langcode: "ja", is_orig: true, weight: 100)
    tra_ja1 = sex.translations.order(created_at: :desc).first
    assert tra_ja1.is_orig
    assert_equal false, tra_en1.reload.is_orig
    assert_equal "ja", sex.reload.orig_locale

    sex.translations << Translation.new(title: "日本語の2", langcode: "ja", is_orig: true, weight: 90)
    tra_ja2 = sex.translations.order(created_at: :desc).first
    assert tra_ja2.is_orig
    assert_equal false, tra_ja1.reload.is_orig
    assert_equal false, tra_en1.reload.is_orig
    assert_equal "ja", sex.reload.orig_locale

    tra_en1.update!(is_orig: true)
    assert tra_en1.is_orig
    assert_equal false, tra_ja1.reload.is_orig
    assert_equal false, tra_ja2.reload.is_orig
    assert_equal "en", sex.reload.orig_locale

    tra_ja1.update!(is_orig: nil)
    assert_nil tra_en1.reload.is_orig
    assert_nil tra_ja1.reload.is_orig
    assert_nil tra_ja2.reload.is_orig
    assert_nil sex.reload.orig_locale

    tra_ja1.update!(is_orig: true)
    assert_equal false, tra_en1.reload.is_orig
    assert_equal false, tra_ja1.reload.is_orig  # is_orig has to be set true for that with the lowest weight in the langcode.
    assert_equal true,  tra_ja2.reload.is_orig  # This has the lowest weight for langcode=="ja"
    assert_equal "ja", sex.reload.orig_locale

    sex.update!(orig_locale: "en")
    assert_equal true,  tra_en1.reload.is_orig
    assert_equal false, tra_ja1.reload.is_orig
    assert_equal false, tra_ja2.reload.is_orig

    sex.update!(orig_locale: "ja")
    assert_equal false, tra_en1.reload.is_orig
    assert_equal false, tra_ja1.reload.is_orig
    assert_equal true,  tra_ja2.reload.is_orig

    sex.update!(orig_locale: nil)
    assert_nil tra_en1.reload.is_orig
    assert_nil tra_ja1.reload.is_orig
    assert_nil tra_ja2.reload.is_orig

    sex.orig_locale = "pt"
    tra_pt = sex.translations.build(title: "tra_pt", langcode: "pt", is_orig: true)
    refute_predicate sex, :valid?
    # sex.save!
    # assert_equal false, tra_en1.reload.is_orig
    # assert_equal false, tra_ja1.reload.is_orig
    # assert_equal false, tra_ja2.reload.is_orig
    # assert_equal true,  tra_pt.reload.is_orig
  end

  test "save_with_guard" do
    # Should fail on :save, :create, :update
    translatable = Music.last
    tra = Translation.new(langcode: "en", is_orig: true, translatable: translatable)
    tra.title = SecureRandom.alphanumeric(9000)  # Must be a random String because an repetitive String is compressed with PostgreSQL's native TOAST before its BTree-indexing upper-limit validation
    assert_equal false, tra.save
    assert tra.new_record?
    assert tra.errors.any?

    ### DEBUG
    # puts "DEBUG: All errors:"
    # tra.errors.group_by(&:attribute).each do |attribute, ar_errors|
    #   puts "[#{attribute.to_s.upcase}] has #{ar_errors.size} errors/issues:"
    #   ar_errors.each do |error|
    #     puts "  - #{error.message} (Type: :#{error.type})"
    #   end
    # end
    assert tra.errors[:title].present?
    assert  tra.errors.added?(:title, SaveIndexGuard::ERROR_TYPE)
    assert_equal 1, tra.errors.where(:title, SaveIndexGuard::ERROR_TYPE).size  # :index_limit_exceeded
    assert_equal SaveIndexGuard::ERROR_TYPE, tra.errors.where(:title).first.type

    # tests of a combined index for :save
    tra.title  = SecureRandom.alphanumeric(1500)
    tra.romaji = SecureRandom.alphanumeric(1400)
    assert_equal false, tra.save
    assert tra.new_record?
    assert tra.errors.any?
    assert tra.errors.added?(:title, SaveIndexGuard::ERROR_TYPE)
    assert tra.errors[:title].present?
    assert tra.errors[:romaji].blank?

    tra.romaji = SecureRandom.alphanumeric(1600)
    assert_equal false, tra.save
    assert tra.errors.added?(:romaji, SaveIndexGuard::ERROR_TYPE)
    assert tra.errors[:title].blank?
    assert tra.errors[:romaji].present?

    # tests of counting non-ASCII
    tra.title = "あかな"+SecureRandom.alphanumeric(2700)
    tra.romaji = ""
    tra.langcode = "ja"
    assert_equal false, tra.save
    assert tra.new_record?
    assert tra.errors.any?
    assert_raises(ActiveRecord::RecordNotSaved){ tra.save! }
    assert tra.errors[:title].present?

    # :create
    hs = {title: SecureRandom.alphanumeric(9000), langcode: "en", is_orig: true, translatable: translatable}
    tra = Translation.create(**hs)
    assert tra.errors.any?
    assert  tra.errors.added?(:title, SaveIndexGuard::ERROR_TYPE)
    assert tra.new_record?
    assert_raises(ActiveRecord::RecordNotSaved){ Translation.create!(**hs) }

    # :update
    tra = translations(:channel_platform_one_en)
    assert tra.update(note: "sanity check to update Translation")
    refute tra.update(title: SecureRandom.alphanumeric(9000))
    assert_raises(ActiveRecord::RecordNotSaved){ tra.update!(title: SecureRandom.alphanumeric(9000)) }
  end

  test "Rails inflection initializer" do
    mu_ja = I18n.t("Music", locale: :ja)
    mu_ja_plural = mu_ja.pluralize(8, :ja)
    assert_equal mu_ja, mu_ja_plural  # to confirm it is NOT "楽曲s"
    refute_equal "s",   mu_ja_plural
  end


  private
    # Helper method to generate valid Translation instances with unique titles
    def _build_translation(translatable: @artist, **custom_attrs)
      @title_counter += 1
      defaults = {
        translatable: translatable,
        title: "Unique Title #{@title_counter}",
        langcode: "en",
        is_orig: nil,
        weight: 1.0 + @title_counter,
        kind: "alt"
      }
      Translation.new(defaults.merge(custom_attrs))
    end
    private :_build_translation

end

