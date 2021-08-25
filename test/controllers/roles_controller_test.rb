require 'test_helper'

class RolesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @role = roles(:translator) # editor in translation
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get roles_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should fail everything" do
    begin
      get '/users/sign_in'
      sign_in Role[:moderator, RoleCategory::MNAME_TRANSLATION].users.first  # moderator
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get roles_url
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
      get new_role_url
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
      get role_url(Role.first)
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    ensure
      Rails.cache.clear
    end
  end

  #test "should get new" do
  #  get new_role_url
  #  assert_response :success
  #end

  #test "should create role" do
  #  assert_difference('Role.count') do
  #    post roles_url, params: { role: { name: @role.name, note: @role.note, role_category_id: @role.role_category_id, weight: @role.weight } }
  #  end

  #  assert_redirected_to role_url(Role.last)
  #end

  #test "should show role" do
  #  get role_url(@role)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_role_url(@role)
  #  assert_response :success
  #end

  #test "should update role" do
  #  patch role_url(@role), params: { role: { name: @role.name, note: @role.note, role_category_id: @role.role_category_id, weight: @role.weight } }
  #  assert_redirected_to role_url(@role)
  #end

  #test "should destroy role" do
  #  assert_difference('Role.count', -1) do
  #    delete role_url(@role)
  #  end

  #  assert_redirected_to roles_url
  #end
end
