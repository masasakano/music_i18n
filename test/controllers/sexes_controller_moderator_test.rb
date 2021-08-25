require 'test_helper'

class SexesControllerModeratorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # get '/users/sign_in'
    # # sign_in users(:user_001)
    # sign_in Role[:moderator].users.first  # moderator
    # post user_session_url

    # # If you want to test that things are working correctly, uncomment this below:
    # follow_redirect!
    # assert_response :success
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    begin
      get '/users/sign_in'
      sign_in Role[:moderator, RoleCategory::MNAME_GENERAL_JA].users.first   # moderator/general_ja
      post user_session_url

      # If you want to test that things are working correctly, uncomment this below:
      follow_redirect!
      assert_response :success
      get sexes_url
      assert_response :success
      get new_sex_url
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
      get sex_url(Sex.first)
      assert_response :success
    ensure
      Rails.cache.clear
    end
    #print "DEBUG:logged_in?=#{user_signed_in?}; current_user="; p current_user  # => undefined method `user_signed_in?' 'current_user'
  end
#  setup do
#    # get '/users/sign_in'
#    # # sign_in users(:user_001)
#    # @user = Role[:moderator].users.first  # moderator
#    # sign_in @user
#    # assert @user.moderator?
#    # post user_session_url
#
#    # # If you want to test that things are working correctly, uncomment this below:
#    # #follow_redirect!
#    # #assert_response :success
#  end
#
#  test "should get index" do
#    get '/users/sign_in'
#    # sign_in users(:user_001)
#    @user = Role[:moderator].users.first  # moderator
#    sign_in @user
#    assert @user.moderator?
#    post user_session_url
#print "DEBUG:@user="; p @user
#print "DEBUG:URL=(name=#{sexes_url.class.name}; id=#{sexes_url.object_id})="; p sexes_url  # => "http://www.example.com/sexes"
##print "DEBUG:logged_in?=#{user_signed_in?}; current_user="; p current_user
#    get harami1129s_url
#    assert_response :redirect
#    #get sexes_url
#    #assert_response :success
#    get "/sexes"
#    ##get sexes_url
#    #assert_response :success
#  end

  #test "should get new" do
  #  get new_sex_url
  #  assert_response :success
  #end

  #test "should create sex" do
  #  assert_difference('Sex.count') do
  #    post sexes_url, params: { sex: { iso5218: @sex.iso5218, note: @sex.note } }
  #  end

  #  assert_redirected_to sex_url(Sex.last)
  #end

  #test "should show sex" do
  #  get sex_url(@sex)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_sex_url(@sex)
  #  assert_response :success
  #end

  #test "should update sex" do
  #  patch sex_url(@sex), params: { sex: { iso5218: @sex.iso5218, note: @sex.note } }
  #  assert_redirected_to sex_url(@sex)
  #end

  #test "should destroy sex" do
  #  assert_difference('Sex.count', -1) do
  #    delete sex_url(@sex)
  #  end

  #  assert_redirected_to sexes_url
  #end
end
