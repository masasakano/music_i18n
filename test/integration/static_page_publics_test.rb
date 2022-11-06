require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class StaticPagePublicsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @validator = W3CValidators::NuValidator.new
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "should show public static_page" do
    static_page = static_pages( :static_about_us )
    get '/'+static_page.mname
    assert_response :success

    csssel = css_select('h1')
    assert  csssel.first.text.include? static_page.title

    csssel = css_select('body')
    assert  csssel.first.text.include? static_page.content

    w3c_validate("public static_page")  # defined in test_helper.rb (see for debugging help)
  end

  test "admin can see the index page" do
    @admin     = roles(:syshelper).users.first  # Only Admin can read/manage
    sign_in @admin

    get '/static_page_publics'  # see routes.rb
    assert_response :success

    ## Fixture 1
    static_page = static_pages( :static_one )
    assert_equal 'en_one', static_page.form_id_model
    csssel = css_select('dt#en_one')
    assert_not  csssel.empty?
    assert_match(/#{Regexp.quote(static_page.title)}/, csssel.first.text)

    csssel = css_select('dd#summary_'+static_page.form_id_model)
    assert_not  csssel.empty?
    assert_match(/#{Regexp.quote(static_page.summary)}/, csssel.first.text)

    ## Fixture 2
    static_page = static_pages(:static_about_us )
    csssel = css_select('dd#summary_'+static_page.form_id_model)
    assert_not  csssel.empty?
    assert_match(/#{Regexp.quote(static_page.content)}/, csssel.first.text, 'Content should be displayed because no summary is defined in Fixture, but?')
  end
end
