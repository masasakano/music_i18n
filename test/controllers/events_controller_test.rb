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
      "place.prefecture_id"=>pla.prefecture.id.to_s, "place_id"=>pla.id.to_s, "place"=>pla.id.to_s,
      "event_group_id"=>@event.event_group.id.to_s,
      "start_year"=>"2024", "start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
      "start_err"=>"3", "start_err_unit"=>"hours",
      "duration_hour"=>"0.5", "weight"=>"",
      "start_time(1i)"=>"2024", "start_time(2i)"=>"8", "start_time(3i)"=>"1", "start_time(4i)"=>"12", "start_time(5i)"=>"00",
      "form_start_err"=>"69959976.0", "form_start_err_unit"=>"hour",
      "note"=>""
    }
    pla = @event.place
    tim = @event.start_time
    @hs_update = {
      "place.prefecture_id.country_id"=>pla.country.id.to_s,
      "place.prefecture_id"=>pla.prefecture.id.to_s, "place_id"=>pla.id.to_s, "place"=>pla.id.to_s,  #  no change
      "event_group_id"=>@event.event_group_id,
      "start_time(1i)"=>"2017", "start_time(2i)"=>tim.month.to_s, "start_time(3i)"=>tim.day.to_s, "start_time(4i)"=>tim.hour.to_s, "start_time(5i)"=>tim.min.to_s,
      "form_start_err"=>"129", "form_start_err_unit"=>"hour",  # updated to 129
      "duration_hour"=>(@event.duration_hour || "").to_s, "weight"=>(@event.weight || "").to_s,
      "note"=>""
    }
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
#puts response.body
    w3c_validate "Event index"  # defined in test_helper.rb (see for debugging help)

    #css_events = "table#events_index_table tbody tr"
    #assert_operator 0, :<, css_select(css_events).size, "rows (defined in Fixtures) should exist, but..."
  end

  test "should get new" do
    get new_event_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get new_event_url
    assert_response :success

    # a GET link from EventGroup
    get new_event_url, params: {event_group_id: EventGroup.last.id.to_s}
    assert_response :success

    evgr = EventGroup.create_basic!(title: "new-test group1", langcode: "en", is_orig: true, start_date: Date.new(2012,4,28), start_date_err: 0, place: places(:tocho), note: (newnote="new1"))
    get new_event_url, params: {event_group_id: evgr.id.to_s}
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
    ev_last = Event.order(:created_at).last
    assert_equal "Test7, The", Event.order(:created_at).last.title, "Event: "+ev_last.inspect
    assert_equal @hs_create["form_start_err"].to_i*3600, ev_last.start_time_err
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
    assert                                      css_select("input#event_form_start_err")[0]["value"].present?, "HTML="+css_select("input#event_form_start_err").to_html
    assert_equal @event.start_time_err/60.0, (v=css_select("input#event_form_start_err")[0]["value"]).to_f, "val=#{v.inspect}"  # This should be "minute"
  end

  test "should update event" do
    #hs = { event: { 
    #  "place.prefecture_id.country_id"=>@event.place.country.id.to_s,
    #  "place.prefecture_id"=>@event.place.prefecture.id.to_s, "place_id"=>@event.place.id.to_s,  #  no change
    #  "event_group_id"=>@event.event_group_id,
    #  "start_year"=>"2017", #"start_month"=>"", "start_day"=>"", "start_hour"=>"", "start_minute"=>"",
    #  "start_err"=>"129", "start_err_unit"=>"hour",  # 129 is updated.
    #  #"duration_hour"=>"0.5", "weight"=>"",
    #  "note"=>""
    #} }

    patch event_url(@event), params: {event: @hs_update} #hs
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    patch event_url(@event), params: {event: @hs_update} #hs
    assert_redirected_to event_url(@event)

    newevt = Event.find @event.id
    t = newevt.start_app_time  # defined in module_common.rb
    assert_equal     2017, t.year, "time=#{newevt.start_time.inspect}"
    assert_equal 129*3600, newevt.start_time_err
    assert_equal 129*3600, t.error.in_seconds
    assert_equal @event.place, newevt.place
    
    # ### test of "middle" time
    # # When params{"start_err"=>""}, i.e., Event#start_time_err is set nil,
    # # and if "month" is blank, the middle of the year (2nd July in a non-leap year)
    # # should be set as the start_time.
    # hs2 = hs.merge({ event: { "start_err"=>"", "start_year"=>"2011", "start_month"=>""}})
    # @event.reload
    # patch event_url(@event), params: hs2
    # assert_redirected_to event_url(@event)

    # @event.reload
    # t = @event.start_app_time
    # assert_equal     2011, t.year,  "time=#{@event.start_time.inspect}"
    # assert_equal        7, t.month, "time=#{@event.start_time.inspect}"
    # assert_equal        2, t.day,   "time=#{@event.start_time.inspect}"
    # assert_nil  @event.start_time_err
  end

  test "should destroy event" do
    assert_no_difference("Event.count") do
      delete event_url(@event)
    end

    sign_in @moderator
    assert_no_difference("Event.count", "should fail because of presence of a child") do
      assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){  # Rails level (has_many - dependent) and DB-level, respectively; nb., this would be ActiveRecord::RecordNotDestroyed if :restrict_with_error is set and destroy! is run.
        delete event_url(@event)
      }
    end
    assert_response :redirect
    follow_redirect!
    refute_match(/\bsuccessfully\b/, css_select("p.notice").text, "ERROR: "+response.body) #css_select("body").text)

    evt = Event.create_with_translations!({event_group: @event.event_group, place_id: @event.place.id}, note: 1950, translations: {en: [{title: 'an event 987'}]})

    sign_in @moderator
    assert_difference("Event.count", -1) do
      delete event_url(evt)
      # my_assert_no_alert_issued  # defined in /test/test_helper.rb  ## previous alert remains... : You need to sign in or sign up before continuing.
    end
    assert_redirected_to events_url
  end
end
