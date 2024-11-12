# coding: utf-8
require "test_helper"

class EventGroupsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)
    @moderator       = users(:user_moderator_general_ja)  # General-JA Moderator can manage.
    @trans_moderator = users(:user_translator)
    @editor_ja       = users(:user_editor_general_ja)
    @hs_create = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
      "place.prefecture_id"=>"", "place_id"=>"",
      "start_date(1i)"=>"1999", "start_date(2i)"=>"1", "start_date(3i)"=>"11",
      "end_date(1i)"=>(Date.current.end_of_year+80.year).year.to_s,
      "end_date(2i)"=>"12", "end_date(3i)"=>"31",
      #"start_year"=>"1999", "start_month"=>"", "start_day"=>"",
      #"end_year"=>"1999", "end_month"=>"", "end_day"=>"",
      "start_date_err"=>"", "end_date_err"=>"", 
      "note"=>""
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get event_groups_url
    assert_response :redirect
    assert_redirected_to root_path, "This can be new_user_session_path, depending how it is written in controller."

    sign_in @editor_ja  ########### This should be unnecessary once index becomes public!
    get event_groups_url
    assert_response :success
    assert_match(/\bPlace\b/, css_select("body").text)

    css_events = "table#event_groups_index_table tbody tr"
    assert_operator 0, :<, css_select(css_events).size, "rows (defined in Fixtures) should exist, but..."

    css_events = "td.event_groups_index_table_events"
    assert_operator 0, :<, css_select(css_events).size
    assert_match(/\A\d+\z/, css_select(css_events).first.text.strip)
    w3c_validate "EventGroup index"  # defined in test_helper.rb (see for debugging help)
    sign_out @editor_ja
  end

  test "should get new" do
    get new_event_group_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get new_event_group_url
    assert_response :success

    exp = (TimeAux::DEF_FIRST_DATE_TIME+1.day).year
    assert_equal exp, css_select('select#event_group_start_date_1i option[selected=selected]')[0]["value"].to_i, "Default year should be selected, but..."
    w3c_validate "EventGroup new"  # defined in test_helper.rb (see for debugging help)
  end

  test "should create event_group" do
    assert_no_difference("EventGroup.count") do
      post event_groups_url, params: { event_group: @hs_create }
    end

    editor = roles(:general_ja_editor).users.first
    sign_in editor
    assert_not Ability.new(editor).can?(:create, EventGroup)
    assert_no_difference("EventGroup.count") do
      post event_groups_url, params: { event_group: @hs_create }
    end

    sign_in @trans_moderator  # cannot create
    assert_not Ability.new(@trans_moderator).can?(:create, EventGroup)
    assert_no_difference("EventGroup.count") do
      post event_groups_url, params: { event_group: @hs_create }
    end

    #sign_in users(:user_sysadmin)  # for DEBUG
    sign_in @moderator
    assert_difference("EventGroup.count") do
      post event_groups_url, params: { event_group: @hs_create }
    end
    assert_redirected_to event_group_url(EventGroup.last)
    new_evgr = EventGroup.order(:created_at).last
    assert_equal "Test7, The", new_evgr.title, "EventGroup: "+EventGroup.order(:created_at).last.inspect
    assert  new_evgr.end_date, "end_date should be defined, but...: EventGroup=#{new_evgr.inspect}"
    assert_equal TimeAux::DEF_LAST_DATE_TIME.year, new_evgr.end_date.year, "Unreasonably late date (large year) should be replaced with the default, but...: EventGroup=#{new_evgr.inspect}"
  end

  test "should show event_group" do
    ## Even non-priviledge people can "show"
    #sign_in @trans_moderator
    get event_group_url(@event_group)
    assert_response :success
    assert_match(/\bPlace\b/, css_select("body").text)
    w3c_validate "EventGroup show"  # defined in test_helper.rb (see for debugging help)
    assert_equal 1, css_select("#table_event_group_show_events").size

    assert_equal 0, css_select("#link_back_to_index a").size  # "Back to Index"
    sign_in @editor_ja  ########### This should be unnecessary once index becomes public!
    get event_group_url(@event_group)
    assert_equal 1, css_select(".link_back_to_index a").size  # "Back to Index"
    sign_out @editor_ja
  end

  test "should get edit" do
    get edit_event_group_url(@event_group)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get edit_event_group_url(@event_group)
    assert_response :success

    @event_group.update!(end_date: TimeAux::DEF_LAST_DATE_TIME.to_date)  # Year 9999
    get edit_event_group_url(@event_group)
    assert_response :success

    selected_end_year = css_select('select#event_group_end_date_1i option[selected=selected]')[0]["value"].to_i
    refute_equal TimeAux::DEF_LAST_DATE_TIME.year, selected_end_year, "End-year in the form should differ from the DB value, but..."
    assert_equal selected_end_year, [TimeAux::DEF_LAST_DATE_TIME.year, selected_end_year].min, "End-year should be a lot earlier than the DB one, but..."
    assert_operator (Date.current+5.year).year, :<, selected_end_year, "End-year should be much later than the current year, but..."
  end

  test "should update event_group" do
    pla = places(:unknown_place_kagawa_japan)
    aus = countries(:aus)
    #pref = pla.prefecture

    hs = { event_group: { "start_date(1i)" => @event_group.start_date.year.to_s, "start_date(2i)" => @event_group.start_date.month.to_s, "start_date(3i)" => @event_group.start_date.day.to_s,
                          "end_date(1i)" => @event_group.end_date.year.to_s, "end_date(2i)" => "11", "end_date(3i)" => @event_group.end_date.day.to_s,
                          "note" => @event_group.note,
                          "place.prefecture_id.country_id"=>aus.id.to_s, "place.prefecture_id"=>"", "place" => "" } }

    patch event_group_url(@event_group), params: hs
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    patch event_group_url(@event_group), params: hs
    assert_redirected_to event_group_url(@event_group)
    @event_group.reload
    assert_equal 11, @event_group.end_date.month
    assert_equal Place.unknown(country: aus), @event_group.place
  end

  test "should destroy event_group for Harami-moderator" do
    ev_lucky = events(:ev_harami_lucky2023)
    assert             ev_lucky.best_translation,          "sanity check of fixtures"
    assert_equal 'en', ev_lucky.best_translation.langcode, "sanity check of fixtures"
    assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError){
      @event_group.events.destroy_all }
    @event_group.events.each do |eev|
      assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError){
        eev.event_items.destroy_all }

      eev.event_items.each do |eevi|
        eevi.harami_vids.destroy_all
        if eevi.harami1129s.exists?
          assert_raises(ActiveRecord::DeleteRestrictionError){eevi.destroy! if !eevi.unknown? }  # ActiveRecord::InvalidForeignKey if has_many was not defined.
          eevi.harami1129s.each do |eh|
            eh.update!(event_item: nil)  # nullify Harami1129's reference.
          end
          eevi.reload  # Essential!!
        end
        eevi.destroy! if !eevi.unknown?  # EventItem#unknown cannot be destroyed.
      end
      eev.reload  # Essential!!
      begin 
        eev.destroy! if !eev.unknown?  # Event#unknown cannot be destroyed.
      rescue ActiveRecord::DeleteRestrictionError
        puts "DEBUG-136(#{File.basename __FILE__}:#{__method__}):eev.event_items=#{eev.event_items.all.to_a}"
        puts "DEBUG-137(#{File.basename __FILE__}:#{__method__}):event=#{eev.inspect}"
        raise
      end
    end
    @event_group.reload

    assert_no_difference("EventGroup.count") do
      delete event_group_url(@event_group)
    end

    sign_in @trans_moderator 
    assert_no_difference("EventGroup.count", "Translator should not destroy.") do
      delete event_group_url(@event_group)
    end
    sign_out @trans_moderator 

    sign_in @moderator
    assert_difference("EventGroup.count", -1) do
      delete event_group_url(@event_group)
    end
    assert_redirected_to event_groups_url
  end

  test "should not destroy event_group with dependent children" do
    sign_in @moderator

    assert @event_group.events.exists?, 'sanity check of fixtures.'
    assert_equal 2, @event_group.events.count
    assert_operator 0, :<, @event_group.harami_vids.count, 'sanity check of fixtures harami_vid.'
    assert_difference("EventGroup.count", 0) do
      delete event_group_url(@event_group)
    end
  end

end
