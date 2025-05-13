# coding: utf-8
require "test_helper"

# == NOTE
#
class EventItems::ResettleNewEventsControllerTest < ActionDispatch::IntegrationTest
  include ModuleYoutubeApiAux  # for unit testing
  include ModuleCommon   # for camel_cased_truncated

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

  test "should get edit and patch update" do
    # See /test/models/harami1129_test.rb
    # Creating HaramiVid AND EventItem to ensure they are in 1-to-1 relation.
    # NOTE: This Harmai1129 has a keyword "都庁" in title, so the populated HaramiVid will be associated to Unknown EventItem in Event of Singleshot-Street-Playing-At-Tocho (I think...)
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

    # Button-like link is not displayed when the EventItem has no siblilngs (except for Unknown)
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 0}, "Text: #{css_select(@css_assoc_event).to_s}"  # another option for the hash: {text: "XXX is not specified."}
    
    # creating a sibling; then Button-like link is displayed.
    evit2 = hvid.event_items.first.dup
    evit2.machine_title = evit2.machine_title + "-2"
    evit2.save!

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

  # Testing Event#start_time after resettle_new_event
  test "should patch update well" do
    # NOTE: The populated HaramiVid from this Harami1129 will be associated to an EventItem in Unknown Singleshot-Street-Playing Event

    h1129 = harami1129s(:harami1129one)
    assert_operator h1129.release_date, :>, Date.new(2020, 6, 15), 'sanity check'
    assert_difference("Translation.count", 3) do  # for HaramiVid, Music, Artist
      assert_difference("ArtistMusicPlay.count*10000 + HaramiVidEventItemAssoc.count*1000 + HaramiVidMusicAssoc.count*100 + Artist.count*10 + Music.count", 11111) do
        assert_difference("HaramiVid.count*100 + Event.count*10 + EventItem.count", 101, "should create no Event but an EventItem") do
          h1129.insert_populate
        end
      end
    end
    h1129.reload

    hvid = h1129.harami_vid
    assert hvid
    assert_equal 1, hvid.event_items.count
    hvid.update!(duration: 4.minutes.in_seconds)

    evit = hvid.event_items.first
    mtitle_orig = evit.machine_title
    ev_orig = evit.event
    refute evit.unknown?
    assert_operator evit.start_time, :<, hvid.release_date.to_time, 'sanity check'
    assert_operator evit.start_time, :>, (hvid.release_date.to_time - 3.months), 'sanity check'
    assert_operator evit.start_time, :>, Date.new(2020, 6, 15), 'sanity check'

    # Creating another EventItem for the same Event so that the Event should have multiple non-unknown EventItems
    evit_another = evit.dup
    evit_another.update!(machine_title: "test_copy_"+__method__.to_s.gsub(/\s/, "_"), start_time: evit.start_time+1.minutes)
    evit.reload
    assert evit.siblings(exclude_unknown: true).exists?

    ## Editor harami is qualified
    sign_in @editor_harami

    # Button-like link should be displayed when the EventItem (except Unknown) belongs_to one of default Events
    get harami_vid_path(hvid)
    assert_response :success
    assert_select @css_assoc_event, {count: 1}, "Text: #{css_select('section#harami_vids_show_unique_parameters dd.item_event').to_s}"  # another option for the hash: {text: "XXX is not specified."}
    get event_item_path(evit)
    assert_response :success
    assert_select @css_assoc_event, {count: 1}, "Text: #{css_select(@css_assoc_event).to_s}"  # another option for the hash: {text: "XXX is not specified."}

    # Run...
    assert_no_difference("ArtistMusicPlay.count + HaramiVidEventItemAssoc.count") do
      assert_difference("HaramiVid.count*100 + Event.count*10 + EventItem.count", 11, "should create an EventItem that belongs_to unknown-street-playing Event") do
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

    evit.reload
    refute_equal ev_orig, (ev_new=evit.event)
    refute_equal mtitle_orig, evit.machine_title
    assert_equal ev_new.start_time, evit.start_time
    assert_operator ev_new.duration_hour.hours, :<, evit.duration_minute.minutes+Event::DEF_TIME_PARAMS[:DURATION]
    assert       ev_new.memo_editor.present?
    assert_match(/^#{Regexp.quote(h1129.song.split.first)}/i, evit.machine_title)

    sign_out @editor_harami
  end
end
