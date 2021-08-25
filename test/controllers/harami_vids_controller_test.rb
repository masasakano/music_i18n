require 'test_helper'

class HaramiVidsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get harami_vids_url
    assert_response :success
    #assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  #test "should get new" do
  #  get new_harami_vid_url
  #  assert_response :success
  #end

  test "should fail to create harami_vid" do
    assert_no_difference('HaramiVid.count') do
      post harami_vids_url, params: { harami_vid: { date: @harami_vid.release_date, duration: @harami_vid.duration, flag_by_harami: @harami_vid.flag_by_harami, place_id: @harami_vid.place_id, uri: @harami_vid.uri+'abc', } }
    end
    assert_redirected_to new_user_session_path
  end

  test "should show harami_vid" do
    get harami_vid_url(@harami_vid)
    assert_response :success
  end

  test "should fail to get edit" do
    get edit_harami_vid_url(@harami_vid)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should fail to update harami_vid" do
    patch harami_vid_url(@harami_vid), params: { harami_vid: { note: 'abc' } }
  #  assert_redirected_to harami_vid_url(@harami_vid)
    assert_redirected_to new_user_session_path
  end

  test "should fail to destroy harami_vid" do
    assert_no_difference('HaramiVid.count') do
      delete harami_vid_url(@harami_vid)
    end
    assert_redirected_to new_user_session_path
  end
end

