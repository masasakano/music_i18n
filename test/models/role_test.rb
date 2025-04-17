# == Schema Information
#
# Table name: roles
#
#  id                      :bigint           not null, primary key
#  name                    :string           not null
#  note                    :text
#  uname(Unique role name) :string
#  weight                  :float
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  role_category_id        :bigint           not null
#
# Indexes
#
#  index_roles_on_name                         (name)
#  index_roles_on_name_and_role_category_id    (name,role_category_id) UNIQUE
#  index_roles_on_role_category_id             (role_category_id)
#  index_roles_on_uname                        (uname) UNIQUE
#  index_roles_on_weight_and_role_category_id  (weight,role_category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (role_category_id => role_categories.id) ON DELETE => cascade
#
require 'test_helper'

class RoleTest < ActiveSupport::TestCase
  test "weight validations" do
    mdl = roles(:translator)
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
  end

  test "has_many through" do
    assert_equal 1,       Role.find(1).users.size
    assert_equal 'a@example.com', Role.find(1).users[0].email
  end

  test "non-null" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){ Role.create!(note: nil, role_category_id: 1) }  # PG::NotNullViolation (though it is caught by Rails validation before passed to the DB)
  end

  test "invalid" do
    assert_raises(ActiveRecord::RecordInvalid){ Role.create!(name: 'some') }  # role_category_id is missing
  end
  
  test "unique name" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ Role.create!(name: 'admin', role_category_id: 1, weight: 789) }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB)
    assert_raises(ActiveRecord::RecordInvalid){
      Role.create!(name: 'admin', role_category: role_categories(:rolecattwo)) } # Weight can't be blank

    Role.create!(name: 'admin', role_category: role_categories(:rolecattwo), weight: 789)  # Same name but in a different RoleCategory
  end

  test "case-insensitive unique" do
    assert_raises(ActiveRecord::RecordInvalid){ Role.create!(name: 'ADMIN', role_category_id: 1) }  #
  end

  test "space is invalid" do
    assert_raises(ActiveRecord::RecordInvalid){ Role.create!(name: 'ad min', role_category_id: 1) }
    assert_raises(ActiveRecord::RecordInvalid){ Role.create!(name: 'naiyo', uname: 'ad min', role_category_id: 1) }
  end

  test "role name is unique within RoleCategory" do
    r_captain    = Role[:captain, :club]
    r_cap1 = r_captain.dup
    r_cap1.uname = 'cap1_dup'
    r_cap1.weight = 235
    assert_raises(ActiveRecord::RecordInvalid){ r_cap1.save! } # Name has already been taken
    r_cap1.role_category = RoleCategory[:harami]
    r_cap1.save!  # Accepted: Same uname but different RoleCategory
  end

  test "role uname is unique" do
    r_captain    = Role[:captain, :club]

    r_cap1 = r_captain.dup
    r_cap1.name  = 'cap1'
    r_cap1.uname = 'cap1_dup'
    assert_raises(ActiveRecord::RecordInvalid){ r_cap1.save! } # Weight has already been taken
    r_cap1.weight = 235
    r_cap1.save!
    r_cap2 = r_captain.dup
    r_cap2.name  = 'cap2'
    r_cap2.uname  = r_cap1.uname  # NOT unique
    r_cap2.weight = r_cap1.weight + 9
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ r_cap2.save! } # Uname has already been taken / DRb::DRbRemoteError: PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_roles_on_uname"
    r_cap2.uname.upcase!   # NOT unique (case-insensitive
    assert_raises(ActiveRecord::RecordInvalid){ r_cap2.save! } # Uname has already been taken
    r_cap2.uname = 'symbol_banned!'
    assert_raises(ActiveRecord::RecordInvalid){ r_cap2.save! } # Uname only allows alphabets, numbers, and underscores
    r_cap2.uname = ''
    assert_raises(ActiveRecord::RecordInvalid){ r_cap2.save! } # Uname only allows alphabets, numbers, and underscores
    r_cap2.uname = nil   # No exception because nil is allowed.
    r_cap2.save!
  end

  test "role class method brackets" do
    assert       Role[Role::UNAME_TRANSLATOR]
    assert_equal Role[Role::UNAME_TRANSLATOR], Role[Role::UNAME_TRANSLATOR.to_sym]
    rolem = Role[:moderator, RoleCategory::MNAME_HARAMI]
    assert       rolem
    assert_equal rolem, Role[rolem]
    assert_equal rolem, Role['moderator', 'harami']
    assert_raises(ArgumentError){ Role[1] }
    assert_raises(RuntimeError){ Role[:moderator] } # RuntimeError: Ambiguous argument: multiple (=2) candidates are found in Role[:moderator]
  end

  test "role operators" do
    assert_nil  Role[:naiyo]

    r_admin     = Role[:admin,     RoleCategory::MNAME_ROOT]
    r_syshelper = Role[:syshelper, RoleCategory::MNAME_ROOT]
    r_moderator = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r_editor    = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r_helper     = Role[:helper,     RoleCategory::MNAME_HARAMI]
    r_captain   = Role[:captain, 'club']   # in RoleCategory club (same level as harami)
    r_last      = Role.last
    r_lowly1    = Role[:lowly1]

    # categories?
    assert  r_syshelper.related_category?(r_helper)
    assert      r_helper.related_category?(r_syshelper)
    assert_not  r_helper.related_category?(r_captain)
    assert_raises(ArgumentError){ r_helper.related_category?(234) }

    assert_not  r_helper.same_category?(r_captain)
    assert_not  r_helper.same_category?(r_syshelper)
    assert      r_helper.same_category?(r_editor)

    assert_raises(ArgumentError){ r_helper.higher_category_than?(r_captain) }
    assert_not r_helper.higher_category_than?(r_syshelper)
    assert_not r_helper.higher_category_than?(r_editor)
    assert     r_admin.higher_category_than?(r_helper)

    assert_raises(ArgumentError){ r_helper.lower_category_than?(r_captain) }
    assert     r_helper.lower_category_than?(r_syshelper)
    assert_not r_helper.lower_category_than?(r_editor)
    assert_not r_admin.lower_category_than?(r_helper)

    ## Arithmatic operations
    assert_raises(ArgumentError){ r_admin < 234 }

    assert_operator r_admin, :<,  r_last
    assert_operator r_admin, :<,  r_moderator
    assert_operator r_admin, :<,  r_editor
    assert_operator r_admin, :<=, r_last
    assert_operator r_admin, :<=, r_moderator
    assert_operator r_admin, :<=, r_editor

    # any one in Category ROOT is higher in rank
    assert_operator r_syshelper, :<,  r_moderator
    assert_operator r_syshelper, :<,  r_editor
    assert_operator r_syshelper, :<,  r_captain

    assert_operator r_moderator, :>,  r_syshelper
    assert_operator r_editor   , :>,  r_syshelper
    assert_operator r_moderator, :>=, r_syshelper
    assert_operator r_editor   , :>=, r_syshelper

    # In the same RoleCategory
    assert_operator r_helper    , :>,  r_moderator
    assert_operator r_editor   , :>,  r_moderator
    assert_operator r_editor   , :>=, r_moderator
    assert_operator r_moderator, :<,  r_editor
    assert_operator r_moderator, :<=, r_editor

    # In a different parallel RoleCategory
    assert_raises(ArgumentError){ r_editor <  r_captain }
    assert_raises(ArgumentError){ r_editor <= r_captain }
    assert_raises(ArgumentError){ r_editor >  r_captain }
    assert_raises(ArgumentError){ r_editor >= r_captain }

    # equal_rank?
    r_dup = r_syshelper.dup
    r_dup.name = 'dup1'
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ r_dup.save! }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB)
    r_dup.weight += 0.3
    r_dup.save!
    r_dif = Role.new
    r_dif.name = 'dif1'
    r_dif.role_category = r_dup.role_category
    assert_raises(ActiveRecord::RecordInvalid) {
      r_dif.save! } # Weight has already been taken
    r_dif.weight = r_dup.weight + 0.9
    r_dif.save!

    assert_not r_syshelper.equal_rank?(r_dup)
    assert     r_syshelper.equal_rank?(r_syshelper)
    assert_not r_syshelper.equal_rank?(r_admin)
    assert_not r_syshelper.equal_rank?(r_editor)
    assert_not r_syshelper.equal_rank?(r_captain)
    assert_not r_dup.equal_rank?(r_dif)
    assert_raises(ArgumentError){ r_dup.equal_rank?( 234 ) }

    # comparison operator
    assert_equal(-1, r_admin     <=> r_captain)
    assert_equal(-1, r_syshelper <=> r_captain)
    assert_equal(-1, r_syshelper <=> r_dup)
    assert_equal  1, r_captain   <=> r_syshelper 
    assert_equal  1, r_dup       <=> r_syshelper 
    assert_equal  0, r_syshelper <=> r_syshelper
    # assert_equal  0, r_dup       <=> r_dif  # Now, weight is not allowed to be nil (at Rails level).
    assert_nil  (    r_captain <=> r_editor)
    assert_nil  (    r_captain <=> nil)
    assert_raises(ArgumentError){ r_dup <=> 234 }

    assert_equal [r_moderator, r_editor, r_helper], r_helper.superiors_or_self_in_category
    assert_equal [r_captain, r_lowly1],           r_lowly1.superiors_or_self_in_category
    assert_equal [r_editor, r_helper],          r_moderator.subordinates_in_category[0..1]
    assert_equal [Role[:lowly2]],                 r_lowly1.subordinates_in_category
    assert_not_includes  r_helper.superiors, r_helper
  end

  test "role comparisons" do
    rcat_harami = RoleCategory['harami']
    role1 = Role['admin']  # admin
    ura = role1.user_role_assocs[0]
    assert role1.sysadmin?
    assert role1.an_admin?
    assert role1.moderator?
    assert role1.is_or_higher_than?('moderator')

    role2 = Role['syshelper']
    assert_not role2.sysadmin?
    assert role2.an_admin?
    assert role2.qualified_as? 'syshelper'
    assert_not role2.qualified_as? role1
    assert     role2.qualified_as? role2
    assert     role2.qualified_as? 'moderator'
    assert     role2.qualified_as? :moderator
    assert role2.moderator?
    assert role2.is_or_higher_than?('moderator')

    role3 = Role['editor', RoleCategory::MNAME_HARAMI]
    assert_not role3.sysadmin?
    assert_not role3.an_admin?
    assert_not role3.moderator?
    assert_not role3.qualified_as? 'moderator'
    assert_not role3.qualified_as? 'admin'             # Different RoleCategory
    assert     Role['admin'].qualified_as? 'moderator' # Different RoleCategory
    assert_not role3.is_or_higher_than?('moderator')
    assert     role3.qualified_as? role3
    assert     role3.qualified_as? role3.role_category

    role4 = Role['captain']
    assert_not role4.sysadmin?
    assert_not role4.an_admin?
    assert_not role4.moderator?
    assert_not role4.qualified_as? 'moderator'
    assert_not role4.qualified_as? :moderator
    assert_not role4.is_or_higher_than?('moderator')
    assert_not role4.qualified_as? 'naiyo'
    assert_raises(ArgumentError){ role4.qualified_as? nil }
    assert_raises(ArgumentError){ role4.qualified_as? true }
    assert_not role4.qualified_as? RoleCategory::MNAME_HARAMI
    assert_not role3.qualified_as? role4.role_category

    assert_not Role['lowly2'].qualified_as? :lowly1  # if both weights are undefined, not qualified.
  end

  test "cascade delete" do
    u3 = User.create! email: 'c@e.com', password: 'abcdef', accept_terms: true
    c_bef = UserRoleAssoc.count
    u3.roles = [Role[:helper, RoleCategory::MNAME_HARAMI]]
    c_med = UserRoleAssoc.count
    assert_equal c_med, c_bef+1
    Role[:helper, RoleCategory::MNAME_HARAMI].delete
    c_aft = UserRoleAssoc.count
    assert_equal c_med, c_aft+1
  end

  test "create constructors" do
    r_admin     = Role[:admin,     RoleCategory::MNAME_ROOT]
    r_moderator = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r_editor    = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r_helper     = Role[:helper,     RoleCategory::MNAME_HARAMI]
    r_captain   = Role[:captain, 'club']   # in RoleCategory club (same level as harami)
    r_lowly1    = Role[:lowly1]

    ## create_superior

    rtmp0 = Role.create_superior(r_editor, name: 'editor') # This silently returns an invalid model!! (according to Rails create() convention)
    assert_not  rtmp0.valid?
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
            Role.create_superior!(r_editor, name: 'editor') }  # ActiveRecord::RecordInvalid: Validation failed: Name has already been taken

    rtmp1 = Role.create_superior!(r_editor, name: 't1')
    assert_operator r_moderator.weight, :<, rtmp1.weight
    assert_operator rtmp1.weight,      :<, r_editor.weight

    rtmp2 = Role.create_superior!(r_editor, name: 't2', weight: 1)  # weight is ignored.
    assert_operator rtmp1.weight,      :<, rtmp2.weight
    assert_operator rtmp2.weight,      :<, r_editor.weight

    rtmp3 = Role.create_superior!(r_editor, name: 't3', weight: r_editor.weight-1)
    assert_equal    r_editor.weight-1,   rtmp3.weight
    assert_operator rtmp2.weight,      :<, rtmp3.weight
    assert_operator rtmp3.weight,      :<, r_editor.weight

    rtmp4 = Role.create_superior!(r_editor, name: 't4', weight: r_editor.weight-1)
    assert_in_delta r_editor.weight-0.5, rtmp4.weight, 1e-6, "W(editor)=#{r_editor.weight}, W(t4)=#{rtmp4.weight}"
    assert_operator rtmp3.weight,      :<, rtmp4.weight
    assert_operator rtmp4.weight,      :<, r_editor.weight

    if Role::DEF_WEIGHT[Role::RNAME_SYSADMIN] != r_admin.weight 
      warn "WARNING: the admin's weight is not #{Role::DEF_WEIGHT[Role::RNAME_SYSADMIN]}, but #{r_admin.weight}."
    else
      rtmp5 = Role.create_superior!(r_admin, name: 'u5')
      assert_operator r_admin.weight, :>, rtmp5.weight
    end

    rtmp6 = Role.create_superior!(r_captain, name: 't6')  # nil weight of the reference
    assert_operator rtmp6.weight, :<, r_captain.weight

    ## create_subordinate

    rtmp0 = Role.create_subordinate(r_editor, name: 'editor') # This silently returns an invalid model!! (according to Rails create() convention)
    assert_not  rtmp0.valid?
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
            Role.create_subordinate!(r_editor, name: 'editor') }  # ActiveRecord::RecordInvalid: Validation failed: Name has already been taken

    rtmp1 = Role.create_subordinate!(r_editor, name: 'u1')
    assert_operator r_editor.weight, :<, rtmp1.weight
    assert_operator rtmp1.weight,    :<, r_helper.weight

    rtmp2 = Role.create_subordinate!(r_editor, name: 'u2', weight: 1e12)  # weight is ignored.
    assert_operator r_editor.weight, :<, rtmp2.weight
    assert_operator rtmp2.weight,    :<, rtmp1.weight

    rtmp3 = Role.create_subordinate!(r_editor, name: 'u3', weight: r_editor.weight+1)
    assert_equal    r_editor.weight+1,   rtmp3.weight
    assert_operator r_editor.weight, :<, rtmp3.weight
    assert_operator rtmp3.weight,    :<, rtmp2.weight

    rtmp4 = Role.create_subordinate!(r_editor, name: 'u4', weight: r_editor.weight+1)
    assert_in_delta r_editor.weight+0.5, rtmp4.weight, 1e-6
    assert_operator r_editor.weight, :<, rtmp4.weight
    assert_operator rtmp4.weight,    :<, rtmp3.weight

    r_sys_last = RoleCategory[:ROOT].roles[-1]
    if ! r_sys_last.weight 
      warn "WARNING: the lowest Role in Caregory=ROOT has a null/nil weight."
    else
      rtmp5 = Role.create_subordinate!(r_sys_last, name: 't5')
      assert_operator r_sys_last.weight, :<, rtmp5.weight
    end

    ## Now, weight has to be non-nil.
    #rtmp6 = Role.create_subordinate!(r_lowly1, name: 'u6')  # nil weight of the reference
    #assert_nil  rtmp6.weight
  end

  test "all superior to" do
    r_admin     = Role[:admin,     RoleCategory::MNAME_ROOT]
    r_moderator = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r_editor    = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r_helper     = Role[:helper,     RoleCategory::MNAME_HARAMI]
    r_captain   = Role[:captain, 'club']   # in RoleCategory club (same level as harami)
    r_lowly1    = Role[:lowly1]
    assert_not Role.all_superior_to?([r_moderator], [r_editor, r_captain])
    assert_not Role.all_superior_to?([r_captain  ], [r_moderator])
    assert     Role.all_superior_to?([r_moderator], [r_editor])
    assert     Role.all_superior_to?([r_moderator, r_captain], [r_editor])
    assert     Role.all_superior_to?([r_moderator, r_captain], [r_editor, r_lowly1])
    assert_not Role.all_superior_to?([r_editor   ], [r_moderator])
    assert     Role.all_superior_to?([r_admin], [r_moderator, r_captain])

    assert_equal role_categories(:club), r_captain.role_category,   "sanity check"
    refute_equal role_categories(:club), r_moderator.role_category, "sanity check"
    assert_nil(  r_moderator <=> r_captain, "sanity check")
    assert     Role.all_superior_to?([r_moderator], [r_editor, r_captain], except: role_categories(:club))
    assert     Role.all_superior_to?([r_editor], [r_moderator, r_captain], except: [r_moderator.role_category, role_categories(:club)]), "true if everything is ignored."

    # The following is a test for an invalid input.
    assert_not Role.all_superior_to?([nil], [r_moderator, r_captain])
  end

  test "superior to" do
    r_admin     = Role[:admin,     RoleCategory::MNAME_ROOT]
    r_moderator = Role[:moderator, RoleCategory::MNAME_HARAMI]
    r_editor    = Role[:editor,    RoleCategory::MNAME_HARAMI]
    r_helper     = Role[:helper,     RoleCategory::MNAME_HARAMI]
    r_captain   = Role[:captain, 'club']   # in RoleCategory club (same level as harami)
    r_lowly1    = Role[:lowly1]
    assert     r_moderator.superior_to?(r_editor)
    assert_not r_moderator.superior_to?(r_captain)
    assert_not r_captain.superior_to?(  r_moderator)
    assert_not r_captain.superior_to?(  r_editor)
    assert_not r_moderator.superior_to?(r_lowly1)
    assert_not r_editor.superior_to?(   r_moderator )
    assert     r_admin.superior_to?(r_moderator)
    assert     r_admin.superior_to?(r_captain)

    assert_raises(ArgumentError, TypeError) { # ArgumentError (though it should be ideally TypeError)
      p r_editor.superior_to?( ?a ) }
  end
end

