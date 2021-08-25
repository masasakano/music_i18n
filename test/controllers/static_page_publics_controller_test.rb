require "test_helper"

class StaticPagePublicsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @static_page = static_pages(:static_about_us)
    @admin     = roles(:syshelper).users.first  # Only Admin can read/manage
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "only admin should get index" do
    get '/static_page_publics'  # see routes.rb
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    #assert_redirected_to root_url

    sign_in @admin
    get '/static_page_publics'  # see routes.rb
    assert_response :success
  end

  test "should show public static_page" do
    get '/about_us'
    assert_response :success
  end

end
