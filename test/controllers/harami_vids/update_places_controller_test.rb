# coding: utf-8
require "test_helper"

class HaramiVids::UpdatePlacesControllerTest < ActionDispatch::IntegrationTest
  include HaramiVids::UpdatePlacesHelper # for unit testing

  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "use_cache_test" => true,
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
      "uri_youtube" => "https://www.youtube.com/watch?v=hV_L7BkwioY", # HARAMIchan Zenzenzense; harami1129s(:harami1129_zenzenzense1).link_root
    }.with_indifferent_access)
    @h1129 = harami1129s(:harami1129_zenzenzense1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should patch update" do
    hvid = harami_vids(:harami_vid_paris1)
    pla_orig = hvid.place
    refute pla_orig.unknown?, "fixture sanity check"  # should be places(:montparnasse_france)
    assert_equal 1, hvid.event_items.count, "fixture sanity check" # should be event_items(:event_item: evit_ev_evgr_single_streets)
    evit = hvid.event_items.first
    assert evit.unknown?, "fixture sanity check"
    updated_at_orig = hvid.updated_at

    ## sign_in mandatory
    patch harami_vids_update_place_url(hvid) #, params: { harami_vid: { update_place: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    patch harami_vids_update_place_url(hvid) #, params: { harami_vid: { update_place: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    sign_in @editor_harami

    assert_nil  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    get harami_vid_url(hvid)
    assert_response :success
    assert_includes css_select("dd.item_place").text, "Paris"  # in hvid.place
    assert          css_select("dd.item_place span.harami_vids_update_place").blank?

    assert_no_difference("Music.count*1000 + Artist.count*100 + Engage.count*10 + HaramiVidMusicAssoc.count") do
      assert_no_difference("ArtistMusicPlay.count*1000 + Event.count*100 + EventItem.count*10") do
        assert_no_difference("HaramiVidEventItemAssoc.count*10 + HaramiVid.count*1") do
          assert_no_difference("Translation.count") do
            assert_no_difference("Channel.count") do
              patch harami_vids_update_place_url(hvid)
              assert_response :unprocessable_entity
            end
          end
        end
      end
    end

    hvid.reload
    assert_equal pla_orig,        hvid.place
    assert_equal updated_at_orig, hvid.updated_at

    pla_lyon = places(:gare_lyon_france)
    pla_paris_unknown = places(:unknown_place_prefecture_paris)
    assert pla_paris_unknown.unknown?, "sanity check"
    assert_equal pla_paris_unknown.prefecture, pla_lyon.prefecture, "sanity check"

    # No change if EventItem#place is significant but irrelevant to HaramiVid#place
    evit.update!(place: pla_lyon)
    assert_nil  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    patch harami_vids_update_place_url(hvid)
    assert_response :unprocessable_entity
    hvid.reload
    assert_equal pla_orig,        hvid.place
    assert_equal updated_at_orig, hvid.updated_at

    # No change if EventItem#place is significant but does not belong to Prefecture of HaramiVid#place even if it is unknown.
    pla_tokyo = places(:unknown_place_tokyo_japan)
    hvid.update!(place: pla_tokyo)
    updated_at_ori2 = hvid.updated_at
    assert_nil  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    patch harami_vids_update_place_url(hvid)
    assert_response :unprocessable_entity
    hvid.reload
    assert_equal pla_tokyo,       hvid.place
    assert_equal updated_at_ori2, hvid.updated_at

    # Updated if HaramiVid#place encompasses EventItem#place.
    hvid.update!(place: pla_paris_unknown)
    assert_equal pla_lyon,  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    get harami_vid_url(hvid)
    assert_includes css_select("dd.item_place").text, "Paris"  # in hvid.place
    assert_includes css_select("dd.item_place div.harami_vids_update_place").text, "EventItem"

    patch harami_vids_update_place_url(hvid)
    assert_response :redirect
    assert_redirected_to harami_vids_update_place_url(hvid)
    hvid.reload
    assert_equal pla_lyon,        hvid.place
    assert_operator updated_at_orig, :<, hvid.updated_at

    # Updated if HaramiVid#place encompasses all EventItem#place and all of EventItem#place are the same.
    hvid.update!(place: pla_paris_unknown)
    evit2 = evit.dup
    evit2.update!(machine_title: evit.machine_title+"-2")
    hvid.event_items << evit2
    assert_equal 2, hvid.event_items.count
    assert_equal pla_lyon,  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    get harami_vid_url(hvid)
    assert_includes css_select("dd.item_place").text, "Paris"  # in hvid.place
    assert_includes css_select("dd.item_place div.harami_vids_update_place").text, "EventItem"

    patch harami_vids_update_place_url(hvid)
    assert_response :redirect
    assert_redirected_to harami_vids_update_place_url(hvid)
    hvid.reload
    assert_equal pla_lyon,        hvid.place
    assert_operator updated_at_orig, :<, hvid.updated_at

    # Not updated if HaramiVid#place encompasses all EventItem#place but not all of EventItem#place are the same.
    hvid.update!(place: pla_paris_unknown)
    updated_at_ori3 = hvid.updated_at
    evit2.update!(place: places(:montparnasse_france)) # In same Paris but at a different place from the other EventItem
    refute_equal evit.place,            evit2.place
    assert_equal evit.place.prefecture, evit2.place.prefecture
    assert_nil  get_evit_place_if_need_updating(hvid) # defined in HaramiVids::UpdatePlacesHelper
    get harami_vid_url(hvid)
    assert          css_select("dd.item_place div.harami_vids_update_place").blank?

    patch harami_vids_update_place_url(hvid)
    assert_response :unprocessable_entity
    hvid.reload
    assert_equal pla_paris_unknown,     hvid.place
    assert_equal updated_at_ori3, hvid.updated_at
  end
end
