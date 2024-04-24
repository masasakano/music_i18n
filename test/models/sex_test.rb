# coding: utf-8

# == Schema Information
#
# Table name: sexes
#
#  id         :bigint           not null, primary key
#  iso5218    :integer          not null
#  note       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sexes_on_iso5218  (iso5218) UNIQUE
#
require 'test_helper'

class SexTest < ActiveSupport::TestCase
  test "has_many" do
    sex1 = Sex.find(1)
    assert_equal 1,        sex1.iso5218
    assert_equal 1,        sex1.translations.where(langcode: 'ja').size
    sex1_word = sex1.orig_translation
    assert_equal 'male',   sex1.title
    assert_equal '男',     sex1.title(langcode: 'ja')
    assert_equal 'オンナ', Sex.find(2).translations.where(langcode: 'ja')[0].ruby
    assert_equal sex1, Sex['male', 'en']
    assert_equal sex1, Sex[:male]
    assert_equal Sex.find_by(iso5218: 0), Sex[:unknown]
    assert_equal Sex.find_by(iso5218: 2), Sex[:female]
    assert_raises(ArgumentError){
      p Sex[:naiyo] }
  end

  test "non-null" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){
      Sex.create!(note: nil) }  # PG::NotNullViolation => Rails: "Validation failed: Iso5218 can't be blank"
  end

  test "unique" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ Sex.create!(iso5218: 1) }  # PG::UniqueViolation => "Validation failed: Iso5218 has already been taken"
    
    tit = 'a new gender'
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ Sex.create_with_orig_translation!({iso5218: 1}, translation: {title: tit, langcode: 'en'}) }
    bwt_new = Sex.create_with_orig_translation!({iso5218: 999}, translation: {title: tit, langcode: 'en'})
    assert_equal tit, bwt_new.title

    male = Sex.where(iso5218: 1).first
    title_existing = male.best_translations['en']
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, "Title should be unique."){
      Sex.create_with_orig_translation!({iso5218: 1}, translation: {title: title_existing, langcode: 'en'}) }
  end

  test "index_boss" do
    sex0 = sexes(:sex0)
    sex1 = sexes(:sex1)
    sex2 = sexes(:sex2)
    sex9 = sexes(:sex9)

    cd = Sex.index_boss([sex0, sex9, sex0, nil])
    assert cd.disabled?
    assert_equal 1, cd.checked_index

    cd = Sex.index_boss([sex0, sex0, sex1, sex2])
    refute cd.disabled?
    assert_equal 2, cd.checked_index

    assert_nil Sex.index_boss([sex0, sex0])
  end

  test "not_disagree?" do
    [:unknown, 9].each do |i_first|  # unknown: iso5218=0
      sex = Sex[i_first]
      assert_raises(TypeError){ sex.not_disagree?(3) }
      assert     sex.not_disagree?(nil)
      assert_not sex.not_disagree?(nil, allow_nil: false)
      [:unknown, :male, :female, 9].each do |i|
        assert     sex.not_disagree?(Sex[i])
        assert     sex.not_disagree?(Sex[i], allow_nil: false)
      end
    end

    sex = Sex[:male]
    [:unknown, :male, 9].each do |i|
      assert     sex.not_disagree?(Sex[i])
      assert     sex.not_disagree?(Sex[i], allow_nil: false)
    end
    assert_not sex.not_disagree?(Sex[:female])
  end

  test "create_basic!" do
    mdl = nil
    assert_nothing_raised{
      mdl = Sex.create_basic!}
    assert_match(/^Sex\-basic\-/, mdl.title)
  end
end

