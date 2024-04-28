require 'test_helper'

class HaramiVidsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    #@editor = roles(:general_ja_editor).users.first  # Editor can manage.
    @editor_harami = users(:user_editor)
    @editor = @editor_harami 
    @moderator_harami = users(:user_moderator)
    @def_params = {"langcode"=>"ja", "title"=>"", "uri"=>"", "release_date(1i)"=>"2024", "release_date(2i)"=>"4", "release_date(3i)"=>"28", "duration"=>"", "place.prefecture_id.country_id"=>"0", "place.prefecture_id"=>"", "place"=>"", "form_channel_owner"=>"3", "form_channel_type"=>"12", "form_channel_platform"=>"1", "form_events"=>"", "artist_name"=>"", "form_engage_hows"=>"72", "form_engage_year"=>"", "form_contribution"=>"", "artist_name_collab"=>"", "form_instrument"=>"2", "form_play_role"=>"2", "music_name"=>"", "music_timing"=>"", "uri_playlist_en"=>"", "uri_playlist_ja"=>"", "note"=>""}

  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get harami_vids_url
    assert_response :success

    assert css_select("table.datagrid.harami_vids_grid tbody tr").any?{|esel| esel.css('td.title_en')[0].text.blank? && !esel.css('td.title_ja')[0].text.blank?}, "Some EN titles should be blank (where JA titles are NOT blank), but..."
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

  test "should destroy harami_vid if privileged" do
    assert_no_difference('HaramiVid.count') do
      delete harami_vid_url(@harami_vid)
      assert_response :redirect
    end
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_no_difference('HaramiVid.count', "editor cannot destroy, but...") do
      assert_no_difference('HaramiVidMusicAssoc.count') do
        assert_difference('Music.count', 0) do
          assert_difference('Place.count', 0) do
            delete harami_vid_url(@harami_vid)
            my_assert_no_alert_issued(screen_test_only: true)  # defined in /test/test_helper.rb
          end
        end
      end
    end
    sign_out @editor

    sign_in @moderator_harami  # Harami moderator can destroy.
    assert Ability.new(@moderator_harami).can?(:destroy, @harami_vid)
    assert_difference('HaramiVid.count', -1, "HaramiVid should decraese by 1, but...") do
      assert_difference('HaramiVidMusicAssoc.count', -1) do
        assert_difference('Music.count', 0) do
          assert_difference('Place.count', 0) do
            delete harami_vid_url(@harami_vid)
            my_assert_no_alert_issued(screen_test_only: true)  # defined in /test/test_helper.rb
          end
        end
      end
    end
  end

end

