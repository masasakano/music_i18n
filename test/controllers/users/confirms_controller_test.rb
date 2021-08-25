require 'test_helper'

class Users::ConfirmsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should not patch update" do
    patch users_confirm_url(1)
    assert_not (200...299).include?(response.code)  # maybe :redirect or 403 forbidden or 401 Unauthorized
    #assert_response :redirect
  end

  test "should update confirm" do
    user2 = users(:user_two)
    assert_not user2.confirmed?
    @moderator = roles(:general_ja_moderator).users.first  # Moderator can confirm
    sign_in(@moderator)
    patch users_confirm_url(user2.id)
    assert_not (200...299).include?(response.code)  # maybe :redirect or 403 forbidden or 401 Unauthorized
    user2.reload
    assert     user2.confirmed?
    sign_out(@moderator)
  end
end
