# coding: utf-8
require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class ArtistsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @artist_ai = artists(:artist_ai)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "can edit an artist as superuser" do
    path = edit_artist_path(@artist_ai) # as in /en/artists/XXX/edit

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    follow_redirect!
    assert_response :success

    user = users(:user_sysadmin)
    sign_in(user)
    get path
    assert_response :success

    csssel = css_select('table tbody th')
    assert_includes csssel[0].text, '日本語'
    assert_match(/add translation/i, csssel[0].css('form input')[0].attributes['value'].text)
    assert_includes csssel[1].text, 'English'
    assert_match(/add translation/i, csssel[1].css('form input')[0].attributes['value'].text)

    csssel = css_select('table tbody tr')
    assert_not   csssel[1].css('td a').empty?
    assert_includes csssel[1].css('td a').text, 'Edit'  # Japanese
    assert_includes csssel[3].css('td a').text, 'Edit'  # English
  end

  test "can edit an artist as an editor and moderator" do
    user = users(:user_editor) # Harami editor (not translator)
    _can_edit_core(user)

    user = users(:user_moderator) # Harami moderator (not translator)
    _can_edit_core(user)
  end

  def _can_edit_core(user)
    sign_in(user)
    path = edit_artist_path(@artist_ai)  # like /en/artists/XXX/edit
    get path
    assert_response :success, "path (#{path}) should be accessible but?"

    csssel = css_select('table tbody th')
    assert_includes csssel[0].text, '日本語'
    assert_match(/add translation/i, csssel[0].css('form input')[0].attributes['value'].text)
    assert_includes csssel[1].text, 'English'
    assert   csssel[1].css('form').empty?

    csssel = css_select('table tbody tr')
    assert_includes     csssel[1].css('td a').text, 'Edit'  # Japanese
    assert_not_includes csssel[3].css('td a').text, 'Edit', "Should be no 'Edit' by #{user.display_name}, but?"  # English
    sign_out(user)
  end

  test "cannot edit an artist as an editor of Translator" do
    path = artist_path(@artist_ai)  # show
    get path
    assert_response :success, "path (#{path}) should be accessible but?"

    path = edit_artist_path(@artist_ai) # as in /en/artists/XXX/edit
    get path
    assert_response :redirect
  end

end
