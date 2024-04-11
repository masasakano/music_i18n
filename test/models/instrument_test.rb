# coding: utf-8
# == Schema Information
#
# Table name: instruments
#
#  id                                    :bigint           not null, primary key
#  note                                  :text
#  weight(weight for sorting for index.) :float            default(999.0), not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#
# Indexes
#
#  index_instruments_on_weight  (weight)
#
require "test_helper"

class InstrumentTest < ActiveSupport::TestCase
  test "fixtures" do
    tra = translations(:instrument_vocal_en)
    assert_equal "Vocal", tra.title
    assert_equal "en",   tra.langcode
    assert_equal "InstrumentVocalEn", tra.note

    tra = translations(:instrument_vocal_ja)
    assert_equal "ja",   tra.langcode
    assert_equal "歌手", tra.title
    assert_equal 10,       tra.translatable.weight

    tra = translations(:instrument_other_ja)
    assert_equal "その他", tra.title
  end

  test "uniqueness" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  Instrument.create!( note: "") }     # When no entries have the default value, this passes!
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: nil) }
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: "abc") }
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: -4) }
  end
end
