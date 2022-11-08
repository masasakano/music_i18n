# coding: utf-8

# == Schema Information
#
# Table name: translations
#
#  id                :bigint           not null, primary key
#  alt_romaji        :text
#  alt_ruby          :text
#  alt_title         :text
#  is_orig           :boolean
#  langcode          :string           not null
#  note              :text
#  romaji            :text
#  ruby              :text
#  title             :text
#  translatable_type :string           not null
#  weight            :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  create_user_id    :bigint
#  translatable_id   :bigint           not null
#  update_user_id    :bigint
#
# Indexes
#
#  index_translations_on_9_cols                                 (translatable_id,translatable_type,langcode,title,alt_title,ruby,alt_ruby,romaji,alt_romaji) UNIQUE
#  index_translations_on_create_user_id                         (create_user_id)
#  index_translations_on_create_user_id_and_update_user_id      (create_user_id,update_user_id)
#  index_translations_on_translatable_type_and_translatable_id  (translatable_type,translatable_id)
#  index_translations_on_update_user_id                         (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id)
#  fk_rails_...  (update_user_id => users.id)
#
require 'test_helper'

class TranslationTest < ActiveSupport::TestCase
  test "has_many" do
    assert Translation.column_names.include?('translatable_type')
    assert Translation.column_names.include?('translatable_id')
    assert_equal 'Country',            translations(:japan_ja).translatable_type
    assert_equal countries(:japan).id, translations(:japan_ja).translatable_id
    assert_equal 'MyTextJapan',        translations(:japan_ja).translatable.note
    assert_equal 'b@example.com', translations(:japan_en).update_user.email
    assert_equal 1,               translations(:japan_ja).create_user.id
  end

  test "constraints various" do
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
    assert_equal Float::INFINITY, ja_trans.find{|i| '新規' == i.title}.weight, "(NOTE: It seems sometimes current_user is set non-nil while executing this in model-testing and as a result the weight for Translation['新規'] is set less than 4 because the user has a high-rank role!): weight=#{ja_trans.find{|i| '新規' == i.title}.weight} User.display_name=#{Translation.whodunnit.display_name rescue Translation.whodunnit.inspect}, translations_with_lang('ja'): #{ja_trans.inspect}"
    assert_equal '新規', ja_trans[1].title, "(NOTE: For some reason, incorrect) translations_with_lang('ja'): #{ja_trans.inspect}"
    assert_equal Float::INFINITY, ja_trans[1].weight
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
    assert_equal "Age, The", bests['en'].title
    assert_equal lalala,     bests['fr'].title, "special case"
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

  test "Translation.select_regex and matched_string" do
    assert_equal 8, Translation.select_regex(nil, nil, translatable_type: Sex).size
    assert_equal 0, Translation.select_regex([:title, :alt_title, :ruby], 'naiyo', translatable_type: Sex).count

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
    assert_raises(MultiTranslationError::AmbiguousError){ trans.matched_string } # (kwd, value) must be explicitly specified in Translation#matched_string because matched_attribute has not been defined. Note Translation was likely created by {Translation.select_regex} as opposed to by {Translation.find_by_regex}, which would set matched_attribute.
    assert_equal 'male', trans.matched_string(:all, /aLe/i)
    assert_equal :title, trans.get_matched_attribute(:all, /aLe/i)
    assert_equal :title, trans.set_matched_attribute(:all, /aLe/i)
    assert_equal 'male', trans.matched_string  # Now matched_attribute is set.
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

    # checking SQL to confirm the OR clause is enclosed with parentheses
    # so AND-OR conditions are correct.
    rela = Translation.select_partial_str(:titles, str, not_clause: {id: [proclaimers_en.id, process.translations.first.id]}, **defopts)
    str_after_or = /.*?(?=\(regexp_match)/.match(rela.to_sql).post_match  # "(regexp_match(translate(title, ' ', ''), 'proc', 'in') IS NOT NULL OR regexp_match(translate(alt_title, ' ', ''), 'proc', 'in') IS NOT NULL)"
    mat = /(\((?>[^()]+|(\g<1>))*\))/.match(str_after_or)  # matching strings inside matched parentheses
    assert_equal str_after_or.length, mat[0].length, "the entier OR clause should be inside the parentheses, but..."
    assert_equal 1, rela.count, "NOT clause should work, but..."

    str = "pr\u3000oc"
    assert_equal 3, Translation.select_partial_str(:titles, str, **defopts).count
    str = "ＰＲoce"
    assert_equal 2, Translation.select_partial_str(:titles, str, **defopts).count
    str = "The Pro"
    assert_equal 3, Translation.select_partial_str(:titles, str, **defopts).count, "'The Pro' should be converted into /pro.*,the/i"
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

    assert_raises(MultiTranslationError::AmbiguousError){
      p Translation.update_or_create_regex!(:title, 'naiyo', langcode: 'ja') }
    assert_raises(MultiTranslationError::AmbiguousError){
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

    ## new (b/c of combination of title and alt_title)
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
    assert_equal ['United Kingdom', 'UK'], translations(:uk_en).titles
    assert_equal 'United Kingdom', translations(:uk_en).title_or_alt
    assert_equal 'UK',             translations(:uk_en).title_or_alt(prefer_alt: true)
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
    assert_equal 4, tra_en1.siblings.size
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
    exp = "translations.title = 'abc'"
    assert_equal exp, Translation.send(:build_sql_match_one, :exact, key, value)
    exp = "translations.title ILIKE 'abc'"
    assert_equal exp, Translation.send(:build_sql_match_one, :exact_ilike, key, value)
    assert_equal "regexp_replace(translations.title,", Translation.send(:build_sql_match_one, :include_ilike, key, value+", The").sub(/ .*/, '')
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

  test "sort with is_orig" do
    sex = Sex.create!(iso5218: 99)

    # Creating many so that it would not pick up the right one just by chance.
    ts = []
    (0..9).each do |i|
      ori = ((rand(0..1) == 0) ? false : nil)
      ts[i] = Translation.create!(translatable: sex, langcode: 'en', is_orig: ori, title: 'T'+i.to_s, weight: rand)
    end
    ts[10] = Translation.create!(translatable: sex, langcode: 'en', is_orig: true, title: 'T10', weight: rand)
    (11..20).each do |i|
      ori = ((rand(0..1) == 0) ? false : nil)
      ts[i] = Translation.create!(translatable: sex, langcode: 'en', is_orig: ori, title: 'T'+i.to_s, weight: rand)
    end
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_equal     ts[10], tra

    # weight
    ts[10].update! is_orig: false, weight: 2
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_not_equal ts[10], tra

    ts[10].update! is_orig: false, weight: 0
    tra = Translation.find_by_a_title(:titles, 'T', translatable: sex)
    assert_equal     ts[10], tra
  end
end

