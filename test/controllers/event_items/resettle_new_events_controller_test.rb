# coding: utf-8
require "test_helper"

# == NOTE
#
class EventItems::ResettleNewEventsControllerTest < ActionDispatch::IntegrationTest
  include ModuleYoutubeApiAux  # for unit testing

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
    @css_assoc_event = "span.associate_to_new_event"
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get update" do
    # See /test/models/harami1129_test.rb
    # Creating HaramiVid AND EventItem to ensure they are in 1-to-1 relation.
    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid
    assert_equal 1, hvid.event_items.count
    hvid.update!(duration: 4.minutes.in_seconds)

    evit = hvid.event_items.first
    mtitle_orig = evit.machine_title
    ev_orig = evit.event

    pla_new = places(:takamatsu_station)
    pla_new_unknown = places(:unknown_place_kagawa_japan)
    assert_equal pla_new.prefecture, pla_new_unknown.prefecture, 'sanity check of fixtures'
    assert       pla_new_unknown.unknown?, 'sanity check'
    hvid.update!(place: pla_new_unknown)  # New place is set.
    evit.update!(place: pla_new)          # New place is set.

    ## sign_in mandatory
    patch event_items_resettle_new_event_url(evit)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "should not be displayed but..."
    get event_item_path(evit)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "should not be displayed but..."

    patch event_items_resettle_new_event_url(evit)  #, params: { { } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    sign_in @editor_harami

    # Displayed Button-like link
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 1}, "Text: #{css_select(@css_assoc_event).to_s}"  # another option for the hash: {text: "XXX is not specified."}
    get event_item_path(evit)
    assert_response :success
    assert_select @css_assoc_event, {count: 1}, "Text: #{css_select(@css_assoc_event).to_s}"  # another option for the hash: {text: "XXX is not specified."}

    # Run...
    assert_no_difference("ArtistMusicPlay.count + HaramiVidEventItemAssoc.count") do
      assert_difference("HaramiVid.count*100 + Event.count*10 + EventItem.count", 11, "should create an Event and unknown EventItem") do
        assert_difference("Translation.count") do  # for the new Event
          patch event_items_resettle_new_event_url(evit)  #, params: { { } }
          assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          # assert_redirected_to hvid
          assert_redirected_to evit
        end
      end
    end
    follow_redirect!
    flash_regex_assert(/successfully updated/, msg=nil, type: :success)

    assert_equal evit.id, EventItem.order(updated_at: :desc).first.id
    evit.reload
    assert_equal hvid.id, evit.harami_vids.first.id
    hvid.reload

    refute_equal ev_orig, (ev_new=evit.event)
    refute_equal mtitle_orig, evit.machine_title

    assert_equal pla_new, evit.place
    assert_equal pla_new, ev_new.place

    assert_operator ev_new.start_time,         :<=, evit.start_time
    assert_operator 1.minutes, :<, evit.duration_minute.minutes, "duration = #{evit.duration_minute.inspect}"
    assert_operator ev_new.duration_hour.hours, :>=, evit.duration_minute.minutes
    assert_operator ev_new.duration_hour.hours, :<,  evit.duration_minute.minutes*20
    assert_operator ev_new.start_time+ev_new.duration_hour.hours, :>=, evit.start_time+evit.duration_minute.minutes,

    # Verify: HVid-3.months < Event#start_time <= EventItem#start_time
    earliest_conservative = hvid.release_date.to_time - 3.months
    assert_operator earliest_conservative, :<, ev_new.start_time
    assert_operator earliest_conservative, :<, evit.start_time
    assert_operator ev_new.start_time,    :<=, evit.start_time

    ## Check if the button does not appear if EventItem is associated to more than one HaramiVid
    HaramiVid.second.event_items << evit
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "Text: #{css_select(@css_assoc_event).to_s}"
    get event_item_path(evit)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "should not be displayed but..."

    ## Check if the button does not appear if EventItem is associated to no HaramiVid
    evit.harami_vids.destroy(HaramiVid.second)
    evit.harami_vids.destroy(hvid)
    evit.harami_vids.reset
    assert_equal 0, evit.harami_vids.count
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "Text: #{css_select(@css_assoc_event).to_s}"
    get event_item_path(evit)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "should not be displayed but..."

    sign_out @editor_harami
  end
end
