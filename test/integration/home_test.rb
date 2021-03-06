# coding: utf-8
require "test_helper"
require 'w3c_validators'

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class ArtistsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @validator = W3CValidators::NuValidator.new
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "anyone can view a page" do
    get root_url
    _can_view_core(nil)
  end

  test "harami-editor can view" do
    user = users(:user_editor) # Harami editor (not translator)
    _can_view_core(user)
    csssel = css_select('div#navbar_upper_user')
    assert_includes csssel[0].text, 'Places'
    assert_includes csssel[0].text, 'HaramiVids'
    assert_not_includes csssel[0].text, 'Translations'
    assert_not_includes csssel[0].text, 'Users'
    assert_not_includes csssel[0].text, 'StaticPages'
  end

  test "harami-moderator can view" do
    user = users(:user_moderator) # Harami moderator (not translator)
    _can_view_core(user)
    csssel = css_select('div#navbar_upper_user')
    assert_includes csssel[0].text, 'Places'
    assert_includes csssel[0].text, 'HaramiVids'
    assert_includes csssel[0].text, 'Harami1129s'
    assert_not_includes csssel[0].text, 'Translations'
    assert_includes csssel[0].text, 'Users'
    assert_not_includes csssel[0].text, 'StaticPages'
  end

  test "moderator-translation can view" do
    user = users(:user_moderator_translation) # Harami moderator (not translator)
    _can_view_core(user)
    csssel = css_select('div#navbar_upper_user')
    assert_includes csssel[0].text, 'Places'
    # assert_not_includes csssel[0].text, 'HaramiVids'  ############## This should be the case. Check it out!
    assert_not_includes csssel[0].text, 'Harami1129s'
    assert_includes csssel[0].text, 'Translations'
    assert_includes csssel[0].text, 'Users'
    assert_not_includes csssel[0].text, 'StaticPages'
  end

  test "sysadmin can view" do
    user = users(:user_sysadmin)
    _can_view_core(user)
    csssel = css_select('div#navbar_top')
    assert_includes csssel[0].text, 'Admin' # Admin_panel
    csssel = css_select('div#navbar_upper_user')
    assert_includes csssel[0].text, 'Places'
    assert_includes csssel[0].text, 'HaramiVids'
    assert_includes csssel[0].text, 'Harami1129s'
    assert_includes csssel[0].text, 'Translations'
    assert_includes csssel[0].text, 'Users'
    assert_includes csssel[0].text, 'StaticPages'
  end

  def _can_view_core(user=nil)
    dname = (user ? user.display_name : 'Anonymous')
    sign_in(user) if user
    get root_url
    assert_response :success
    w3c_validate(dname)  # defined in test_helper.rb (see for debuggin help)

    csssel = css_select('div#navbar_top')
    assert_equal((user ? 1 : 0), csssel.size)
    assert_includes(csssel[0].text, 'Log out') if user

    csssel = css_select('div#navbar_upper_user')
    assert_equal((user ? 1 : 0), csssel.size)

    csssel = css_select('div#language_switcher_top')
    assert_equal 1, csssel.size
    assert_includes csssel[0].text, 'English'
    css1 = csssel[0].css('a')
    assert_equal 1, css1.size
    assert_includes css1.text, '?????????'

    csssel = css_select('div#navbar_upper_any')
    assert_equal 1, csssel.size
    cssmenuli = csssel[0].css('ul li')
    assert_operator cssmenuli.size, '>', 0
    assert csssel[0].css('ul li.nav-item a').any?{|i| i.text.include? 'About '}, 'Failed for '+dname

    css_a = csssel[0].css('ul li.nav-item a.dropdown-item')
    assert css_a.any?{|i| i.text.include? 'Terms of '}
    assert css_a.any?{|i| i.attributes['href'].text.include? File.basename(StaticPagesController.public_path('editing_guideline'))} if user

    csssel = css_select('div#body_main div#home-intro')
    assert_equal 1, csssel.size
    if user
      assert_not_includes csssel[0].text, 'Sign up'
    else
      assert_includes     csssel[0].text, 'Sign up'
    end

    csssel = css_select('div#body_main table thead')
    assert_equal 1, csssel.size
    css2 = csssel[0].css('th')
    assert css2.any?{|i| i.text.include? 'Title'}
    assert css2.any?{|i| i.text.include? 'Artists'}
    assert css2.any?{|i| i.text.include? 'Musics'}

    csssel = css_select('div#home_bottom')
    assert_equal 1, csssel.size
    if user
      assert_includes     csssel[0].text, I18n.t('log_out')
      assert_not_includes csssel[0].text, 'Log in'
      assert_not_includes csssel[0].text, 'Sign up'
    else
      assert_not_includes csssel[0].text, I18n.t('log_out')
      assert_includes     csssel[0].text, 'Log in'
      assert_includes     csssel[0].text, 'Sign up'
    end
  end
end
