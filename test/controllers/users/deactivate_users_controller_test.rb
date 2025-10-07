require 'test_helper'

class Users::DeactivateUsersControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @sysadmin = users(:user_sysadmin)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "sysadmin should get edit" do
    # NOTE: users_edit_deactivate_users_url(1) returns: http://www.example.com/users/1/deactivate_users/edit
    get users_edit_deactivate_users_path(@sysadmin)  # sysadmin
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    assert_response :redirect  # 302

    # Sign in as a sysadmin
    @user = @sysadmin
    sign_in(@user)
#print 'DEBUG00: user=';p @user
#print 'DEBUG01: path=';p users_edit_deactivate_users_path(@user)

    # NOTE: users_edit_deactivate_users_path(1) returns: /users/1/deactivate_users/edit
    get users_edit_deactivate_users_path(users(:user_moderator))  # Moderator's page
    assert (200...299).include?(response.code.to_i), "response:(200...299) !== #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@user.id)}"  # maybe :redirect or 403 forbidden 
    assert_response :success

    # Even sysadmin cannot access his own edit page to disable his account.
    get users_edit_deactivate_users_path(@user)  # sysadmin
    assert_not (200...299).include?(response.code.to_i), "response:(200...299) !== #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@user.id)}"  # maybe :redirect or 403 forbidden or 500
  end

  
  test "sysadmin should not delete oneself" do
    # Sign in as a sysadmin
    sign_in(@sysadmin)
    old_id   = @sysadmin.id

    delete users_destroy_deactivate_users_path(@sysadmin)
    assert_equal 500, response.code.to_i, "response:500 !== #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@sysadmin.id)}, maybe redirected to #{response.headers['Location']}"

    assert  User.find_by_id(old_id)
  end

  test "should patch update" do
    @user = users(:user_captain)
    path2test = users_do_deactivate_users_path(@user)
    assert_controller_dispatch_exception(path2test, err_class: ActionController::RoutingError)  # defined in test_helper.rb
     # No route matches [GET] "/users/1234/deactivate_users"

    # Sign in as a sysadmin
    sign_in(@sysadmin)
    assert(@sysadmin.sysadmin?)
    assert_controller_dispatch_exception(path2test, err_class: ActionController::ParameterMissing, method: :patch)  # defined in test_helper.rb
      # params MUST be passed, or else ActionController::ParameterMissing is raised.

    # sysadmin deactivates a user
    sign_in(@sysadmin)
    old_id   = @user.id
    old_name = @user.display_name
    patch path2test, params: {user: {User::DEACTIVATE_METHOD_FORM_NAME => 'rename'}}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@user.id)}"
    assert_equal users_url, response.headers['Location']

    # Has the user been deleted?
    pat = /^#{Regexp.quote(User::EXUSERROOT)}\d+\z/
    newname = User.find(old_id).display_name
    assert_not_equal old_name, newname
    assert_match     pat,      newname

    patch users_do_deactivate_users_path(@sysadmin), params: {user: {User::DEACTIVATE_METHOD_FORM_NAME => 'rename'}}
    assert_equal 500, response.code.to_i, "response:500 !== #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@sysadmin.id)}, maybe redirected to #{response.headers['Location']}"

    # sysadmin destroys a user (who is an exuser-XXX) completely
    sign_in(@sysadmin)
#puts "DEBUG92: tra(cre)=#{User.find(old_id).created_translations.map{|i| i.title}} tra(upd)=#{User.find(old_id).updated_translations.map{|i| i.title}}"
    patch users_do_deactivate_users_path(@user), params: {user: {User::DEACTIVATE_METHOD_FORM_NAME => 'destroy'}}
    assert_nil  User.find_by_id(old_id)
  end

  test "should patch update to destroy a user having multiple entries" do
    @user = users(:user_editor)
    old_id   = @user.id

    # sysadmin destroys a user (who has multiple Translation entries) completely
    sign_in(@sysadmin)
#puts "DEBUG93: tra(cre)=#{User.find(old_id).created_translations.map{|i| i.title}} tra(upd)=#{User.find(old_id).updated_translations.map{|i| i.title}}"
#puts "DEBUG94: captain=#{users(:user_captain).has_undestroyable_children?}"
    trans = @user.created_translations.first
    assert_equal old_id, trans.create_user_id
    patch users_do_deactivate_users_path(@user), params: {user: {User::DEACTIVATE_METHOD_FORM_NAME => 'destroy'}}
    assert_nil  User.find_by_id(old_id)
    trans.reload
    assert_nil trans.create_user_id
  end

  test "editor should not get edit" do
    @user = users(:user_editor)
    assert @user.editor? 

    # Editor cannot access sysadmin edit page
    sign_in(@user)
    get users_edit_deactivate_users_path(@sysadmin)  # sysadmin
    assert_response :redirect  # 302

    # Editor cannot access another member's edit page
    sign_in(@user)
    get users_edit_deactivate_users_path(users(:user_two))
    assert_response :redirect  # 302

    ability = Ability.new(@user)
    assert Ability.new(@sysadmin).can?(:edit, Users::DeactivateUser)
    #assert ability.can?(:edit, Users::DeactivateUser)

    # Editor cannot access their own edit page
    sign_in(@user)
    get users_edit_deactivate_users_path(@user)  # editor herself
    assert_response :redirect  # 302
  end

  test "moderator should get edit" do
    @user = users(:user_moderator)
    assert @user.moderator? 

    # Moderator can access an editor's edit page
    sign_in(@user)
    get users_edit_deactivate_users_path(users(:user_editor))  # editor
    assert_response :success

    # Moderator cannot access his own edit page (to disable his own account).
    get users_edit_deactivate_users_path(@user)  # moderator
    assert_response :redirect  # 302

    # Moderator cannot access sysadmin edit page
    sign_in(@user)
    get users_edit_deactivate_users_path(@sysadmin)  # sysadmin
    #assert_not (200...299).include?(response.code.to_i), "response:(200...299) === #{response.code.inspect} for path=#{users_edit_deactivate_users_path(@user.id)}"  # maybe :redirect or 403 forbidden 
    assert_response :redirect  # 302
  end
end

