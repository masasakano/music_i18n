# == Schema Information
#
# Table name: role_categories
#
#  id          :bigint           not null, primary key
#  mname       :string           not null
#  note        :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  superior_id :bigint
#
# Indexes
#
#  index_role_categories_on_mname        (mname) UNIQUE
#  index_role_categories_on_superior_id  (superior_id)
#
require 'test_helper'

class RoleCategoryTest < ActiveSupport::TestCase
  test "has_many" do
    assert_equal 'admin', RoleCategory.find(1).roles[0].name
    rc_harami = RoleCategory[:harami]
    r_last = rc_harami.roles.last
    assert_equal 10000000,         r_last.weight # test of sorted
    assert_equal 'helper10000000', r_last.name   # test of sorted

    # on_delete: cascade
    rol = Role[:moderator, :harami]
    assert_equal 'moderator', rol.name
    assert_equal 'harami_moderator', rol.uname
    rc_harami.destroy
    assert_raises(ActiveRecord::RecordNotFound){ rol.reload }
    assert_nil  Role[:moderator, :harami], "Fail. Still exists: "+rol.role_category.inspect
  end

  test "non-null" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){ RoleCategory.create!(note: nil) }  # PG::NotNullViolation (though it is caught by Rails validation before passed to the DB)
  end

  test "unique" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ RoleCategory.create!(mname: 'ROOT') }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB)
  end

  test "case-insensitive unique" do
    assert_raises(ActiveRecord::RecordInvalid){ RoleCategory.create!(mname: 'RooT') }  # 
  end

  test "space is invalid" do
    assert_raises(ActiveRecord::RecordInvalid){ RoleCategory.create!(mname: 'sys tem') }
  end

  test "curly brackets" do
    assert_equal RoleCategory.find(1), RoleCategory['ROOT']
  end

  test "comparison between" do
    rc_root = RoleCategory[:ROOT]
    rc_harami = RoleCategory[:harami]
    rc_club   = RoleCategory[:club]
    rc_last   = RoleCategory.last
    assert(rc_root != 2 )
    assert_raises(ArgumentError){ rc_root < 2 }
    assert_operator rc_root, :<,  rc_last
    assert_operator rc_last,   :>,  rc_root
    assert_operator rc_root, :<,  rc_harami
    assert_operator rc_root, :<=, rc_harami
    assert_operator rc_harami, :<=, rc_harami
    assert_operator rc_harami, :>,  rc_root
    assert_operator rc_harami, :>=, rc_root
    assert_operator rc_harami, :>=, rc_harami

    assert_equal(-1, rc_root <=> rc_harami)
    assert_equal( 1, rc_harami <=> rc_root)
    assert_equal( 0, rc_root <=> rc_root)
    assert_equal(-1, rc_root <=> RoleCategory['subsubsystem'])
    assert_nil (rc_club <=> rc_harami)
    assert_nil (rc_club <=> nil)
  end

  test "superior, superiors and subordinates" do
    rc_root    = RoleCategory[:ROOT]
    rc_harami    = RoleCategory[:harami]
    rc_subsystem = RoleCategory[:subsystem]
    assert_equal  rc_root,  rc_harami.superior
    assert_equal [rc_root], rc_harami.superiors
    assert_equal [rc_root, rc_subsystem], RoleCategory['subsubsystem'].superiors

    exp = [RoleCategory['club'], role_categories(:rc_general_ja), rc_harami, rc_subsystem, role_categories(:rc_translation)] # No grandchildren
    assert_equal exp, rc_root.subordinates.sort{|a,b| a.mname <=> b.mname}
    assert       rc_root.root_category?
    assert_equal rc_root, RoleCategory.root_category
    RoleCategory.delete_all
    assert_nil   RoleCategory.root_category
  end

  test "tree" do
    tree = RoleCategory.tree
    # tree.print_tree # for DEBUG
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

    assert_operator tree.size, :>=, 7
    assert_equal 2, tree['club'].size
    assert_equal 0, tree.node_depth
    assert_equal 1, tree['club'].node_depth
    assert_equal 2, tree['club']['subclub'].node_depth
    assert_equal 2, tree.node_height
    assert_equal tree['club'], tree['club']['subclub'].parent
    assert_equal [tree['club']['subclub']], tree['club'].children
    assert     tree['club']['subclub'].is_only_child?
    assert_not tree['club'].is_only_child?
    assert_equal [tree['subsystem']['subsubsystem']], tree['subsystem']['sub2system'].siblings

    assert_nil       (tree['club'] <=> tree['club']['subclub'])
    # assert_equal -1, (tree['club'] <=> tree['harami'])  # -1 in Tree::TreeNode but nil in its subclass(!)
    # assert_equal -1, (tree['subsystem']['subsubsystem'] <=> tree['subsystem']['sub2system'])  # nil for some reason.
    assert_nil   (tree['club']['subclub'] <=> tree['subsystem']['subsubsystem'])
    assert_nil       (tree['club']['subclub'] <=> tree['harami'])

    assert      tree['club'  ].direct_line?(tree['club']['subclub'])
    assert_not  tree['harami'].direct_line?(tree['club']['subclub'])
  end

  test "trees" do
    trees = RoleCategory.trees [:subclub, :harami, :club].map{|i| RoleCategory[i]}, klass: RoleCategoryNode
    assert_equal 2, trees.size          # Array[:harami, :club]
    assert_equal 2, trees.find{|i| i.name == 'club'}.size  # Node[:club, :subclub]
    assert trees.find{|i| i.name == 'harami'}.is_leaf?
    assert trees.find{|i| i.name == 'harami'}.is_root?
  end
end
