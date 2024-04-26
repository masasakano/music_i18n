# coding: utf-8

require 'test_helper'

class ModuleGuessPlaceTest < ActiveSupport::TestCase
  include ModuleGuessPlace

  test "guess_place" do
    klass = self.class
    jp_unknown = Place.unknown(country: "JP")

    assert_nil klass.guess_place("naiyo...", def_country: nil, fallback: nil)
    exp = Place.unknown
    assert_equal exp, klass.guess_place("naiyo...", def_country: nil)
    assert_equal countries(:japan), Country.find_by(iso3166_n3_code: 392)
    assert_equal countries(:japan), Country["JPN"]
    exp = jp_unknown
    assert_equal exp, klass.guess_place("naiyo...")

    exp = places(:tocho)
    assert_equal exp, klass.guess_place("東京都庁に行ってきました")

    shimane_ken = prefectures(:shimane)
    shimane_sta = Place.create!(prefecture: shimane_ken).with_translation(title: "島根駅", langcode: "ja", is_orig: true)
    assert_equal countries(:japan), shimane_sta.country
    assert_equal shimane_ken,       shimane_sta.prefecture

    assert_equal jp_unknown, klass.guess_place("さて無人駅で調査")

    exp = Place.unknown(prefecture: prefectures(:kagawa))
    assert_equal exp, klass.guess_place("また香川空港もないんですけど")
  end

  private
end

