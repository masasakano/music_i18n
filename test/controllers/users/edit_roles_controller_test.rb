# coding: utf-8
require "test_helper"

class Users::EditRolesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @moderator = roles(:general_ja_editor).users.first  # Editor can manage.
    @role_admin = roles(:admin)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to patch update" do
    patch users_edit_role_url(User.first)
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    assert_redirected_to new_user_session_path  # Devise sing_in route

    sign_in users(:user_editor_general_ja)  # Editor cannot manage anyone else.
    patch users_edit_role_url(users(:user_editor_general_ja2))
    assert_response :redirect
    # assert_redirected_to root_url  # Root URL?? (because already signed in)
  end

  test "editor should manage update self" do
    rolec_g = role_categories(:rc_general_ja)
    role = roles( :general_ja_editor )
    role_m = roles( :general_ja_moderator )
    user = users(:user_editor_general_ja)
    assert_equal 1, user.roles.count    # fixture sanity check
    assert_equal role, user.roles.first #
    assert user.qualified_as?(role)     #

    sign_in user  # Editor can manage themselves
    patch users_edit_role_url(user)
    assert_response :redirect
    assert_redirected_to user_path(user)

    # Fails
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {"role_ROOT"=>@role_admin.id.to_s,})
      assert_redirected_to user_path(user)
    }
    # Fails in promoting
    key_g = "role_"+rolec_g.mname
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => role_m.id.to_s,})
      user.reload
      assert_equal role, user.roles.first
    }
    # Succeeds in cancelling
    key_g = "role_"+rolec_g.mname
    assert_difference('UserRoleAssoc.count', -1){
      patch users_edit_role_url(user, params: {key_g => "-1",})
      user.reload
      assert_equal 0, user.roles.size
    }
  end

  test "moderator should manage update others" do
    rolec_g = role_categories(:rc_general_ja)
    rolec_h = role_categories(:rolecattwo)
    role_m = roles( :general_ja_moderator )
    role_e = roles( :general_ja_editor )
    user      = users(:user_editor_general_ja)
    user_self = users(:user_moderator_general_ja)
    assert_equal 1, user.roles.count    # fixture sanity check
    assert_equal role_e, user.roles.first # fixture sanity check

    key_g = "role_"+rolec_g.mname
    key_h = "role_"+rolec_h.mname

    sign_in user_self
    assert user_self.moderator?

    # Succeed (cancel the Role)
    assert_difference('UserRoleAssoc.count', -1){
      patch users_edit_role_url(user, params: {key_g => "-1",})
      assert_equal 0, user.roles.count
      user.reload
      assert_redirected_to user_path(user)
    }

    # Fails (sysadmin)
    sysadmin = users(:user_sysadmin)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(sysadmin, params: {key_g => "-1",})
      user.reload
      assert_response :redirect
      assert_redirected_to user_path(sysadmin)
    }

    # Fails (promote to a Role that he is not qualified as)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_h => roles(:translator).id.to_s,})
      user.reload
      assert_equal 0, user.roles.count
    }

    # Fails (promote to a Role that he is not qualified as: key is fabricated)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => roles(:translator).id.to_s,})
      user.reload
      assert_equal 0, user.roles.count
    }

    # Succeed (promote to his subordinate)
    assert_difference('UserRoleAssoc.count', 1){
      patch users_edit_role_url(user, params: {key_g => role_e.id.to_s,})
      user.reload
      assert_equal role_e, user.roles.first
    }

    # Succeed (no change)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => role_e.id.to_s,})
      user.reload
      assert_equal role_e, user.roles.first
    }

    # Succeed (promote to the same as self)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => role_m.id.to_s,})
      user.reload
      assert_equal role_m, user.roles.first  # changed.
    }

    # Fails (demote someone at the same rank)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => role_e.id.to_s,})
      user.reload
      assert_equal role_m, user.roles.first
    }

    # Fails (demote someone at the same rank)
    assert_difference('UserRoleAssoc.count', 0){
      patch users_edit_role_url(user, params: {key_g => "-1",})
      user.reload
      assert_equal role_m, user.roles.first
    }
  end
end

