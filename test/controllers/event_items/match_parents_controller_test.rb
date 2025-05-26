require "test_helper"

class EventItems::MatchParentsControllerTest < ActionDispatch::IntegrationTest
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

  test "should patch update" do
    patch event_items_match_parent_url(@event_item), params: { event_item: {}}
    assert_response :redirect
    assert_redirected_to new_user_session_path

    evit_orig = @event_item

    sign_in @editor_harami
    patch event_items_match_parent_url(@event_item) #, params: { }
    assert_redirected_to event_item_url(@event_item)
    assert_equal evit_orig.weight, EventItem.find(@event_item.id).weight

    @event_item.reload
    assert_equal evit_orig, @event_item

    dur_min     = @event_item.duration_minute
    dur_min_err = @event_item.duration_minute_err
    @event_item.update!(duration_minute_err: 9999999)
    patch event_items_match_parent_url(@event_item) #, params: { }
    @event_item.reload
    assert_equal dur_min*60,  @event_item.duration_minute_err
    refute_equal dur_min_err, @event_item.duration_minute_err  # Error is updated according to duration_minute

    sign_out @editor_harami
  end
end
