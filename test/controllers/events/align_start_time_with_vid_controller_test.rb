require "test_helper"

class Events::AlignStartTimeWithVidControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event       = events(:ev_harami_lucky2023)
    @event_item  = event_items(:evit_1_harami_lucky2023)
    @sysadmin = users(:user_sysadmin)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    pla = places(:unknown_place_unknown_prefecture_japan)
    # INFO -- :   Parameters: {"id"=>"402", "locale"=>"ja"}
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should patch update" do
    patch events_align_start_time_with_vid_path(@event)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami

    assert_equal @event, @event_item.event, 'sanity check of fixtures'
    assert @event_item.harami_vids.exists?, 'sanity check of fixtures'
    hvid = @event_item.harami_vids.first
    assert hvid.release_date, 'sanity check of fixtures'
    assert_operator hvid.release_date, :>, Date.new(2020,9,1), 'sanity check of fixtures'

    # destroy all the other HaramiVids associations to @event
    @event.harami_vid_event_item_assocs.where.not(harami_vid_id: hvid.id).destroy_all
    @event.harami_vid_event_item_assocs.reset
    @event.harami_vids.reset
    assert_equal 1, @event.harami_vids.distinct.count

    evgr = @event.event_group
    old_sttime = hvid.release_date.to_time - 18.months  # Float#years (like 1.5.years) is undefined!
    old_sttime_err = 90.years.in_seconds
    evgr.update!(start_date: old_sttime.to_date - 2.days)
    @event.update!(start_time: old_sttime, start_time_err: old_sttime_err)

    patch events_align_start_time_with_vid_path(@event) #, params: { }
    assert_redirected_to events_align_start_time_with_vid_path(@event)

    @event.reload
    refute_equal old_sttime,     @event.start_time
    refute_equal old_sttime_err, @event.start_time_err
    assert_operator @event.start_time, :>, hvid.release_date.to_time - ModuleHaramiVidEventAux::OFFSET_PERIOD_FROM_REFERENCE - 7.days
    assert_operator @event.start_time_err, :<, (ModuleHaramiVidEventAux::OFFSET_PERIOD_FROM_REFERENCE+7.days).in_seconds

    sign_out @editor_harami
  end
end
