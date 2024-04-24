# coding: utf-8
require "test_helper"

class EventItemsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event       = events(:ev_harami_lucky2023)
    @event_item  = event_items(:evit_1_harami_lucky2023)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    pla = places(:unknown_place_unknown_prefecture_japan)
    @hs_create = {
      "machine_title"=>"test_ei01",
      "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
      "place.prefecture_id"=>pla.prefecture.id.to_s, "place_id"=>pla.id.to_s,
      "event_id"=>@event_item.event.id.to_s,
      "start_year"=>"2024", "start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
      "start_err"=>"3", "start_err_unit"=>"hours",
      "duration_minute"=>"20", "duration_minute_err"=>"3.5", "weight"=>"", "event_ratio"=>"0.4",
      "note"=>"",
    }.with_indifferent_access
    @validator = W3CValidators::NuValidator.new
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

    sign_in @moderator_harami
    get new_event_url
    assert_response :success
  end

  test "should create event_item" do
    assert_no_difference("EventItem.count") do
      post event_items_url, params: { event_item: @hs_create }
    end

    editor = users(:user_editor)
    sign_in editor
    assert_difference("EventItem.count") do
      post event_items_url, params: { event_item: @hs_create }
    end
    ei_last = EventItem.last
    assert_redirected_to event_item_url(ei_last)
    assert_equal 2024, ei_last.start_time.year
  end

  test "should show event_item" do
    get event_item_url(@event_item)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get event_item_url(@event_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_event_item_url(@event_item)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get edit_event_item_url(@event_item)
    assert_response :success
  end

  test "should update event_item" do
    patch event_item_url(@event_item), params: { event_item: @hs_create.merge({"weight" => 0.98}) }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    patch event_item_url(@event_item), params: { event_item: @hs_create.merge({"weight" => 0.98}) }
    assert_redirected_to event_item_url(@event_item)
    assert_equal 0.98, EventItem.find(@event_item.id).weight

    patch event_item_url(@event_item), params: {event_item: @hs_create.merge({"machine_title" => event_items(:evit_1_harami_lucky2023).machine_title}) }
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
