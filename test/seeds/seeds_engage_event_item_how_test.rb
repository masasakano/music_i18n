# coding: utf-8

require 'test_helper'
require(Rails.root.to_s+"/db/seeds/engage_event_item_how.rb")

class SeedsEngageEventItemHowTest < ActiveSupport::TestCase
  setup do
    nt_be4 = Translation.count
    [Harami1129, HaramiVid, EventItem, EngageEventItemHow].each do |eklass|
      eklass.destroy_all
    end
    nt_aft = Translation.count
    assert_operator nt_be4, :>, nt_aft  # 164 -> 139
  end

  test "SeedsEngageEventItemHow.load_seeds" do
    assert_equal 0, EngageEventItemHow.count, "sanity check"
    n_seeds = Seeds::EngageEventItemHow::SEED_DATA.keys.count
    nt_be4 = Translation.count

    n_changed = Seeds::EngageEventItemHow.load_seeds

    nt_aft = Translation.count
    assert_operator 1, :<, n_changed 
    assert_operator(n_seeds*2, :<,  nt_aft-nt_be4, "Change in Translation (EN, JA, some FR)")
    assert_operator(nt_aft-nt_be4, :<=, n_seeds*3)
    assert_operator(n_seeds*3, :<,  n_changed, "Change in EngageEventItemHow and Translation (EN, JA, some FR)")
    assert_operator(n_changed, :<=, n_seeds*4)
    assert_equal n_seeds, EngageEventItemHow.count

    assert_match(/unknown/i, EngageEventItemHow.unknown.title(langcode: :en))
    assert EngageEventItemHow.unknown.unknown?
    assert EngageEventItemHow[/unknown/i].unknown?
    #p EngageEventItemHow.all
  end

  private

end

