# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  display_name           :string           default(""), not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  ext_account_name       :string
#  ext_uid                :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def suppress_stderr
    stderr_orig = $stderr.clone
    begin
      $stderr.reopen File.new('/dev/null', 'w')
      yield
    ensure
      $stderr.reopen stderr_orig
    end
  end

  # <https://gist.github.com/moertel/11091573>
  def suppress_output
    original_stdout, original_stderr = $stdout.clone, $stderr.clone
    $stderr.reopen File.new('/dev/null', 'w')
    $stdout.reopen File.new('/dev/null', 'w')
    yield
  ensure
    $stdout.reopen original_stdout
    $stderr.reopen original_stderr
  end

  test "has_many through" do
    assert_equal 1,       User.find(1).roles.size
    assert_equal 'admin', User.find(1).roles[0].name
  end

  test "confirm fixtures" do
    user = users(:user_syshelper)
    assert_not user.sysadmin?
    assert     user.an_admin?
    assert     user.moderator?
    assert     user.editor?
    assert     user.qualified_as?(:moderator)
    assert     user.qualified_as?(:captain)

    user = users(:user_moderator)
    assert_not user.sysadmin?
    assert_not user.an_admin?
    assert     user.moderator?
    assert     user.editor?
    assert     user.qualified_as?(:moderator)

    user = users(:user_editor)
    assert_not user.sysadmin?
    assert_not user.an_admin?
    assert_not user.moderator?
    assert     user.editor?
    assert_not user.qualified_as?(:moderator)

    user = users(:user_captain)
    assert_not user.sysadmin?
    assert_not user.an_admin?
    assert_not user.moderator?
    assert_not user.editor?
    assert_not user.qualified_as?(:moderator)
    assert     user.qualified_as?(:captain)
  end

  test "role comparisons" do
    user = User.find(1)  # admin
    ura = user.user_role_assocs[0]
    assert user.an_admin?
    assert user.sysadmin?
    assert user.moderator?
    assert user.editor?
    assert user.role_is_or_higher_than?('moderator')

    user = user.dup
    user.roles = [Role[:editor, RoleCategory::MNAME_HARAMI]]
    user.email = 'test_editor@example.com'
    user.password = 'test_editor'
    user.confirmation_token = user.email+user.password[0..5]  # If not reset, DRb::DRbRemoteError: PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_users_on_confirmation_token"
    user.accept_terms = true
    user.save!
    user.reload
    assert_not user.an_admin?
    assert_not user.sysadmin?
    assert_not user.moderator?
    assert     user.editor?
    assert_not user.role_is_or_higher_than?('moderator')

    # Multiple roles
    assert_not user.role_is_or_higher_than?('captain')
    user.roles << Role[:captain, 'club']
    user.save!
    user.reload
    assert     user.role_is_or_higher_than?('captain')
    assert     user.qualified_as? 'captain'
    assert     user.editor?
    assert     user.qualified_as? :editor

    user = user.dup
    user.roles = [Role[:syshelper, RoleCategory::MNAME_ROOT]]
    user.email = 'test_syshelper@example.com'
    user.password = 'test_syshelper'
    user.confirmation_token = user.confirmation_token.next rescue nil  # once Device has introduced it.
    user.save!
    user.reload
    assert     user.an_admin?
    assert_not user.sysadmin?
    assert_not user.qualified_as? :admin
    assert     user.moderator?
    assert     user.editor?
    assert     user.role_is_or_higher_than?('moderator')
    assert     user.role_is_or_higher_than?('captain')
  end

  test "cascade delete" do
    u3 = User.create! email: 'c@e.com', password: 'abcdef', accept_terms: true
    assert_equal 0, u3.roles.count
    c_bef = UserRoleAssoc.count
    u3.roles = [Role[:helper, RoleCategory::MNAME_HARAMI]]
    c_med = UserRoleAssoc.count
    assert_equal c_med, c_bef+1
    u3.delete
    c_aft = UserRoleAssoc.count
    assert_equal c_med, c_aft+1
  end

  test "user with role initialization" do
    r0 = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r1 = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r2 = Role[:captain, 'club']
    uc1 = User.count
    ur1 = UserRoleAssoc.count

    u2 = User.new{ |i|
      i.email = 'init1.text@test.com'
      i.password = '123456789aB.'
      i.accept_terms = true
      i.save!
    }.with_roles(r1)
    uc2 = User.count
    ur2 = UserRoleAssoc.count
    assert_equal uc1+1, uc2 
    assert_equal ur1+1, ur2, "ur1=#{ur1}, ur1+1=#{ur1+1}, ur2=#{ur2}: UserRoleAssoc=#{UserRoleAssoc.all}"
    assert_equal 1, UserRoleAssoc.where(user_id: u2.id).count
    assert u2.editor?
    u2.with_roles(r0, r1, r1, r2)
    assert u2.moderator?
    assert u2.qualified_as?(r2)

    u3 = User.create!(email: 'init3.text@test.com', password: '123456789aB.', accept_terms: true).with_roles([r1])
    uc3 = User.count
    ur3 = UserRoleAssoc.count
    assert_equal uc3, uc2+1
    assert_equal ur3, ur2+3

    # arid = User.pluck(:id).sort
    # u4 = suppress_stderr{ User.new(role_id: arid[-1]+100, email: 'init4.text@test.com', password: '423456789aB.') }
    # assert_raises(ActiveRecord::RecordInvalid){suppress_stderr{ u4.save! }}
    # uc4 = User.count
    # ur4 = UserRoleAssoc.count
    # assert_equal uc4, uc3  # No change
    # assert_equal ur4, ur3
  end

  test "translation create and update" do
    user = User.find(1)
    assert_equal 'Nippon', user.created_translations.where(langcode: 'ja', translatable_type: 'Country', romaji: 'Nippon')[0].romaji  # created_translations list does include Nippon.
    user = users(:user_two)
    assert_equal 'Japan',  user.updated_translations[0].title
    assert_equal 'Japan',  user.touched_translations.where(langcode: 'en')[0].title
  end

  test "abs superior to" do
    userm = users(:user_moderator)
    usere = users(:user_editor)
    userc = users(:user_captain)
    assert_not userm.abs_superior_to?(userc)
    assert_not userc.abs_superior_to?(userm)
    assert     userm.abs_superior_to?(usere)
    assert_not usere.abs_superior_to?(userm)
  end

  test "first user promoted to root" do
    User.all.each do |eu|
      %i(created_translations updated_translations).each do |em|
        eu.send(em).delete_all
      end
    end
    User.delete_all
    u3 = User.create! email: 'c@e.com', password: 'abcdef', accept_terms: true
    assert_equal 1, User.count
    assert_equal 1, u3.roles.count
    assert  u3.superuser?
    assert  u3.confirmed?
  end

  test "user.roles_in" do
    rolec_g = role_categories(:rc_general_ja)
    role_m = roles( :general_ja_moderator )
    role_e = roles( :general_ja_editor )
    user      = users(:user_editor_general_ja)
    assert_equal 1,        user.roles_in(rolec_g).size
    assert_equal [role_e], user.roles_in(rolec_g)
    user.roles << role_m
    assert_equal 2, user.roles_in(rolec_g).size
    assert_equal 0, user.roles_in(role_categories(:rc_translation)).size
  end

  test "superior to" do
    r_admin     = Role[:admin,     RoleCategory::MNAME_ROOT]
    r_moderator = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r_editor    = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r_captain   = Role[:captain, 'club']   # in RoleCategory club (same level as harami)
    rc_general_m = role_categories(:rc_general_ja)
    r_general_m = roles(:general_ja_moderator)
    assert_equal rc_general_m, r_general_m.role_category # sanity check
    admin = users(:user_sysadmin)
    moderator = users(:user_moderator)
    editor    = users(:user_editor)
    captain   = users(:user_captain)
    general_m = users(:user_moderator_general_ja)
    general_e = users(:user_editor_general_ja)

    assert_not admin.superior_to?(    r_admin)
    assert     admin.superior_to?(    r_editor)
    assert     admin.superior_to?(    r_moderator)
    assert     moderator.superior_to?(r_editor)
    assert_not moderator.superior_to?(r_captain)
    assert_not editor.superior_to?(   r_moderator )
    assert_not editor.superior_to?(   r_editor )
    assert_not general_m.superior_to?(r_editor )

    assert     admin.superior_to?(    editor)
    assert     admin.superior_to?(    moderator)
    assert     moderator.superior_to?(editor)
    assert_not moderator.superior_to?(captain)
    assert_not editor.superior_to?(   moderator )
    assert_not editor.superior_to?(   editor )
    assert_not general_m.superior_to?(editor )

    assert     general_m.superior_to?(general_e, rc_general_m), [general_m.email, general_e.email, rc_general_m.mname].inspect
    user2 = users(:user_two)
    assert     general_m.superior_to?(user2, rc_general_m), 'other does not have any roles'
    user2.roles << r_captain
    assert     general_m.superior_to?(user2, rc_general_m), 'other has a role in an unrelated RoleCategory'

    assert_not editor.superior_to?(   general_e )
    assert_not editor.superior_to?(   general_e, rc_general_m)
    assert_not editor.superior_to?(user2, rc_general_m)
    editor.roles << r_general_m    ## Modify
    assert     editor.superior_to?(   general_e )
    general_e.roles << r_moderator ## Modify
    assert_not editor.superior_to?(   general_e )
    assert     editor.superior_to?(   general_e, rc_general_m)
    assert_not general_e.superior_to?( editor )
    assert     general_e.superior_to?( editor, r_moderator.role_category)
  end
end

