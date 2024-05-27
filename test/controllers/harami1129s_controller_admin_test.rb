require 'test_helper'

class Harami1129sControllerAdminTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------
  # add from here
  include Devise::Test::IntegrationHelpers

  setup do
    #get '/users/sign_in'
    ## sign_in users(:user_001)
    #sign_in User.find(1)  # superuser
    #post user_session_url

    ## If you want to test that things are working correctly, uncomment this below:
    #follow_redirect!
    #assert_response :success
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get channels_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    begin
      get '/users/sign_in'
      # sign_in users(:user_001)
      sign_in User.find(1)  # superuser
      post user_session_url

      # If you want to test that things are working correctly, uncomment this below:
      follow_redirect!
      assert_response :success

      #print "DEBUG:logged_in?=#{user_signed_in?}; current_user="; p current_user  # => undefined method `user_signed_in?' 'current_user'
      get harami1129s_url
      assert_response :success
      if is_env_set_positive?('TEST_STRICT')  # defined in application_helper.rb
        w3c_validate "Harami1129 index"  # defined in test_helper.rb (see for debugging help)
      end  # only if TEST_STRICT, because of invalid HTML for datagrid filter for Range
      get sexes_url
      assert_response :success
    ensure
      Rails.cache.clear
    end
  end

  #test "should get new" do
  #  get new_harami1129_url
  #  assert_response :success
  #end

  #test "should create harami1129" do
  #  assert_difference('Harami1129.count') do
  #    post harami1129s_url, params: { harami1129: { ins_at: @harami1129.ins_at, ins_link_root: @harami1129.ins_link_root, ins_link_time: @harami1129.ins_link_time, ins_release_date: @harami1129.ins_release_date, ins_singer: @harami1129.ins_singer, ins_song: @harami1129.ins_song, ins_title: @harami1129.ins_title, link_root: @harami1129.link_root, link_time: @harami1129.link_time, note: @harami1129.note, release_date: @harami1129.release_date, singer: @harami1129.singer, song: @harami1129.song, title: @harami1129.title } }
  #  end

  #  assert_redirected_to harami1129_url(Harami1129.last)
  #end

  #test "should show harami1129" do
  #  get harami1129_url(@harami1129)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_harami1129_url(@harami1129)
  #  assert_response :success
  #end

  #test "should update harami1129" do
  #  patch harami1129_url(@harami1129), params: { harami1129: { ins_at: @harami1129.ins_at, ins_link_root: @harami1129.ins_link_root, ins_link_time: @harami1129.ins_link_time, ins_release_date: @harami1129.ins_release_date, ins_singer: @harami1129.ins_singer, ins_song: @harami1129.ins_song, ins_title: @harami1129.ins_title, link_root: @harami1129.link_root, link_time: @harami1129.link_time, note: @harami1129.note, release_date: @harami1129.release_date, singer: @harami1129.singer, song: @harami1129.song, title: @harami1129.title } }
  #  assert_redirected_to harami1129_url(@harami1129)
  #end

  #test "should destroy harami1129" do
  #  assert_difference('Harami1129.count', -1) do
  #    delete harami1129_url(@harami1129)
  #  end

  #  assert_redirected_to harami1129s_url
  #end
end
