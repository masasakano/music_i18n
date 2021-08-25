require 'test_helper'

class RoleCategoriesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @role_category = role_categories(:rolecattwo)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get role_categories_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should fail everything" do
    begin
      get '/users/sign_in'
      sign_in Role[:moderator, :harami].users.first  # moderator
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get roles_url
      assert_not (200...299).include?(response.code.to_i), "Response.code=#{response.code}"  # maybe :redirect or 403 forbidden 
      get new_role_url
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
      get role_url(Role.first)
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    ensure
      Rails.cache.clear
    end
  end

  #test "should get new" do
  #  get new_role_category_url
  #  assert_response :success
  #end

  #test "should create role_category" do
  #  assert_difference('RoleCategory.count') do
  #    post role_categories_url, params: { role_category: { name: @role_category.name, note: @role_category.note } }
  #  end

  #  assert_redirected_to role_category_url(RoleCategory.last)
  #end

  #test "should show role_category" do
  #  get role_category_url(@role_category)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_role_category_url(@role_category)
  #  assert_response :success
  #end

  #test "should update role_category" do
  #  patch role_category_url(@role_category), params: { role_category: { name: @role_category.name, note: @role_category.note } }
  #  assert_redirected_to role_category_url(@role_category)
  #end

  #test "should destroy role_category" do
  #  assert_difference('RoleCategory.count', -1) do
  #    delete role_category_url(@role_category)
  #  end

  #  assert_redirected_to role_categories_url
  #end
end
