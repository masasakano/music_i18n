require 'test_helper'

class HaramiVidsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @validator = W3CValidators::NuValidator.new

    @def_place = places(:tocho)
    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "uri"=>"https://youtu.be/InitialUri", "duration"=>"56",
      "release_date(1i)"=>"2024", "release_date(2i)"=>"2", "release_date(3i)"=>"28",
      "place.prefecture_id.country_id"=>@def_place.country.id.to_s,
      "place.prefecture_id"=>@def_place.prefecture_id.to_s, "place"=>@def_place.id.to_s,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      "form_events" => events(:ev_harami_lucky2023).id.to_s,
      "artist_name"=>"",
      "form_engage_hows"=>EngageHow.default(:HaramiVid).id.to_s,
      "form_engage_year"=>"1988", "form_contribution"=>"0.5678",
      "artist_name_collab"=>"",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "music_name"=>"", "music_timing"=>"1234",
      "note"=>"",
       # "uri_playlist_en"=>"", "uri_playlist_ja"=>"",
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
      "title"=>"Initial test-title", "langcode"=>"ja",
    }.with_indifferent_access)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get harami_vids_url
    assert_response :success, "Should be open to public, but..."

    assert css_select("table.datagrid.harami_vids_grid tbody tr").any?{|esel| esel.css('td.title_en')[0].text.blank? && !esel.css('td.title_ja')[0].text.blank?}, "Some EN titles should be blank (where JA titles are NOT blank), but..."
  end

  test "should get new" do
    get new_harami_vid_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@trans_moderator, @moderator_ja].each do |user|
      sign_in user
      get new_harami_vid_url
      assert_response :redirect, "should be banned for #{user.display_name}, but allowed..."
      assert_redirected_to root_path
      sign_out user
    end

    sign_in @editor_harami
    get new_harami_vid_url
    assert_response :success
  end

  test "should create harami_vid" do
    assert_no_difference('HaramiVid.count') do
      post harami_vids_url, params: { harami_vid: @def_create_params }
    end
    assert_redirected_to new_user_session_path

    [@trans_moderator, @moderator_ja].each do |user|
      sign_in user
      assert_no_difference('HaramiVid.count') do
        post harami_vids_url, params: { harami_vid: @def_create_params }
      end
      assert_response :redirect, "should be banned for #{user.display_name}, but allowed..."
      assert_redirected_to root_path
      sign_out user
    end

    sign_in @editor_harami
    run_test_create_null(Channel, extra_colnames: %i(title langcode)) # defined in /test/helpers/controller_helper.rb
    ## null imput should fail.

#if false # temporary skip
if true
    assert_no_difference("HaramiVid.count") do
      post harami_vids_url, params: { harami_vid: @def_create_params.merge({title: 'some', uri: 'https://youtu.be/naiyo', form_channel_owner: ChannelOwner.order(:id).last.id+1})}
      assert_response :unprocessable_entity
    end
end

    #hsnew = {title: 'a new one', uri: "https://youtu.be/mytest1", note: "newno"}
    hsnew = {note: "newno"}
    assert_no_difference("Channel.count") do  # existing Channel is found
      assert_difference("HaramiVid.count") do
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      end
    end
    mdl_last = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal "newno", mdl_last.note
    assert_equal @def_create_params[:title],  mdl_last.title
    assert_equal Channel.default(:HaramiVid), mdl_last.channel

    # A new channle is temporarily created but must be rolled-back because HaramiVid was not created after all.
    hsnew = {form_channel_platform: channel_platforms(:channel_platform_facebook).id, note: "fail due to unique uri"}
    assert_no_difference("Channel.count") do
      assert_no_difference("HaramiVid.count") do
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
        assert_response :unprocessable_entity

        uri2test = ApplicationHelper.normalized_uri_youtube(@def_create_params[:uri], long: true, with_scheme: true, with_host: true)
        assert_includes uri2test, "https://www.youtube.com/watch?v=", 'sanity check'
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew).merge({uri: uri2test})}
        assert_response :unprocessable_entity
      end
    end
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

    sign_in @editor_harami
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
    sign_out @editor_harami

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

