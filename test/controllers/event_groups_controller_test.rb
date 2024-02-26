# coding: utf-8
require "test_helper"

class EventGroupsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_group = event_groups(:evgr_lucky2023)
    @moderator       = users(:user_moderator_general_ja)  # General-JA Moderator can manage.
    @trans_moderator = users(:user_translator)
    @hs_create = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
      "place.prefecture_id"=>"", "place_id"=>"",
      "order_no"=>"", "start_year"=>"1999", "start_month"=>"", "start_day"=>"",
      "end_year"=>"1999", "end_month"=>"", "end_day"=>"",
      "start_date_err"=>"", "end_date_err"=>"", 
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
    get event_groups_url
    assert_response :success
    w3c_validate "EventGroup index"  # defined in test_helper.rb (see for debugging help)
  end

  test "should get new" do
    get new_event_group_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get new_event_group_url
    assert_response :success
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
    assert_equal "Test7, The", EventGroup.order(:created_at).last.title, "EventGroup: "+EventGroup.order(:created_at).last.inspect
  end

  test "should show event_group" do
    sign_in @trans_moderator
    get event_group_url(@event_group)
    assert_response :success
    w3c_validate "EventGroup index"  # defined in test_helper.rb (see for debugging help)
  end

  test "should get edit" do
    get edit_event_group_url(@event_group)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get edit_event_group_url(@event_group)
    assert_response :success
  end

  test "should update event_group" do
    pla = places(:unknown_place_kagawa_japan)
    pref = pla.prefecture

    hs = { event_group: { start_day: @event_group.start_date.day, start_month: @event_group.start_date.month, start_year: @event_group.start_date.year, note: @event_group.note, order_no: @event_group.order_no, end_day: @event_group.end_date.day, end_month: 11, end_year: @event_group.end_date.year, :"place.prefecture_id.country_id"=>"", "place.prefecture_id"=>pref.id, place_id: "" } }

    patch event_group_url(@event_group), params: hs
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    patch event_group_url(@event_group), params: hs
    assert_redirected_to event_group_url(@event_group)
    @event_group.reload
    assert_equal 11, @event_group.end_date.month
    assert_equal pla, @event_group.place
  end

  test "should destroy event_group for Harami-moderator" do
    @event_group.events.destroy_all

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
    assert_raises(ActiveRecord::DeleteRestrictionError){
      delete event_group_url(@event_group)
    }
  end

end
