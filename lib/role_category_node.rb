# -*- coding: utf-8 -*-

require 'tree'  # TreeNode in Ruby Tree Gem

# #see module #{RoleCategoriesHelper}
class RoleCategoryNode < Tree::TreeNode
  # Method <=> in Tree::TreeNode may not be what you expect.
  # Besides, it returns nil in many cases, which makes methods break down.
  # Hence if you want to use any of the following methods,
  #   :sort, :sort_by, :max, :max_by, :min, :min_by, :minmax, :minmax_by
  # make sure to call it with a block in which you implement your own comparson
  # algorithm.
  include Enumerable

  # True if self and other in the ascendant<=>descendant relation.
  #
  # @param other [Tree::TreeNode]
  def direct_line?(other)
    self == other || parentage.include?(other) || other.parentage.include?(self)
  end
  
  # Return a child node that is for the specified mname
  #
  # @param mname [String,Symbol,RoleCategory]
  # @return [RoleCategoryNode]
  def find_by_mname(mname)
    mname = mname.mname if mname.respond_to? :mname
    find{|i| i.name.to_s == mname.to_s}
  end

  # Return the maximum node depth to the deepest leaf
  #
  # If there is only ROOT, it is 0.
  #
  # @return [Integer]
  def max_node_depth
    ret = 0
    each_leaf do |node|
      ret = [ret, node.node_depth].max
    end
    ret
  end

  # Any "leaf" with nil "content" is (destructively) removed from self.
  #
  # @return [self]
  def compact!
    max_node_depth.times do
      each do |node|
        if !node.content && node.is_leaf?
          node.parent.remove! node
        end
      end
    end
    self
  end

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)

  def inspect
    s = sprintf "<RCNode(%s:%s[depth=%d", content, name, node_depth
    s + (is_leaf? ? '(LEAF)])>' : sprintf('])--%s>', children.inspect))
  end
end

