require "test_helper"

class PageFormatsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------
  # add from here
  include Devise::Test::IntegrationHelpers

  setup do
    @page_format = page_formats(:page_format_full_html)
    @admin = users(:user_sysadmin)
    @general_moderator = users(:user_moderator)  # moderator/general_ja, who is not qualified to manimuplate this model
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get page_formats_url
    assert_not (200...299).include?(response.code)  # maybe :redirect or 403 forbidden 
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get page_formats_url
    assert_redirected_to root_url
  end

  test "admin should get index" do
    sign_in @admin
    get page_formats_url
    assert_response :success
  end

  test "should fail to get new" do
    get new_page_format_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get new_page_format_url
    assert_redirected_to root_url
  end

  test "admin should get new" do
    sign_in @admin
    get new_page_format_url
    assert_response :success
  end

  test "should fail to create page_format" do
    sign_in @general_moderator
    assert_difference('PageFormat.count', 0) do
      post page_formats_url, params: { page_format: { mname: @page_format.mname, note: @page_format.note } }
    end
    assert_redirected_to root_url
  end

  test "admin should create page_format" do
    sign_in @admin
    assert_difference('PageFormat.count') do
      post page_formats_url, params: { page_format: { mname: 'tekito' } }
    end
    assert_redirected_to page_format_url(PageFormat.last)

    assert_difference('PageFormat.count', 0) do
        post page_formats_url, params: { page_format: { mname: nil } }
    end
    assert_response :unprocessable_entity  # Because of failure due to null constraint

    assert_difference('PageFormat.count', 0) do
        post page_formats_url, params: { page_format: { mname: @page_format.mname } }
    end
    assert_response :unprocessable_entity  # Because of failure due to unique constraint
  end

  test "should fail to show page_format" do
    get page_format_url(@page_format)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get page_format_url(@page_format)
    assert_redirected_to root_url
  end

  test "moderator and admin should show page_format" do
    sign_in @admin
    get page_format_url(@page_format)
    assert_response :success
  end

  test "should fail to get edit" do
    get edit_page_format_url(@page_format)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    get edit_page_format_url(@page_format)
    assert_redirected_to root_url
  end

  test "admin should get edit" do
    sign_in @admin
    get edit_page_format_url(@page_format)
    assert_response :success
  end

  test "should update page_format" do
    patch page_format_url(@page_format), params: { page_format: { mname: 'tekito2' } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    patch page_format_url(@page_format), params: { page_format: { mname: 'tekito2' } }
    assert_redirected_to root_url
  end

  test "admin should update page_format" do
    sign_in @admin
    patch page_format_url(@page_format), params: { page_format: { mname: 'tekito' } }
    assert_redirected_to page_format_url(@page_format)

    sign_in @admin
    patch page_format_url(@page_format), params: { page_format: { mname: page_formats(:page_format_filtered_html).mname, note: 'random' } }
    assert_response :unprocessable_entity  # Because of failure due to unique constraint
  end

  test "should fail to destroy page_format" do
    assert_difference('PageFormat.count', 0) do
      delete page_format_url(@page_format)
    end
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @general_moderator
    assert_difference('PageFormat.count', 0) do
      delete page_format_url(@page_format)
    end
    assert_redirected_to root_url
  end

  test "admin should destroy page_format" do
    sign_in @admin

    post page_formats_url, params: { page_format: { mname: 'tekito' } }
    assert_difference('PageFormat.count', -1) do
      delete page_format_url(PageFormat.last)
    end
    assert_redirected_to page_formats_url

    assert_raises(ActiveRecord::DeleteRestrictionError){ # Cannot delete record because of dependent static_pages
      p delete(page_format_url(@page_format)) }
  end
end

