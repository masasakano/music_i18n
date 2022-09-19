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

    assert_operator tree.size, :>=, 7, "tree should have more than 6 nodes: "+tree.inspect
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

    assert_equal  -1, (tree['club'] <=> tree['club']['subclub'])
    #assert_nil       (tree['club'] <=> tree['club']['subclub'])  # In RubyTree Ver.1
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

  # Test the cmp (new <=>) operator.
  #
  #          +----------+
  #          |  ROOT    |
  #          +-+--------+
  #            |
  #            |    +---------------+   +------------------+
  #            +----+  X1(xnode)    |-+-+  X11(tnode)      |
  #            |    +---------------+ | +------------------+
  #            |                      |
  #            |                      +--- X12(knode) --- X121(anode)
  #            |                      |
  #            |                      +--- X13(cnode)
  #            |    +---------------+
  #            +----+  CHILD1       |
  #            |    +---------------+
  #            |
  #            |    +---------------+
  #            +----+  CHILD2       |
  #            |    +---------------+
  #            |
  #            |    +---------------+   +------------------+
  #            +----+  CHILD3       +---+  CHILD4          |
  #                 +---------------+   +------------------+
  #
  test "tree_node modification" do
      @root = Tree::TreeNode.new('ROOT', 'Root Node')

      @child1 = Tree::TreeNode.new('Child1', 'Child Node 1')
      @child2 = Tree::TreeNode.new('Child2', 'Child Node 2')
      @child3 = Tree::TreeNode.new('Child3', 'Child Node 3')
      @child4 = Tree::TreeNode.new('Child4', 'Grand Child 1')
      @child5 = Tree::TreeNode.new('Child5', 'Child Node 4')

    #def test_cmp
      @x1  = Tree::TreeNode.new('xnode-x1',  'X Node 1')
      @x11 = Tree::TreeNode.new('tnode-x11', 'X Node 11')
      @x12 = Tree::TreeNode.new('knode-x12', 'X Node 12')
      @x121= Tree::TreeNode.new('Anode-x121','X Node 121')
      @x13 = Tree::TreeNode.new('cnode-x13', 'X Node 13')
      @root << @x1
      @x1 << @x11
      @x1 << @x12 << @x121
      @x1 << @x13

    # Create the actual test tree.
    #def setup_test_tree
      @root << @child1
      @root << @child2
      @root << @child3 << @child4
    #end

      root2 = Tree::TreeNode.new('Diff', 'other')
      chi2  = Tree::TreeNode.new('Diff_chi', 'diffchi')
      root2 << chi2

      # Tests of test-internal method
      assert_equal(0, _get_index_in_each(@root,   :each))
      assert_equal(1, _get_index_in_each(@x1,     :each))
      assert_equal(2, _get_index_in_each(@x11,    :each))
      assert_equal(6, _get_index_in_each(@child1, :each))
      assert_equal(0, _get_index_in_each(@root,   :breadth_each))
      assert_equal(1, _get_index_in_each(@x1,     :breadth_each))
      assert_equal(5, _get_index_in_each(@x11,    :breadth_each))
      assert_equal(2, _get_index_in_each(@child1, :breadth_each))

      # .cmp(other, policy: :each) (Default)
      metho = :each
      assert_equal( 0, @root.cmp(@root),     'root == root')
      assert_equal( 0, @child4.cmp(@child4), 'child4 == child4')
      assert_equal(-1, @root.cmp(@child4),   'root < child')
      assert_equal(-1, @x1.cmp(@x11),  'parent < child')
      assert_equal(-1, @x1.cmp(@x12),  'parent < child')
      assert_equal(-1, @x1.cmp(@x121), 'parent < grandchild')
      assert_equal(-1, @root.cmp(@x121), 'parent < grandgrandchild')
      assert_equal( 1, @x12.cmp(@x1),  'child > parent')
      assert_equal( 1, @x121.cmp(@x1), 'grandchild > parent')
      assert_equal( 1, @x121.cmp(@root), 'grandgrandchild > parent')
      assert_equal(-1, @x11.cmp(@x12), 'elder-sibling < younger-sibling')
      assert_equal(-1, @x11.cmp(@x13), 'elder-sibling < younger-sibling')
      assert_equal( 1, @x12.cmp(@x11), 'younger-sibling < elder-sibling')
      assert_equal( 1, @x13.cmp(@x11), 'younger-sibling < elder-sibling')
      assert_equal(-1, @x11.cmp(@x121), 'elder uncle < nephew')
      assert_equal( 1, @x13.cmp(@x121), 'younger uncle > nephew')
      assert_equal( 1, @x121.cmp(@x11), 'nephew > elder uncle')
      assert_equal(-1, @x121.cmp(@x13), 'nephew < younger uncle')
      assert_equal(-1, @x121.cmp(@child1), 'grandnephew < younger granduncle')
      assert_equal(-1, @x1.cmp(@child4), 'cousin of elder uncle < cousin of younger uncle')
      assert_equal( 1, @child4.cmp(@x1), 'cousin of younger uncle < cousin of elder uncle')
      assert_equal(-1, @x13.cmp(@child4), 'grandcousin of elder uncle < grandcousin of younger uncle')
      assert_equal( 1, @child4.cmp(@x13), 'grandcousin of younger uncle < grandcousin of elder uncle')
      assert_nil(      @root.cmp( root2), 'nil for different root')
      assert_nil(      @child4.cmp(chi2), 'nil for different root')
      assert_nil(      @child4.cmp(9999), 'nil for another Object')
      assert_equal( 1, @x13.cmp(@x11, policy: metho), 'younger-sibling < elder-sibling')
      assert_equal(_spaceship_through_each(@x121, @x1, metho),  @x121.cmp(@x1),  'x121-x1 with each method')
      assert_equal(_spaceship_through_each(@x121, @x13, metho), @x121.cmp(@x13), 'x121-x13 with each method')
      assert_equal(_spaceship_through_each(@child4, @x13, metho), @child4.cmp(@x13), 'child4-x13 with each method')

      # .cmp(other, policy: :breadth_each)
      metho = :breadth_each
      assert_equal( 0, @root.cmp(@root, policy: metho),     'root == root')
      assert_equal( 0, @child4.cmp(@child4, policy: metho), 'child4 == child4')
      assert_equal(-1, @root.cmp(@child4, policy: metho),   'root < child')
      assert_equal(-1, @x1.cmp(@x11, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x12, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x121, policy: metho), 'parent < grandchild')
      assert_equal(-1, @root.cmp(@x121, policy: metho), 'parent < grandgrandchild')
      assert_equal( 1, @x12.cmp(@x1, policy: metho),  'child > parent')
      assert_equal( 1, @x121.cmp(@x1, policy: metho), 'grandchild > parent')
      assert_equal( 1, @x121.cmp(@root, policy: metho), 'grandgrandchild > parent')
      assert_equal( 1, @x121.cmp(@child1, policy: metho), 'grandnephew > younger granduncle')
      assert_equal(-1, @x11.cmp(@x12, policy: metho), 'elder-sibling < younger-sibling')
      assert_equal(-1, @x11.cmp(@x13, policy: metho), 'elder-sibling < younger-sibling')
      assert_equal( 1, @x12.cmp(@x11, policy: metho), 'younger-sibling < elder-sibling')
      assert_equal( 1, @x13.cmp(@x11, policy: metho), 'younger-sibling < elder-sibling')
      assert_equal(-1, @x11.cmp(@x121, policy: metho), 'elder uncle < nephew')
      assert_equal(-1, @x13.cmp(@x121, policy: metho), 'younger uncle > nephew')
      assert_equal( 1, @x121.cmp(@x11, policy: metho), 'nephew > elder uncle')
      assert_equal( 1, @x121.cmp(@x13, policy: metho), 'nephew < younger uncle')
      assert_equal(-1, @x1.cmp(@child4, policy: metho), 'cousin of elder uncle < cousin of younger uncle')
      assert_equal( 1, @child4.cmp(@x1, policy: metho), 'cousin of younger uncle < cousin of elder uncle')
      assert_equal(-1, @x13.cmp(@child4, policy: metho), 'grandcousin of elder uncle < grandcousin of younger uncle')
      assert_equal( 1, @child4.cmp(@x13, policy: metho), 'grandcousin of younger uncle < grandcousin of elder uncle')
      assert_nil(      @root.cmp( root2, policy: metho), 'nil for different root')
      assert_nil(      @child4.cmp(chi2, policy: metho), 'nil for different root')
      assert_nil(      @child4.cmp(9999, policy: metho), 'nil for another Object')
      assert_equal(_spaceship_through_each(@x121, @x1, metho),  @x121.cmp(@x1, policy: metho),  'x121-x1 with breadth_each method')
      assert_equal(_spaceship_through_each(@x121, @x13, metho), @x121.cmp(@x13, policy: metho), 'x121-x13 with breadth_each method')
      assert_equal(_spaceship_through_each(@child4, @x13, metho), @child4.cmp(@x13, policy: metho), 'child4-x13 breadth_with each method')

      # .cmp(other, policy: :direct_or_sibling)
      metho = :direct_or_sibling
      assert_equal( 0, @root.cmp(@root, policy: metho),     'root == root')
      assert_equal( 0, @child4.cmp(@child4, policy: metho), 'child4 == child4')
      assert_equal(-1, @root.cmp(@child4, policy: metho),   'root < child')
      assert_equal(-1, @x1.cmp(@x11, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x12, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x121, policy: metho), 'parent < grandchild')
      assert_equal(-1, @root.cmp(@x121, policy: metho), 'parent < grandgrandchild')
      assert_equal( 1, @x12.cmp(@x1, policy: metho),  'child > parent')
      assert_equal( 1, @x121.cmp(@x1, policy: metho), 'grandchild > parent')
      assert_equal( 1, @x121.cmp(@root, policy: metho), 'grandgrandchild > parent')
      assert_equal(-1, @x11.cmp(@x12, policy: metho), 'elder-sibling < younger-sibling')
      assert_equal(-1, @x11.cmp(@x13, policy: metho), 'elder-sibling < younger-sibling')
      assert_equal( 1, @x12.cmp(@x11, policy: metho), 'younger-sibling > elder-sibling')
      assert_equal( 1, @x13.cmp(@x11, policy: metho), 'younger-sibling > elder-sibling')
      assert_equal( 1, @x13.cmp(@x12, policy: metho), 'younger-sibling > elder-sibling')
      assert_nil(      @x11.cmp(@x121, policy: metho), 'elder uncle <> nephew')
      assert_nil(      @x13.cmp(@x121, policy: metho), 'younger uncle <> nephew')
      assert_nil(      @x121.cmp(@x11, policy: metho), 'nephew <> elder uncle')
      assert_nil(      @x121.cmp(@x13, policy: metho), 'nephew <> younger uncle')
      assert_nil(      @x121.cmp(@child1, policy: metho), 'grandnephew <> younger granduncle')
      assert_nil(      @x1.cmp(@child4, policy: metho), 'cousin of elder uncle <> cousin of younger uncle')
      assert_nil(      @child4.cmp(@x1, policy: metho), 'cousin of younger uncle <> cousin of elder uncle')
      assert_nil(      @x13.cmp(@child4, policy: metho), 'grandcousin of elder uncle <> grandcousin of younger uncle')
      assert_nil(      @child4.cmp(@x13, policy: metho), 'grandcousin of younger uncle <> grandcousin of elder uncle')
      assert_nil(      @root.cmp( root2, policy: metho), 'nil for different root')
      assert_nil(      @child4.cmp(chi2, policy: metho), 'nil for different root')
      assert_nil(      @child4.cmp(9999, policy: metho), 'nil for another Object')

      # .cmp(other, policy: :direct_only)
      metho = :direct_only
      assert_equal( 0, @root.cmp(@root, policy: metho),     'root == root')
      assert_equal( 0, @child4.cmp(@child4, policy: metho), 'child4 == child4')
      assert_equal(-1, @root.cmp(@child4, policy: metho),   'root < child')
      assert_equal(-1, @x1.cmp(@x11, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x12, policy: metho),  'parent < child')
      assert_equal(-1, @x1.cmp(@x121, policy: metho), 'parent < grandchild')
      assert_equal(-1, @root.cmp(@x121, policy: metho), 'parent < grandgrandchild')
      assert_equal( 1, @x12.cmp(@x1, policy: metho),  'child > parent')
      assert_equal( 1, @x121.cmp(@x1, policy: metho), 'grandchild > parent')
      assert_equal( 1, @x121.cmp(@root, policy: metho), 'grandgrandchild > parent')
      assert_nil(      @x11.cmp(@x12, policy: metho), 'elder-sibling <> younger-sibling')
      assert_nil(      @x13.cmp(@x12, policy: metho), 'younger-sibling <> elder-sibling')

      # .cmp(other, policy: :name)
      metho = :name
      assert_equal( 0, @child4.cmp(@child4, policy: metho), 'Child4 == Child4')
      assert_equal(-1, @child4.cmp(@root, policy: metho), '"Child4" < "ROOT"')
      assert_equal( 1, @x1.cmp(@child4, policy: metho),   '"xnode-x1" (x1) > "Child4"')
      assert_equal(-1, @x121.cmp(@child4, policy: metho), '"Anode-x121" (x121) < "Child4"')
      
      assert_raise(ArgumentError){ @x11.cmp(@x12, policy: :wrong_one) }
  end

    # Returns an index of tre in #metho.to_a
    #
    # @param [Tree::TreeNode] tre1
    # @param [Tree::TreeNode] tre2
    # @param [Symbol] metho Either :each or :breadth_each
    # @return [Integer] -1, 0, 1
    def _spaceship_through_each(tre1, tre2, metho)
      _get_index_in_each(tre1, metho) <=> _get_index_in_each(tre2, metho)
    end

    # Returns an index of tre in #metho.to_a
    #
    # @param [Tree::TreeNode] tre
    # @param [Symbol] metho Either :each or :breadth_each
    # @return [Integer] non-negative Integer
    def _get_index_in_each(tre, metho)
      tre.root.send(metho).to_a.find_index{|i| i == tre}
    end

end
