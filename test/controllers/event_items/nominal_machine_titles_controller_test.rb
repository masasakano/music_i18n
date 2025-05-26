require "test_helper"

class EventItems::NominalMachineTitlesControllerTest < ActionDispatch::IntegrationTest
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
    patch event_items_nominal_machine_title_path(@event_item)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami

    mctit = @event_item.machine_title
    patch event_items_nominal_machine_title_path(@event_item) #, params: { }
    assert_redirected_to event_items_nominal_machine_title_path(@event_item)

    @event_item.reload
    refute_equal mctit, @event_item.machine_title
    event = @event_item.event
    refute_match(/^\S+\-\S+_<_/i, @event_item.machine_title, "mctit=#{mctit.inspect} Event=#{event.title.inspect} EventGroup=#{@event_item.event_group.title.inspect}")

    mctit = @event_item.machine_title
    tit        = "MyUpdateTest M Title"
    tit2expect = "MyUpdateTest_M_Title"
    event.best_translation.update!(title: tit)

    patch event_items_nominal_machine_title_path(@event_item) #, params: { }
    @event_item.reload

    assert_redirected_to event_items_nominal_machine_title_path(@event_item)
    refute_equal mctit, @event_item.machine_title
    assert_match(/^\S+\-\S+_<_/i, @event_item.machine_title, "mctit=#{mctit.inspect} Event=#{event.title.inspect} EventGroup=#{@event_item.event_group.title.inspect}")
    assert_match(/#{tit2expect}/i, @event_item.machine_title, "mctit=#{mctit.inspect} Event=#{event.title.inspect} EventGroup=#{@event_item.event_group.title.inspect}")

    sign_out @editor_harami
  end
end
