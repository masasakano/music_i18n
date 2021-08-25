require 'tree'  # TreeNode in Ruby Tree Gem

module RoleCategoriesHelper

  # Returns an Array of RubyTree-s
  #
  # Each Tree Node: (#{RoleCategory#mname}, RoleCategory)
  #
  # An Array of #{RoleCategory}-s can be given; if not all the records in DB
  # are used to construct the return node.
  #
  # This returns an Array in case there are multiple root nodes.
  # If no main argument is given (or nil), the returned Array should have only one element,
  # i.e., a root {Tree::TreeNode}.
  #
  # == Algorithm
  #
  # First, a dummy root node is created.
  # Any subsequent potentially parent-less nodes are treated as its child node
  # while processing. At the end of the processing all the direct child nodes
  # are returned as an Array with their parents all detached.
  #
  # @param alldb [Array<Object>] If nil, all the records in the model class.
  # @param klass: [Class] The class to be returned. {Tree::TreeNode} (Default) or its subclass.
  # @return [Array<Tree::TreeNode>]
  def trees(alldb=nil, klass: Tree::TreeNode)
    tmprootnode = klass.new(:TmpRootNode)
    alldb = (alldb ? alldb.uniq : self.all.order(:id))

    alldb.each do |erc_db| # Each-Role-Category_from_DB
      node2add = klass.new(erc_db.mname, erc_db)  # name=mname, content=RoleCategory
      is_added = false
      ar = tmprootnode.children  # A temporary variable is mandatory because tmprootnode may be modified inside the each iterator/loop.
      ar.each do |enode|
        newnode = add_rc_to_tree(enode, node2add)
        is_added = true if newnode
      end

      if !is_added
        # The new RoleCategory does not belong to any of the existing Nodes.
        tmprootnode << node2add
        next
      end
    end

    # Remove the dummy root node and transform the rest to an Array
    tmprootnode.children.map{|i| i.remove_from_parent!}
  end

  # Adds a new {RoleCategory} to a Tree as a node
  #
  # If the given {RoleCategory} is not related to the given {Tree::TreeNode},
  # nil is returned.
  # Otherwise the updated {Tree::TreeNode} node in which a node for the given
  # {RoleCategory} is inserted is returned.
  #
  # @param enode [Tree::TreeNode]
  # @param newnode [RoleCategory]
  # @return [Tree::TreeNode, NilClass]
  def add_rc_to_tree(enode, newnode)
    newrc = newnode.content
    cmp = (newrc <=> enode.content)
    case cmp
    when nil
      return nil
    when -1  # newnode-RoleCategory is the parent
      if !enode.is_root?
        enode.parent << newnode
        enode.remove_from_parent!
      end
      newnode << enode
      newnode.siblings.each do |en|
        if (newrc <=> en.content) == -1  # This would never be 1.
          en.remove_from_parent!
          newnode << en
        end
      end
      return newnode
    when 1   # newnode-RoleCategory is a descendant
      enode.children do |ea_ch|
        ret = send(__method__, ea_ch, newnode)
        return enode if ret  # non-nil means newnode was added to one of the descendants.
      end
      return enode << newnode #if enode.is_leaf?
    else
      warn "ERROR: Should never come here - the identical one is attempted to be added?: [cmp=#{cmp.inspect}][names(enode/new)="+enode.name+"/#{newnode.name}]"
    end

    # This point should never reach:
    warn "WARNING: Should never come here: [name="+enode.name+"]"
    enode.print_tree
    raise "Should not happen: cmp=#{cmp} enode=#{enode.inspect} / NEW=#{newnode.inspect}"
  end
  private :add_rc_to_tree

end

