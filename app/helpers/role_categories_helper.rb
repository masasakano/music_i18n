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
  # @param strict [Boolean] If true, and if there is no node that has a superior_id referred to another one, this raises an Exception.
  # @return [Array<Tree::TreeNode>] the class of elements is klass
  def trees(alldb=nil, klass: Tree::TreeNode, strict: false)
    alldb = (alldb ? alldb.uniq : self.all.order(:id))
    return [] if alldb.empty?
    return trees_reorganize_on_superior(alldb, klass, strict: strict) if alldb[0].respond_to? :superior_id

    tmprootnode = klass.new(:TmpRootNode)
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

  # Returns reorganized trees (Array) based on superior_id
  #
  # @param alldb [Array<Object>] Should be an Array (or equivalent) of model class-es.
  # @param klass [Class] The class to be returned. {Tree::TreeNode} (Default) or its subclass.
  # @param strict [Boolean] If true, and if there is no node that has a superior_id referred to another one, this raises an Exception.
  # @return [Array<Tree::TreeNode>] the class of elements is klass
  def trees_reorganize_on_superior(alldb, klass, strict: false)
    tmprootnode = klass.new(:TmpRootNode)
    allnodes = alldb.map{|erc_db| klass.new(erc_db.mname, erc_db) }
    alldb.zip(allnodes).each do |ea| # [[Model1, Node1], ...]
      mdl, node = ea
      suid = mdl.superior_id
      next if !suid
      parent_ind = alldb.find_index{|ea_m| ea_m.id == suid}
      if !parent_ind
        raise "ERROR: Strangely no has superior_id=#{suid}, referred from model.id=#{mdl.id} in the given models: #{alldb.inspect}" if strict
        next
      end
      if node == allnodes[parent_ind]
        warn "Node is the child of self, which should never happen."
        next
      end
      allnodes[parent_ind] << node
    end
    allnodes.select{|i| i.root?}
  end
  private :trees_reorganize_on_superior

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
      if !enode.root?
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
      return enode << newnode #if enode.leaf?
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

