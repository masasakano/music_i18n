require 'test_helper'

class PrefecturesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @prefecture = prefectures(:tokyo)
    @moderator = roles(:general_ja_moderator).users.first  # (General) Editor can manage some of them.
    @editor = roles(:general_ja_editor).users.first  # (General) Editor can manage some of them.
    @syshelper = users(:user_syshelper) #User.roots.first   # an admin can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get prefectures_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should get index" do
    begin
      get '/users/sign_in'
      sign_in Role[:editor, RoleCategory::MNAME_GENERAL_JA].users.first  # editor/general_ja
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get prefectures_url
      assert_response :success
      get new_prefecture_url
      assert_response :success
      get prefecture_url(Prefecture.first)
      assert_response :success
    ensure
      Rails.cache.clear
    end
  end

  test "should fail to get new if not logged in" do
    get new_prefecture_url
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  #test "should create prefecture" do
  #  assert_difference('Prefecture.count') do
  #    post prefectures_url, params: { prefecture: { country_id: @prefecture.country_id, note: @prefecture.note } }
  #  end

  #  assert_redirected_to prefecture_url(Prefecture.last)
  #end

  test "should show prefecture" do
    # show is NOT activated for non-logged-in user (or non-editor?).
    get prefecture_url(@prefecture)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get prefecture_url(@prefecture)
    assert_response :success
  end

  test "should fail/succeed to get edit" do
    get edit_prefecture_url(@prefecture)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get edit_prefecture_url(@prefecture)
    assert_response :success
  end

  test "should update prefecture if editor" do
    pref_liverpool = prefectures(:liverpool)

    updated_at_orig = pref_liverpool.updated_at
    country_orig = pref_liverpool.country
    note2 = 'Edited new prefecture note'
    patch prefecture_url(pref_liverpool), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s } }

    assert_response :redirect  # because not privileged
    assert_redirected_to new_user_session_path

    sign_in @editor
    patch prefecture_url(pref_liverpool), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s } }
    assert_response :redirect
    assert_redirected_to prefecture_url(pref_liverpool)

    pref_liverpool.reload
    assert_operator updated_at_orig, :<, pref_liverpool.updated_at
    assert_equal note2, pref_liverpool.note
    assert_not_equal country_orig, pref_liverpool.country
    assert_equal Country['AUS'], pref_liverpool.country
  end

  test "should update nothing for prefecture in Japan" do
    note2 = 'Edited new prefecture note'
    sign_in @moderator # Even moderator is not allowed to change parameters for prefectures in Japan.

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s, iso3166_loc_code: 9998 } }
    assert_response :unprocessable_entity

    patch prefecture_url(@prefecture), params: { prefecture: { country_id: Country['AUS'].id.to_s } }
    assert_response :unprocessable_entity, "moderatora cannot change a JPN prefecure to another country"

    patch prefecture_url(@prefecture), params: { prefecture: { iso3166_loc_code: 9998 } }
    assert_response :unprocessable_entity, "moderatora cannot change iso3166_loc_code of a JPN prefecure"

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2 } }
    assert_response :unprocessable_entity, "moderatora cannot change note of a JPN prefecure"

    pref_liverpool = prefectures(:liverpool)
    patch prefecture_url(pref_liverpool), params: { prefecture: { country_id: Country['JPN'].id.to_s } }
    assert_response :unprocessable_entity, "moderatora cannot change the country of a non-JPN prefecure to Japan"
  end

  test "syshelper should update for prefecture in Japan" do
    note2 = 'Edited new prefecture note'
    sign_in @syshelper # An admin is allowed to change parameters for prefectures in Japan.

    pref_orig = @prefecture.dup
    orig_updated_at1 = @prefecture.updated_at

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s, iso3166_loc_code: 9998 } }
    assert_response :redirect
    assert_redirected_to prefecture_url(@prefecture)

    @prefecture.reload
    assert_operator orig_updated_at1, :<, @prefecture.updated_at
    assert_not_equal pref_orig.iso3166_loc_code, @prefecture.iso3166_loc_code
    assert_equal     9998,                       @prefecture.iso3166_loc_code
    assert_equal note2, @prefecture.note
    assert_not_equal pref_orig.country, @prefecture.country
    assert_equal Country['AUS'], @prefecture.country

    orig_updated_at2 = @prefecture.updated_at
    patch prefecture_url(@prefecture), params: { prefecture: { note: "", country_id: Country['JPN'].id.to_s, iso3166_loc_code: pref_orig.iso3166_loc_code } }
    assert_response :redirect
    assert_redirected_to prefecture_url(@prefecture)

    @prefecture.reload
    assert_operator orig_updated_at2, :<, @prefecture.updated_at
    assert_equal pref_orig.iso3166_loc_code, @prefecture.iso3166_loc_code
    assert_equal pref_orig.country,          @prefecture.country
    assert_equal "",                         @prefecture.note
  end

  #test "should destroy prefecture" do
  #  assert_difference('Prefecture.count', -1) do
  #    delete prefecture_url(@prefecture)
  #  end

  #  assert_redirected_to prefectures_url
  #end
end
