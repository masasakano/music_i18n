require "test_helper"

class EngagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @engage = engages(:engage1)
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    sign_in @editor
    music  = Music.first
    get engages_url(music_id: music.id)
    assert_response :success
  end

  test "should create" do
    # Creation unauthorized
    assert_no_difference('Engage.count') do
      post engages_url, params: { engage: { artist_name: translations(:artist_rcsuccession_ja).title, music_id: @engage.music.id, engage_how: [engage_hows(:engage_how_composer).id, engage_hows(:engage_how_player).id], year: 1234 } }
      assert_response :redirect
      assert_redirected_to new_user_session_url
    end

    # Delete unauthorized
    assert_no_difference('Engage.count') do
      delete engage_url(Engage.last)
      assert_response :redirect
      assert_redirected_to new_user_session_url
    end

    sign_in users(:user_two)
    # Creation unauthorized
    assert_no_difference('Engage.count') do
      post engages_url, params: { engage: { artist_name: translations(:artist_rcsuccession_ja).title, music_id: @engage.music.id, engage_how: [engage_hows(:engage_how_composer).id, engage_hows(:engage_how_player).id], year: 1234 } }
      assert_response :redirect
      assert_redirected_to new_user_session_url
    end

    sign_in @editor

    # Creation success
    assert_difference('Engage.count', 2) do
      post engages_url, params: { engage: { artist_name: translations(:artist_rcsuccession_ja).title, music_id: @engage.music.id, engage_how: [engage_hows(:engage_how_composer).id, engage_hows(:engage_how_player).id], year: 1234 } }
      assert_response :redirect
      assert_redirected_to music_url(@engage.music) # Redirected to Music#show page
    end

    # Adding 'The' (which does not exist in DB) is accepted
    assert_difference('Engage.count', 1) do
      post engages_url, params: { engage: { artist_name: 'The '+translations(:artist_rcsuccession_ja).title, music_id: @engage.music.id, engage_how: [engage_hows(:engage_how_singer_cover).id], year: 1234 } }
    end

    # Delete success
    assert_difference('Engage.count', -1) do
      delete engage_url(Engage.last)
      assert_response :redirect
      assert_redirected_to engages_url # Redirected to Engage
    end
  end

  test "should fail to delete" do
    sign_in @editor
    eng = engages( :engage_ai_story )
    assert_raises(ActiveRecord::DeleteRestrictionError){
      delete engage_url(eng)}
    #assert_difference('Engage.count', -1) do
    #  delete engage_url(eng)
    #  assert_response :redirect
    #  assert_redirected_to engages_url # Redirected to Engage
    #end
  end
end
