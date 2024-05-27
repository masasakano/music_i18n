# coding: utf-8
require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class TranslationIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "editor can view most of a page in show" do
    user  = users(:user_translator)
    trans = translations(:music_kampai_en1)
    music = musics(:music_kampai)
    assert_equal user,  trans.create_user,  'sanity test of a translation user fails...'
    assert_equal music, trans.translatable, 'sanity test of a translation music fails...'

    get translation_url(trans)
    assert_response :redirect
    flash.clear

    sign_in(user)
    get translation_url(trans)
    assert_response :success

    csssel = css_select('div#body_main dl')
    css2 = csssel[0].css('dt')
    assert_not css2.any?{|i| i.text.include? 'Weight'}

    csssel = css_select('div#body_main table thead tr')
    assert_not csssel.any?{|i| i.text.include? 'Weight'}

    w3c_validate(user.display_name)  # defined in test_helper.rb (see for debugging help)
  end

  test "editor can view all of a page in show" do
    user  = users(:user_moderator_translation)
    trans = translations(:music_kampai_en1)
    music = musics(:music_kampai)

    sign_in(user)
    get translation_url(trans)
    assert_response :success

    csssel = css_select('div#body_main dl')
    css2 = csssel[0].css('dt')
    assert css2.any?{|i| i.text.include? 'Weight'}

    csssel = css_select('div#body_main table thead tr')
    assert csssel.any?{|i| i.text.include? 'Weight'}

    w3c_validate(user.display_name)  # defined in test_helper.rb (see for debugging help)
  end
end

