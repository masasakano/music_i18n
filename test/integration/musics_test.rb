require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class MusicsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "can see the new page" do
    artist_ai = artists(:artist_ai)
    path = new_music_path(music: {artist_id: artist_ai.id}) # as in /app/views/artists/show.html.erb

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    follow_redirect!
    assert_response :success

    #log_in_as( users(:user_sysadmin) )
    sign_in( users(:user_sysadmin) )
    #sign_in( users(:user_editor) )
    get path
    assert_response :success
    
    # <input value="AI (ID=7)" disabled="disabled" type="text" name="music[artist_name]" id="music_artist_name">
    csssel = css_select('input#music_artist_name')
    assert_equal 1, csssel.size
    assert_equal 'disabled', csssel.first.attributes['disabled'].value # disabled="disabled"
    artist_title = artist_ai.title_or_alt
    assert_match(/.*[a-z]+.* \(ID=#{artist_ai.id}\)\z/i, csssel.first.attributes['value'].value) # value="AI (ID=7)"
    assert_select "h1", 'New Music for Artist '+artist_title
  end
end
