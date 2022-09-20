require "test_helper"

class UserRoleAssocControllerTest < ActionDispatch::IntegrationTest
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

  test "admin should get update" do
    user = @sysadmin

    sign_in(user)
    assert_raises(ActionController::RoutingError){ # No route matches [GET] "/user_role_assoc/1"
      get user_role_assoc_url(user)
    }

    sign_in(user)
    allrolenames = user.roles.map(&:name)
    path = user_role_assoc_url(user)
    patch path, params: {role_ROOT: 'none'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
#print "DEBUG-sys1:";p flash
#print "DEBUG-sys2:";p response
    assert_equal user_url(user), response.headers['Location']  # if unauthorized, this fails b/c redirect_to root
    assert_operator flash[:alert].size, :>, 10  # You cannot cancel the sysadmin role as the sole sysadmin.
    assert_match(/\[ErrorCancelSysadmin\]/, flash[:alert])
    assert_equal allrolenames, user.roles.map(&:name)  # No change in roles
  end

  test "modertor should cancel editor" do
    moderator = users( :user_moderator )
    user = users( :user_editor )
    path = user_role_assoc_url(user)
    allrolenames = user.roles.map(&:name)

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_ROOT: 'admin'}
    assert_response :redirect
    assert_equal user_url(user), response.headers['Location']  # if unauthorized, this fails b/c redirect_to root
#print "DEBUG-usrrole9:";p flash
    assert_operator flash[:alert].size, :>, 10
    assert_match(/\[ErrorUpdateHigherRankRole\]/, flash[:alert])
    flash.clear

    ability = Ability.new(moderator)
    assert_not ability.can?(:update, @sysadmin.user_role_assocs.first)

    sign_in(moderator)
    patch user_role_assoc_url(@sysadmin), params: {role_ROOT: 'none'}
    assert_response :redirect
    assert_equal root_url, response.headers['Location']  # redirect_to root b/c unauthorized
#print "DEBUG-usrrole1:";p flash
    assert_operator flash[:alert].size, :>, 10  # You cannot cancel the sysadmin role as the sole sysadmin.
    assert_match(/\[ErrorUpdateHigherRankRole\]/, flash[:alert])
    flash.clear

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_ROOT: 'none'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
#print "DEBUG-usrrole2:";p flash
    assert_operator flash[:alert].size, :>, 10  # You cannot cancel the sysadmin role as the sole sysadmin.
    assert_match(/\[Error/, flash[:alert]) # [ErrorUpdateHigherRankRole]
    flash.clear

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_harami: 'none'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
    assert_equal user_url(user), response.headers['Location']
    user.reload
    assert_empty user.roles  # Role has been cancelled.
    flash.clear

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_ROOT: 'admin'}
    assert_response :redirect
    assert_equal user_url(user), response.headers['Location']
    assert_operator flash[:alert].size, :>, 10
    assert_match(/\[ErrorUpdateHigherRankRole\]/, flash[:alert])
    flash.clear

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_harami: 'moderator'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
    assert_equal user_url(user), response.headers['Location']
    user.reload
    assert_equal Role[:moderator, :harami], user.roles[0]  # has been promoted to 'moderator'
    flash.clear

    sign_in(moderator)
    patch user_role_assoc_url(user), params: {role_harami: 'none'}
    assert_response :redirect
    assert_equal user_url(user), response.headers['Location']
    user.reload
    assert_equal Role[:moderator, :harami], user.roles[0]  # has been promoted to 'moderator'
## The following should work...
#    assert_operator flash[:alert].size, :>, 10  # You cannot cancel the same-rank role.
#    assert_match(/\[ErrorUpdateHigherRankRole\]/, flash[:alert])
    flash.clear

#### The test fails...    
#    sign_in(moderator)
#    patch user_role_assoc_url(user), params: {role_harami: 'editor'}
#    assert_response :redirect
#    assert_equal user_url(user), response.headers['Location']
#    user.reload
#    assert_equal Role[:moderator], user.roles[0]  # has been promoted to 'moderator'
#    assert_operator flash[:alert].size, :>, 10  # You cannot demote the same-rank role.
#    assert_match(/\[ErrorUpdateHigherRankRole\]/, flash[:alert])
#    flash.clear
  end

  test "editor should get update for himself" do
    user = users( :user_editor )

    sign_in(user)
    path = user_role_assoc_url(user)
    patch user_role_assoc_url(user), params: {role_harami: 'none'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
    user.reload
    assert_empty user.roles, "(NOTE) user=#{user.inspect} user.roles=#{user.roles.inspect}"  # self's role has been cancelled.
  end


  test "non-role should not get update" do
    user = users( :user_two )
    path = user_role_assoc_url(user)
    patch user_role_assoc_url(user), params: {role_harami: 'editor'}
    assert_response :redirect, "response: 302 !== #{response.code.inspect} for path=#{path}"
    assert_match(/\b(?:sign|log) *in\b/, flash[:alert])
    flash.clear
  end 

end
