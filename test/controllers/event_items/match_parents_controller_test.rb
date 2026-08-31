require "test_helper"

class EventItems::MatchParentsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event       = events(:ev_harami_lucky2023)
    @event_item  = event_items(:evit_1_harami_lucky2023)
    # @sysadmin = users(:user_sysadmin)
    # @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    # @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    # @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    # @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
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
