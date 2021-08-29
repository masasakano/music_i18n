require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class HaramiVidsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "can see the new page" do
    get new_harami_vid_path
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    follow_redirect!
    assert_response :success

    #log_in_as( users(:user_sysadmin) )
    sign_in( users(:user_sysadmin) )
    get new_harami_vid_path
    assert_response :success
    assert_equal 1, css_select('div#div_select_prefecture').size
    assert_equal 'field', css_select('div#div_select_prefecture').first.attributes['class'].value # class="field"
    # assert_select "h1", "Welcome#index"
  end
end
