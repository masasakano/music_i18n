require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  def setup
    @rc_root = RoleCategory.root_category  # to cache (== RoleCategory[RoleCategory::MNAME_ROOT])
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index or show" do
    get users_index_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route

    get user_url(users(:user_translator))
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
  end

  test "get_roletree by moderator" do
    harami_moderator  = users(:user_moderator) # roles(:moderator).users.first
    harami_editor     = users(:user_editor)    # roles(:editor).users.first
    translator        = users(:user_translator)
    general_ja_editor = users(:user_editor_general_ja) # roles(:general_ja_editor).users.first
    rc_harami = harami_moderator.roles.first.role_category  # = RoleCategory[RoleCategory::MNAME_HARAMI]
    assert_equal rc_harami.mname, RoleCategory::MNAME_HARAMI  # sanity check.
    rc_trans  = translator.roles.first.role_category  # = RoleCategory[RoleCategory::MNAME_TRANSLATION]

    # irb> RoleCategory.tree.print_tree
    # * ROOT
    # |---> general_ja
    # |---> harami
    # |---+ subsystem
    # |    |---> sub2system
    # |    +---> subsubsystem
    # |---> translation
    # +---+ club
    #     +---> subclub

    sign_in harami_moderator

    roletree = UsersController.get_roletree(harami_moderator, harami_moderator)
    assert_equal RoleCategory::MNAME_ROOT, roletree.name
    content = roletree.content
    assert_equal User::ROLE_FORM_RADIO_PREFIX + RoleCategory::MNAME_ROOT, content[:id_name]
    assert_equal RoleCategory[RoleCategory::MNAME_ROOT], content[:role_category]
    assert       content[:delete_disabled]
    assert_equal RoleCategory.root_category.roles.count, content[:forms].size  # Moderator sees all Roles even for Root RoleCategory
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal [false], content[:forms].map(&:checked?).uniq   # None checked

    # NOTE: roletree[rc_harami.mname] returns ChildNode with Name (NEVER Grandchild)
    assert_equal rc_harami.mname, roletree[rc_harami.mname].name  # meaning roletree[rc_harami.mname] is non-nil.

    content = roletree[rc_harami.mname].content
    assert_equal User::ROLE_FORM_RADIO_PREFIX + rc_harami.mname, content[:id_name]
    assert_equal rc_harami, content[:role_category]
    assert_not   content[:delete_disabled]
    assert_equal rc_harami.roles.count, content[:forms].size  # Moderator sees all Roles.
    assert_equal [false], content[:forms].map(&:disabled?).uniq  # NONE disabled
    assert_equal 1, content[:forms].find_all(&:checked?).size    # 1 (Role=moderator) checked

    # Now forcibly adds Role Editor, meaning having 2 roles in a single RoleCategory (which should not happen in reality)
    harami_moderator.roles << roles(:editor)
    harami_moderator.reload
    assert_raises(NoMethodError) {
      p roletree = UsersController.get_roletree(harami_moderator, harami_moderator, force_update: false) }
    roletree = UsersController.get_roletree(harami_moderator, harami_moderator, force_update: true)
    content = roletree[rc_harami.mname].content
    assert_not   content[:delete_disabled]
    assert_equal rc_harami.roles.count, content[:forms].size
    assert_equal [false], content[:forms].map(&:disabled?).uniq
    assert_equal 2, content[:forms].find_all(&:checked?).size    # 2 - only difference

    # Moderator checks Admin info
    roletree = UsersController.get_roletree(harami_moderator, users(:user_sysadmin)) # Def: (force_update: true)
    content = roletree.content  # ROOT category
    assert       content[:delete_disabled]
    assert_equal RoleCategory.root_category.roles.count, content[:forms].size
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal 1, content[:forms].find_all(&:checked?).size    # 1 checked

    content = roletree[rc_harami.mname].content
    assert       content[:delete_disabled]
    assert_equal rc_harami.roles.count, content[:forms].size
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal [false], content[:forms].map(&:checked?).uniq   # None checked

    # Moderator checks Editor info
    roletree = UsersController.get_roletree(harami_moderator, harami_editor)
    content = roletree.content  # ROOT category
    assert       content[:delete_disabled]
    assert_equal RoleCategory.root_category.roles.count, content[:forms].size
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal 0, content[:forms].find_all(&:checked?).size    # None checked

    content = roletree[rc_harami.mname].content
    assert_not   content[:delete_disabled]
    assert_equal rc_harami.roles.count, content[:forms].size
    assert_equal [false], content[:forms].map(&:disabled?).uniq  # NONE disabled
    assert_equal 1, content[:forms].find_all(&:checked?).size    # 1 (Role=Editor) checked
    h_roles = harami_editor.roles
    assert_equal 1, h_roles.count # sanity check of Fixture
    assert_equal h_roles.first, content[:forms].find{|i| i.checked?}.role, 'The checked should be Editor, but?'

    # Moderator checks Translator info
    roletree = UsersController.get_roletree(harami_moderator, translator)
    content_root = roletree.content  # ROOT category
    _assert_root_category_by_moderator(content_root)

    content = roletree[rc_harami.mname].content # RoleCategory of harami
    assert_not   content[:delete_disabled]
    assert_equal rc_harami.roles.count, content[:forms].size
    assert_equal [false], content[:forms].map(&:disabled?).uniq  # NONE disabled
    assert_equal 0, content[:forms].find_all(&:checked?).size    # 0 checked

    content = roletree[rc_trans.mname].content  # RoleCategory of translation
    assert       content[:delete_disabled]
    assert_equal rc_trans.roles.count, content[:forms].size  # Moderator sees all Roles even he has no Role in Translation
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    h_roles = translator.roles
    assert_equal 1, h_roles.count # sanity check of Fixture
    assert_equal 1, content[:forms].find_all(&:checked?).size    # 1 checked
    assert_equal h_roles.first, content[:forms].find{|i| i.checked?}.role, 'The checked should be Translator, but?'

    # Moderator checks info of a user with no roles
    roletree = UsersController.get_roletree(harami_moderator, users(:user_two))
    content_root = roletree.content  # ROOT category
    _assert_root_category_by_moderator(content_root)
    assert_operator 0, '<', roletree.children.size
  end

  test "get_roletree by editor" do
    harami_moderator  = users(:user_moderator) # roles(:moderator).users.first
    harami_editor     = users(:user_editor)    # roles(:editor).users.first
    translator        = users(:user_translator)
    general_ja_editor = users(:user_editor_general_ja) # roles(:general_ja_editor).users.first
    rc_harami = harami_moderator.roles.first.role_category  # = RoleCategory[RoleCategory::MNAME_HARAMI]
    assert_equal rc_harami.mname, RoleCategory::MNAME_HARAMI  # sanity check.
    rc_trans  = translator.roles.first.role_category  # = RoleCategory[RoleCategory::MNAME_TRANSLATION]

    sign_in harami_editor

    # Editor checks info of himself
    roletree = UsersController.get_roletree(harami_editor, harami_editor)

    assert_nil   roletree.content  # ROOT category
    #content_root = roletree.content  # ROOT category
    #assert_equal User::ROLE_FORM_RADIO_PREFIX + RoleCategory::MNAME_ROOT, content_root[:id_name]
    #assert_equal @rc_root, content_root[:role_category]
    #assert       content_root[:delete_disabled]
    #assert_equal 0, content_root[:forms].size  # Editor cannot see any superior Roles (except the one that is assigned to the user to check)

    content = roletree[rc_harami.mname].content # RoleCategory of harami
    assert_not   content[:delete_disabled]
    n_roles_all = rc_harami.roles.count
    assert_equal n_roles_all-1, content[:forms].size   # All - Moderato_role
    assert_equal 0, content[:forms].find_all(&:disabled?).size  # Moderator_role is not included; so none of the included models are disabled.
    assert_equal 1, content[:forms].find_all(&:checked?).size   # 1 checked

    # Editor checks Moderator info
    roletree = UsersController.get_roletree(harami_editor, harami_moderator)
    content = roletree[rc_harami.mname].content # RoleCategory of harami
    assert       content[:delete_disabled]
    assert_equal 1, content[:forms].size   # All but Moderato_role
    assert          content[:forms].first.disabled?
    assert          content[:forms].first.checked?
    assert_equal harami_moderator.roles.first, content[:forms].find{|i| i.checked?}.role, 'The checked should be Moderator, but?'

    # Editor checks Translator info
    roletree = UsersController.get_roletree(harami_editor, translator)
    content = roletree[rc_trans.mname].content  # RoleCategory of translation
    assert       content[:delete_disabled]
    assert_equal 1, content[:forms].size   # All but Moderato_role
    assert          content[:forms].first.disabled?
    assert          content[:forms].first.checked?
    assert_equal translator.roles.first, content[:forms].find{|i| i.checked?}.role, 'The checked should be Translator, but?'
    # assert      roletree[rc_harami.mname].content[:delete_disabled]  ## Node does not exist.
    assert_nil  roletree[rc_harami.mname]  # Editor belongs to RoleCategory of harami, but is not qualified to edit any roles of any other people (but demoting himself).

    # Editor checks info of sysadmin
    user_sysadmin = users(:user_sysadmin)
    roletree = UsersController.get_roletree(harami_editor, user_sysadmin)
    assert       roletree.is_leaf?
    content_root = roletree.content  # ROOT category
    assert_equal User::ROLE_FORM_RADIO_PREFIX + RoleCategory::MNAME_ROOT, content_root[:id_name]
    assert_equal @rc_root, content_root[:role_category]
    assert       content_root[:delete_disabled]
    assert_equal 1, content_root[:forms].size
    assert_equal [true],  content_root[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal user_sysadmin.roles.first, content_root[:forms].find{|i| i.checked?}.role, 'The checked should be Sysadmin, but?'

    # Editor checks info of a user with no roles
    assert_nil UsersController.get_roletree(harami_editor, users(:user_two))
  end

  ###############
  private
  ###############

  # @param content [Hash]
  def _assert_root_category_by_moderator(content)
    @n_roles ||= @rc_root.roles.count        # to cache
    assert_equal User::ROLE_FORM_RADIO_PREFIX + RoleCategory::MNAME_ROOT, content[:id_name]
    assert_equal @rc_root, content[:role_category]
    assert       content[:delete_disabled]
    assert_equal @n_roles, content[:forms].size  # Moderator sees all Roles even for Root RoleCategory
    assert_equal [true],  content[:forms].map(&:disabled?).uniq  # All disabled
    assert_equal [false], content[:forms].map(&:checked?).uniq   # None checked
  end
end

