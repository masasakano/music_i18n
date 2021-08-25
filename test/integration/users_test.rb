require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class UsersIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "handling roles by no role user" do
    harami_moderator = users(:user_moderator) # roles(:moderator).users.first
    user_no_role     = users(:user_no_role)

    get user_path(user_no_role)
    assert_redirected_to new_user_session_path  # Devise sing_in route

    sign_in( users(:user_two) )
    get user_path(users(:user_two))
    assert_redirected_to new_user_session_path, 'Login should be needed b/c the user has not been confirmed, but?'  # Devise sing_in route

    sign_in( user_no_role )

    get user_path(user_no_role)
    assert_response :success

    assert_match(/^User profile/, css_select('h1').first.text)
    %w(2 3 4).each do |i_str|
      css_select('h'+i_str).each do |css|
        assert_not( /Roles/i =~ css.text )
      end
    end

    get user_path(harami_moderator)
    assert_response :success
    %w(2 3 4).each do |i_str|
      css_select('h'+i_str).each do |css|
        assert_not( /Roles/i =~ css.text, 'User with no roles should not be able to see Roles of other users')
      end
    end
  end

  test "add and remove roles" do
    harami_moderator = users(:user_moderator) # roles(:moderator).users.first
    harami_editor    = users(:user_editor) # roles(:editor).users.first
    r_moderator = harami_moderator.roles.first
    r_editor    = harami_editor.roles.first
    rc_harami = r_editor.role_category
    user_no_role     = users(:user_no_role)

    sign_in( harami_editor )

    # show of another user (of no roles)
    get user_path(user_no_role)
    assert_response :success
    assert  css_select('h3').any?{|css| /Roles/i =~ css.text}

    css_select('h3').each do |css|
      if /Roles/i =~ css.text
        assert_equal 'None', css.next_element.text.strip[0,4], 'Editor sees "None" for a user with no roles (Moderator would see options to promote the user), but?'
      end
    end

    # show of Editor himself
    get user_path(harami_editor)
    assert_response :success

    cssform = _get_cssform
    assert cssform
    css_submit = cssform.search('input[type="submit"]')
    assert_equal 1, css_submit.size

    # show of Moderator by Editor
    get user_path(harami_moderator)
    assert_response :success

    cssform = _get_cssform
    assert cssform
    css_submit = cssform.search('input[type="submit"]')
    assert_equal 0, css_submit.size  # No submit button
    
    sign_out(harami_editor)

    ### show of user of no role by Moderator
    sign_in( harami_moderator )

    get user_path(user_no_role)
    assert_response :success
    assert  css_select('h3').any?{|css| /Roles/i =~ css.text}

    cssform = _get_cssform
    assert cssform
    css_submit = cssform.search('input[type="submit"]')
    assert_equal 1, css_submit.size

    key_g = User::ROLE_FORM_RADIO_PREFIX+rc_harami.mname  # role_
    patch users_edit_role_url(user_no_role, params: {key_g => r_editor.id.to_s,})  # though method in form is "post", the hidden input type says value of "patch"

    ### show of user with an added role by Moderator
    get user_path(user_no_role)
    assert_response :success
    cssform = _get_cssform
    assert_match(/\beditor\b/, cssform.search('dd').map{|i| i.text}.join(" "))

    cssform.search('dt').each do |css|
      mname = rc_harami.mname
      if /\b#{Regexp.quote mname}\b/i =~ css.text
        css_input = css.next_element.search('input')[0]
        assert css_input.attributes['disabled'].blank?, 'Moderator is able to promote a user to Moderator, but?'
        css_label = css.next_element.search('label')[0]
        assert_match(/#{r_moderator.name}/i, css_label.text, 'should match "moderator", but?')
      end
    end
    sign_out( harami_moderator )

    # Now the user too can see his role.
    sign_in( user_no_role )
    get user_path(user_no_role)
    assert_response :success
    cssform = _get_cssform
    assert cssform
    css_submit = cssform.search('input[type="submit"]')
    assert_equal 1, css_submit.size
    assert_match(/\beditor\b/, cssform.search('dd').map{|i| i.text}.join(" "))
    sign_out( user_no_role )

    ### moderator cannot demote him anymore once promoted further.
    sign_in( harami_moderator )
    assert_equal 1, user_no_role.roles.count
    assert_difference('user_no_role.roles.count', 0){
      patch users_edit_role_url(user_no_role, params: {key_g => r_moderator.id.to_s,})
    }  # roles change, but the number remains the same

    get user_path(user_no_role)
    assert_response :success
    cssform = _get_cssform
    # assert_match(/\beditor\b/, cssform.search('dd').map{|i| i.text}.join(" "))  # In this case submit-button should not be displayed ideally (because Moderator is not senior in any RoleCategory anymore), but it is still displayed.

    cssform.search('dt').each do |css|
      mname = rc_harami.mname
      if /\b#{Regexp.quote mname}\b/i =~ css.text
        css_label = css.next_element.search('label')[0]
        assert_match(/#{r_moderator.name}/i, css_label.text, 'should match "moderator", but?')
        css.next_element.search('input').each do |css_input|
          assert_equal 'disabled', css_input.attributes['disabled'].text, 'Moderator is now unable to change a role of the, but?'
        end
      end
    end
    sign_out( harami_moderator )
  end

  def _get_cssform
    css_select('h3').each do |css|
      if /Roles/i =~ css.text
        next_css = css.next_element
        return next_css if 'form' == next_css.name
        raise 'After H3(Roles), it is not a <form>.'
      end
    end
    nil
  end
end
