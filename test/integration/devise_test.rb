# coding: utf-8
require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class DeviseIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "get create user registration" do
    assert_equal '/ja/users/sign_up', '/ja'+new_user_registration_path.sub(/\?.+/, '')
    assert_equal '/users/sign_up?locale=ja', new_user_registration_path.sub(/(\?locale=)../, '\1ja')
    get new_user_registration_path.sub(/(\?locale=)../, '\1ja')
    # get '/ja'+new_user_registration_path.sub(/\?.+/, '')  # => ActionController::RoutingError
    assert_response :success
    assert_equal :en, I18n.locale
    css = css_select('div#devise_new_registration_accept_terms a').first
    assert_equal '/ja/terms_service', css.attributes['href'].text
    assert_equal I18n.t('terms_of_service', locale: :ja), css.text  # /config/locales/common.ja.yml : 利用規約
    css = css_select('div#devise_new_registration_accept_terms').first
    assert_includes css.text, I18n.t('read_agree_terms_html', locale: :ja)[-5..-1]

    #puts css_select('div#devise_new_registration_accept_terms a').first.to_html

    assert_difference('User.count', 1){
      min_length = Rails.application.config.devise.password_length.first # Password min: 6
      pw = '12' * min_length  # twice as long as the minimum
      post user_registration_path(params: {user: {email: 'test_cre@example.com', display_name: 'test_cre', password: pw, password_confirmation: pw }})
      assert_response :success  # meaning failure - has to retry
      assert_equal 1, css_select('.invalid-feedback').size

      ## Failure
      post user_registration_path(params: {user: {email: 'test_cre@example.com', display_name: 'test_cre', password: pw, password_confirmation: pw, accept_terms: "0" }})
      assert_response :success  # meaning failure - has to retry
      assert_equal 1, css_select('.invalid-feedback').size

      ## Failure
      pw = '12' * (min_length/2-1)  # shorter than as the minimum required length
      post user_registration_path(params: {user: {email: 'test_cre@example.com', display_name: 'test_cre', password: pw, password_confirmation: pw, accept_terms: "1" }})
      assert_response :success  # meaning failure - has to retry
      assert_includes css_select('div.alert-danger').text, I18n.t('simple_form.error_notification.default_message', locale: :ja)  # using simple_form
      assert_includes css_select('.invalid-feedback').text, I18n.t('errors.messages.too_short', locale: :ja, count: min_length)

      ## success
      pw = '12' * min_length  # twice as long as the minimum
      post user_registration_path(params: {user: {email: 'test_cre@example.com', display_name: 'test_cre', password: pw, password_confirmation: pw, accept_terms: "1" }})
      assert_empty css_select('div.alert-danger'), 'There should not be "以下の問題をチェックしてください", but?'
      assert_equal 0, css_select('.invalid-feedback').size

      assert_response :redirect
      assert_redirected_to :root
    }
    # puts @response.body # => <html><body>You are being <a href="http://www.example.com/?locale=ja">redirected</a>.</body></html>
  end

end
