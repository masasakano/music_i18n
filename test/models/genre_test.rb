# == Schema Information
#
# Table name: genres
#
#  id                                        :bigint           not null, primary key
#  note                                      :text
#  weight(Smaller means higher in priority.) :float
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#
require 'test_helper'

class GenreTest < ActiveSupport::TestCase
  test "unknown" do
    assert Genre.unknown
    assert_operator 0, '<', Genre.unknown.id
    obj = Genre[/UnknownGen/i, 'en']
    assert_equal obj, Genre.unknown
    assert obj.unknown?
  end

  test "not_disagree? with unknown" do
    genre = Genre.unknown
    assert_raises(TypeError){ genre.not_disagree?(3) }
    assert     genre.not_disagree?(nil)
    assert_not genre.not_disagree?(nil, allow_nil: false)
    assert     genre.not_disagree?(genres(:genre_classic))
    assert     genre.not_disagree?(genres(:genre_classic), allow_nil: false) 
    assert     genre.not_disagree?(genre)
    assert     genre.not_disagree?(genre, allow_nil: false)
  end

  test "not_disagree? with a significant" do
    genre = genres(:genre_classic)
    assert_raises(TypeError){ genre.not_disagree?(3) }
    assert     genre.not_disagree?(nil)
    assert_not genre.not_disagree?(nil, allow_nil: false)
    assert_not genre.not_disagree?(genres(:genre_pop))
    assert_not genre.not_disagree?(genres(:genre_pop), allow_nil: false) 
    assert     genre.not_disagree?(Genre.unknown)
    assert     genre.not_disagree?(Genre.unknown, allow_nil: false), "Genre.unknown=#{Genre.unknown.inspect}"
  end

  test "uniqueness" do
    unique_weight = Genre.where.not(weight: [nil, Float::INFINITY]).order(weight: :desc).first.weight
    refute_equal Float::INFINITY, unique_weight

    hsin = {langcode: "en", weight: unique_weight+1, title: "for-val03-#{__method__.to_s}", note: "record3"}
    record3 = Genre.create_basic!(**hsin)
    record4 = nil

    hs_base = hsin.merge({weight: record3.weight+1, note: "record4"})
    assert_raises(ActiveRecord::RecordInvalid, "Creation with an identical title should fail, but..."){
      record4 = Genre.create_basic!( **hs_base) }
    assert_raises(ActiveRecord::RecordInvalid, "Creation with an identical title should fail, but..."){
      record4 = Genre.create_basic!(**(hs_base.merge({alt_title: record3.title+"04",}))) }
    assert_raises(ActiveRecord::RecordInvalid, "Creation with an identical alt_title should fail, but..."){
      record4 = Genre.create_basic!(**(hs_base.merge({title: nil, alt_title: record3.title,}))) }
    assert_nothing_raised{
      record4 = Genre.create_basic!(**(hs_base.merge({title: nil, alt_title: record3.title+"-4"}))) }

    assert record4.valid?
    tra = record4.translations.first
    assert tra.valid?

    tra.title = hsin[:title]
    refute tra.valid?
    assert record4.valid?
    assert_nothing_raised{ record4.update!(note: 'something44') }
  end
end
