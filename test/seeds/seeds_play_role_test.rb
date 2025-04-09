# coding: utf-8

require 'test_helper'
require(Rails.root.to_s+"/db/seeds/play_roles.rb")

class SeedsPlayRoleTest < ActiveSupport::TestCase
  setup do
    nt_be4 = Translation.count
    [ArtistMusicPlay, Harami1129, HaramiVid, EventItem, PlayRole].each do |eklass|
      eklass.destroy_all
    end
    nt_aft = Translation.count
    assert_operator nt_be4, :>, nt_aft  # 164 -> 139
  end

  test "SeedsPlayRole.load_seeds" do
    assert_equal 0, PlayRole.count, "sanity check"
    n_seeds = Seeds::PlayRoles::SEED_DATA.keys.count
    nt_be4 = Translation.count

    n_changed = Seeds::PlayRoles.load_seeds

    nt_aft = Translation.count
    assert_operator 1, :<, n_changed 
    assert_operator(n_seeds*2, :<,  nt_aft-nt_be4, "Change in Translation (EN, JA, some FR)")
    assert_operator(nt_aft-nt_be4, :<=, n_seeds*3)
    assert_operator(n_seeds*3, :<,  n_changed, "Change in PlayRole and Translation (EN, JA, some FR)")
    assert_operator(n_changed, :<=, n_seeds*4)
    assert_equal n_seeds, PlayRole.count

    assert_match(/unknown/i, PlayRole.unknown.title(langcode: :en), "(NOTE) For some reason, this fails only sometimes... PlayRole.unknown==#{PlayRole.unknown.inspect}")
    assert PlayRole.unknown.unknown?
    assert PlayRole[/unknown/i].unknown?, "PlayRole[/unknown/i]=#{PlayRole[/unknown/i].inspect}"
    #p PlayRole.all
  end

  private

end

