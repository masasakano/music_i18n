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
end

