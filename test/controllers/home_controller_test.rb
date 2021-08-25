require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get home_index_url
    assert_response :success
  end

  test "user with roles should get index" do
    user = roles(:general_ja_editor).users.first  # an Editor
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user

    user = roles(:general_ja_moderator).users.first  # a Moderator
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user

    user = users(:user_sysadmin)
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user
  end

end
