# coding: utf-8
require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event = events(:ev_harami_lucky2023)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    @moderator = @moderator_all 
    pla = places(:unknown_place_unknown_prefecture_japan)
    @hs_create = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
      "place.prefecture_id"=>pla.prefecture.id.to_s, "place_id"=>pla.id.to_s,
      "event_group_id"=>@event.event_group.id.to_s,
      "start_year"=>"2024", "start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
      "start_err"=>"3", "start_err_unit"=>"hours",
      "duration_hour"=>"0.5", "weight"=>"",
      "note"=>""
    }
    @validator = W3CValidators::NuValidator.new
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get events_url
    assert_response :success
    assert_match(/\bPlace\b/, css_select("table").text)
    w3c_validate "Event index"  # defined in test_helper.rb (see for debugging help)
  end

  test "should get new" do
    get new_event_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get new_event_url
    assert_response :success
  end

  test "should create event" do
    assert_no_difference("Event.count") do
      post events_url, params: { event: @hs_create }
    end

    editor = roles(:general_ja_editor).users.first
    sign_in editor
    assert_not Ability.new(editor).can?(:create, Event)
    assert_no_difference("Event.count") do
      post events_url, params: { event: @hs_create }
    end

    sign_in @trans_moderator  # cannot create
    assert_not Ability.new(@trans_moderator).can?(:create, Event)
    assert_no_difference("Event.count") do
      post events_url, params: { event: @hs_create }
    end
    sign_out @trans_moderator

    #sign_in users(:user_sysadmin)  # for DEBUG
    sign_in @moderator_all
    assert_difference("Event.count") do
      post events_url, params: { event: @hs_create }
      my_assert_no_alert_issued screen_test_only: true  # defined in /test/test_helper.rb
    end
    assert_redirected_to event_url(Event.last)
    assert_equal "Test7, The", Event.order(:created_at).last.title, "Event: "+Event.order(:created_at).last.inspect
  end

  test "should show event" do
    #sign_in @trans_moderator
    get event_url(@event)
    assert_response :success
    assert_match(/\bPlace\b/, css_select("body").text)
    w3c_validate "Event index"  # defined in test_helper.rb (see for debugging help)
  end

  test "should get edit" do
    get edit_event_url(@event)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get edit_event_url(@event)
    assert_response :success
  end

  test "should update event" do
    hs = { event: { 
      "place.prefecture_id.country_id"=>@event.place.country.id.to_s,
      "place.prefecture_id"=>@event.place.prefecture.id.to_s, "place_id"=>@event.place.id.to_s,  #  no change
      "event_group_id"=>@event.event_group_id,
      "start_year"=>"2017", #"start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
      "start_err"=>"129", "start_err_unit"=>"hour",  # 129 is updated.
      #"duration_hour"=>"0.5", "weight"=>"",
      "note"=>""
    } }

    patch event_url(@event), params: hs
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    patch event_url(@event), params: hs
    assert_redirected_to event_url(@event)

    newevt = Event.find @event.id
    t = newevt.start_app_time
    assert_equal     2017, t.year, "time=#{newevt.start_time.inspect}"
    assert_equal 129*3600, newevt.start_time_err
    assert_equal 129*3600, t.error.in_seconds
    assert_equal @event.place, newevt.place
    
    ### test of "middle" time
    # When params{"start_err"=>""}, i.e., Event#start_time_err is set nil,
    # and if "month" is blank, the middle of the year (2nd July in a non-leap year)
    # should be set as the start_time.
    hs2 = hs.merge({ event: { "start_err"=>"", "start_year"=>"2011", "start_month"=>""}})
    @event.reload
    patch event_url(@event), params: hs2
    assert_redirected_to event_url(@event)

    @event.reload
    t = @event.start_app_time
    assert_equal     2011, t.year,  "time=#{@event.start_time.inspect}"
    assert_equal        7, t.month, "time=#{@event.start_time.inspect}"
    assert_equal        2, t.day,   "time=#{@event.start_time.inspect}"
    assert_nil  @event.start_time_err
  end

  test "should destroy event" do
    assert_no_difference("EventGroup.count") do
      delete event_url(@event)
    end

    sign_in @moderator
    assert_no_difference("EventGroup.count", "should fail because of presence of a child") do
      delete event_url(@event)
    end

    evt = Event.create_with_translations!({event_group: @event.event_group, place_id: @event.place.id}, note: 1950, translations: {en: [{title: 'an event 987'}]})

    assert_difference("Event.count", -1) do
      delete event_url(evt)
      my_assert_no_alert_issued  # defined in /test/test_helper.rb
    end
    assert_redirected_to events_url
  end
end
