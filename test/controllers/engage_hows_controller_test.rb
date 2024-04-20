require "test_helper"

class EngageHowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @engage_how = engage_hows(:engage_how_1)
    @moderator = Role[:moderator, RoleCategory::MNAME_GENERAL_JA].users.first
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get engage_hows_url
    assert_response :redirect

    sign_in @moderator
    get engage_hows_url
    assert_response :success
  end

  test "should get new" do
    sign_in @moderator
    get new_engage_how_url
    assert_response :success
  end

  test "should create engage_how" do
    sign_in @moderator

    # Creation failure
    assert_raises(ActionController::ParameterMissing){ post engage_hows_url, params: { engage_how: { note: @engage_how.note } } }

    sign_in @moderator
    assert_no_difference('EngageHow.count') do
      post engage_hows_url, params: { translation: {is_orig: '1'}, engage_how: { note: @engage_how.note } }
    end
    #assert_match(/\bno langcode\b/i, flash.alert, "output: #{css_select('div#body_main').to_html}")
    assert_match(/\bno langcode\b/i, css_select('div#error_explanation ul').text, "output: #{css_select('div#body_main').to_html}")
    assert_response :unprocessable_entity # 422

    # Creation failures
    assert_no_difference('EngageHow.count') do
      post engage_hows_url, params: { translation: { langcode: 'ja', is_orig: '0', title: 'abc', alt_title: 'abc' }, engage_how: {note: ''} }
    end
    assert_response :unprocessable_entity # 422

    # Creation success
    assert_difference('EngageHow.count') do
      post engage_hows_url, params: { translation: { langcode: 'ja', is_orig: '-99', title: 'new test 1' }, engage_how: {note: ''} }
    end
    eh_last = EngageHow.last
    assert_redirected_to engage_how_url(eh_last)
    assert_operator eh_last, '<', EngageHow.unknown
    assert_operator eh_last, '>', EngageHow.where('id <> ?', eh_last).sort[-2] # In default, the weight, if unspecified, of a newly-created instance should be the second last.
    assert_equal 'new test 1', eh_last.title, "trans=#{eh_last.translations}"
  end

  test "should show engage_how" do
    sign_in @moderator
    get engage_how_url(@engage_how)
    assert_response :success
  end

  test "should get edit" do
    sign_in @moderator
    get edit_engage_how_url(@engage_how)
    assert_response :success
  end

  test "should update engage_how" do
    sign_in @moderator
    patch engage_how_url(@engage_how), params: { engage_how: { weight: 555, note: @engage_how.note } }
    assert_redirected_to engage_how_url(@engage_how)
    @engage_how.reload
    assert_equal 555, @engage_how.weight
  end

  test "should destroy engage_how" do
    sign_in @moderator
    assert_raises(ActiveRecord::DeleteRestrictionError){ delete engage_how_url(@engage_how) }
    assert_difference('EngageHow.count', 1) do
      neweng = EngageHow.create!()
    end

    # Moderator can't delete (only CRU is allowed).
    assert_difference('EngageHow.count', 0) do
      delete engage_how_url(@engage_how)
    end
    assert_response :redirect
    #assert_redirected_to engage_hows_url
  end
end
