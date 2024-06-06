# coding: utf-8
require "test_helper"

class EventItemsControllerTest < ActionDispatch::IntegrationTest
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
    @hs_create = {
      "machine_title"=>"test_ei01",
      "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
      "place.prefecture_id"=>pla.prefecture.id.to_s, "place"=>pla.id.to_s,
      "event_id"=>@event_item.event.id.to_s,
      "start_time(1i)"=>"2024", "start_time(2i)"=>"8", "start_time(3i)"=>"1", "start_time(4i)"=>"12", "start_time(5i)"=>"00",
      "publish_date(1i)"=>"2024", "publish_date(2i)"=>"9", "publish_date(3i)"=>"3",
      #"start_year"=>"2024", "start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
      #"start_err"=>"3", "start_err_unit"=>"hours",
      "form_start_err"=>"69959976.0", "form_start_err_unit"=>"hour",
      "duration_minute"=>"20", "duration_minute_err"=>"3.5", "weight"=>"", "event_ratio"=>"0.4",
      "note"=>"",
    }.with_indifferent_access
    # INFO -- :   Parameters: {"authenticity_token"=>"[FILTERED]", "event_item"=>{"machine_title"=>"", "event_id"=>"10", "start_time(1i)"=>"2019", "start_time(2i)"=>"1", "start_time(3i)"=>"1", "start_time(4i)"=>"12", "start_time(5i)"=>"00", "form_start_err"=>"69959976.0", "form_start_err_unit"=>"hour", "duration_minute"=>"", "duration_minute_err"=>"", "place.prefecture_id.country_id"=>"0", "place.prefecture_id"=>"", "place"=>"", "weight"=>"", "event_ratio"=>"", "note"=>""}, "commit"=>"Submit", "locale"=>"en"}
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get event_items_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get event_items_url
    assert_response :success
  end

  test "should get new" do
    get new_event_item_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@moderator_harami, @sysadmin].each do |user|
      sign_in user
      get new_event_url
      assert_response :success
      sign_out user
    end
  end

  test "should create event_item" do
    assert_no_difference("EventItem.count") do
      post event_items_url, params: { event_item: @hs_create }
    end

    editor = users(:user_editor)
    sign_in editor
    assert_difference("EventItem.count") do
      post event_items_url, params: { event_item: @hs_create }
      assert_response :redirect
    end
    ei_last = EventItem.last
    assert_redirected_to event_item_url(ei_last)
    assert_equal 2024, ei_last.start_time.year
    assert_equal    8, ei_last.start_time.month
    assert_equal    9, ei_last.publish_date.month
    assert_equal @hs_create["form_start_err"].to_i*3600, ei_last.start_time_err
  end

  test "should show event_item" do
    get event_item_url(@event_item)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@editor_harami, @sysadmin].each do |user|
      sign_in user
      get event_item_url(@event_item)
      assert_response :success
      sign_out user
    end
  end

  test "should get edit" do
    get edit_event_item_url(@event_item)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@editor_harami, @moderator_harami, @sysadmin].each do |user|
      sign_in user
      get edit_event_item_url(@event_item)
      assert_response :success
      sign_out user
    end
  end

  test "should update event_item" do
    patch event_item_url(@event_item), params: { event_item: @hs_create.merge({"weight" => 0.98}) }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    patch event_item_url(@event_item), params: { event_item: @hs_create.merge({"weight" => 0.98}) }
    assert_redirected_to event_item_url(@event_item)
    assert_equal 0.98, EventItem.find(@event_item.id).weight

    @event_item.reload
    tocho = places(:tocho)
    stt_time = Time.current.floor - 2.days
    @event_item.event.update!(start_time: stt_time, place: tocho)
    tokyo_unknown = tocho.prefecture.unknown_place
    @event_item.update!(start_time: stt_time-2.hours, place: tokyo_unknown)
    @event_item.reload
    assert @event_item.place.encompass_strictly?(@event_item.event.place), 'sanity check'
    assert_operator @event_item.event.start_time_err, :<, @event_item.start_time_err, 'This may or may not be true, actually.'

    # Leaves most parameters 
    hs2give = @hs_create.merge(
      get_params_from_date_time(@event_item.start_time, "start_time", maxnum=6)).merge(
      {"weight" => @event_item.weight, "place" => @event_item.place.id, "match_parent"=>"1", "note" => (tmptxt="test-match")}
    )
    patch event_item_url(@event_item), params: { event_item: hs2give }
    assert_redirected_to event_item_url(@event_item)

    @event_item.reload
    event = @event_item.event
    assert_equal tmptxt, @event_item.note, 'sanity check'
    assert_equal event.place,          @event_item.place
    assert_equal event.start_time,     @event_item.start_time
    assert_operator event.start_time_err, :>=, @event_item.start_time_err, "this must be guaranteed, but..."
    assert_equal    event.start_time_err,      @event_item.start_time_err  # providing the assert_operator above is true.

    @event_item.update!(start_time: stt_time-2.hours, place: tokyo_unknown, event: events(:ev_harami_budokan2022_soiree))
    @event_item.reload
    
    # Test of specifying "match_parent"=>"1" at the same time as the new Event (in this case, reverting back to the original Event)
    patch event_item_url(@event_item), params: { event_item: hs2give.merge({"event_id" => event.id.to_s, "note" => (tmptxt="test-match2")})}
    assert_redirected_to event_item_url(@event_item)
    @event_item.reload
    assert_equal tmptxt, @event_item.note, 'sanity check'
    assert_equal event.place,          @event_item.place
    assert_equal event.start_time,     @event_item.start_time
  end

  test "should destroy event_item" do
    @event_item.harami_vids.destroy_all  # essential.

    assert_no_difference("EventItem.count", -1) do
      delete event_item_url(@event_item)
      assert_response :redirect
    end

    sign_in @editor_harami
    assert_difference("EventItem.count", -1) do
      delete event_item_url(@event_item)
    end
    assert_redirected_to event_items_url
  end
end
