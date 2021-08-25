require 'test_helper'

class SexesControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------
  # add from here
  include Devise::Test::IntegrationHelpers

  setup do
    @sex = Sex.second  # Sex.find(1)
    @admin = users(:user_sysadmin)
    @general_moderator = users(:user_moderator)  # moderator/general_ja, who is not qualified to manimuplate this model though can read
    #sign_in @general_moderator
    #get '/users/sign_in'
    ##post user_session_url
    ### If you want to test that things are working correctly, uncomment this below:
    ##follow_redirect!
    ##assert_response :success
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get sexes_url
    assert_not (200...299).include?(response.code)  # maybe :redirect or 403 forbidden 
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "moderator and admin should get index" do
    sign_in @general_moderator
    get sexes_url
    assert_response :success
    sign_out @general_moderator

    sign_in @admin
    get sexes_url
    assert_response :success
  end

  test "should fail to get new" do
    get new_sex_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get new_sex_url
    assert_redirected_to root_url
  end

  test "admin should get new" do
    sign_in @admin
    get new_sex_url
    assert_response :success
  end

  test "should fail to create sex" do
    sign_in @general_moderator
    assert_difference('Sex.count', 0) do
      post sexes_url, params: { sex: { iso5218: @sex.iso5218, note: @sex.note } }
    end
    assert_redirected_to root_url
  end

  test "admin should create sex" do
    sign_in @admin
    assert_difference('Sex.count') do
      post sexes_url, params: { sex: { iso5218: 9998 } }
    end
    assert_redirected_to sex_url(Sex.last)

    assert_difference('Sex.count', 0) do
        post sexes_url, params: { sex: { iso5218: nil } }
    end
    assert_response :unprocessable_entity  # Because of failure due to null constraint (default used to be :success till Rails 6.0?)

    assert_difference('Sex.count', 0) do
        post sexes_url, params: { sex: { iso5218: @sex.iso5218 } }
    end
    assert_response :unprocessable_entity  # Because of failure due to unique constraint
  end

  test "should fail to show sex" do
    get sex_url(@sex)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "moderator and admin should show sex" do
    sign_in @general_moderator
    get sex_url(@sex)
    assert_response :success
    sign_out @general_moderator

    sign_in @admin
    get sex_url(@sex)
    assert_response :success
  end

  test "should fail to get edit" do
    get edit_sex_url(@sex)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get edit_sex_url(@sex)
    assert_redirected_to root_url
  end

  test "admin should get edit" do
    sign_in @admin
    get edit_sex_url(@sex)
    assert_response :success
  end

  test "should fail to update sex" do
    patch sex_url(@sex), params: { sex: { iso5218: 997 } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    patch sex_url(@sex), params: { sex: { iso5218: 997 } }
    assert_redirected_to root_url
  end

  test "admin should update sex" do
    sign_in @admin
    patch sex_url(@sex), params: { sex: { iso5218: 9997 } }
    assert_redirected_to sex_url(@sex)

    patch sex_url(@sex), params: { sex: { iso5218: Sex.third.iso5218, note: 'random' } }
    assert_response :unprocessable_entity  # Because of failure due to unique constraint
  end

  test "should fail to destroy sex" do
    assert_difference('Sex.count', 0) do
      delete sex_url(@sex)
    end
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    assert_difference('Sex.count', 0) do
      delete sex_url(@sex)
    end
    assert_redirected_to root_url
  end

  test "admin should destroy sex" do
    sign_in @admin

    post sexes_url, params: { sex: { iso5218: 9998 } }
    assert_difference('Sex.count', -1) do
      delete sex_url(Sex.last)
    end
    assert_redirected_to sexes_url

    assert_difference('Sex.count', 0) do
      assert_raise(ActiveRecord::DeleteRestrictionError){  # Cannot delete record because of dependent artists
        delete sex_url(@sex) }
    end
    # => no response
  end
end
