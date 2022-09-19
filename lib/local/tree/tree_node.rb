
# This file is loaded from /config/application.rb

module Tree

  # Overwrite method {#<=>}
  #
  # Basically taken from https://github.com/masasakano/RubyTreeCmpOperator
  # except {#<=>} is NOT redefined in the repo but in this module.
  class TreeNode

    # Provides a new comparison operation for the nodes.
    #
    # Comparison is based on the ordering of either {#each} or {#breadth_each}
    # according to the keyword parameter +policy+. Alternatively, if +policy+
    # is +:direct_or_sibling+, this returns +nil+ unless self and +other+
    # are in the direct line, that is, either must be an ancestor of the other
    # or both must be the direct siblings to eath other. If +:direct_only+,
    # even those in a sibling-relationship would return +nil+.
    # Finally, if +:name+, they are compared on the basis of {#name}.
    #
    # @param [Tree::TreeNode] other The other node to compare against.
    # @param [Symbol] policy One of +:each+, +:breadth_each+, +:direct_or_sibling+, +:direct_only+., and +:name+
    # @return [Integer, NilClass] +1 if this node is a 'successor', 0 if equal and -1 if
    #                   this node is a 'predecessor'. Returns 'nil' if the other
    #                   object is not like a {Tree::TreeNode}.
    def cmp(other, policy: :each)
      # @note Technically, the algorithm can be significantly simplified.
      #   For example, the index of +tree+ for {#breadth_each} can be given with
      #     tree.root.send(:breadth_each).to_a.find_index{|i| i == tree}
      #   as implemented in _get_index_in_each() in /test/test_tree.rb
      #   In that case, +:direct_only+ can be judged with
      #     self == other || parentage.include?(other) || other.parentage.include?(self)
      #
      #   See the method _spaceship_through_each() in /test/test_tree.rb
      #   for the real implementation, which is used in the test code for
      #   this method test_cmp() for verification.
      #
      #   However, such a simple algorithm can be slow and memory-hungry
      #   when the tree structure to examine is huge because they traverse
      #   all the elements from the ROOT always.  The algorithm below is
      #   much more efficient in such cases.

      #return super if %i(parentage root? breadth_each).any?{|i| !other.respond_to?(i)} # super should be used if this method is named "<=>"
      #return(self <=> other) if %i(breadth_each parent children).any?{|i| !other.respond_to?(i)}
      return nil if %i(breadth_each parent children).any?{|i| !other.respond_to?(i)}
      return 0 if self == other
      return(self.name <=> other.name) if :name == policy

      # Constructs Arrays of [Root.name, Integer(sibling_rank(0<=x)), Integer, ...]
      arself, arother = _make_arrays_for_cmp(other)

      # ROOTs differ (n.b., arrays are destructively modified)
      return nil if arself.shift != arother.shift

      case policy
      when :breadth_each
        size_cmp = (arself.size <=> arother.size)
        return((size_cmp != 0) ? size_cmp : (arself <=> arother))

      when :each, :direct_only, :direct_or_sibling
        arself.zip(arother).each_with_index do |ea, i|
          case (res = (ea[0] <=> ea[1]))
          when 1, -1
            case policy
            when :each
              return res
            when :direct_or_sibling
              return(((i == arself.size-1) && (i == arother.size-1)) ? res : nil)
            else # :direct_only
              return nil
            end
          when nil  # ea[1] is nil, meaning other is an ancestor of self.
            return 1
          end
        end
        return(-1)  # meaning self is an ancestor of other, including the case where self is ROOT.
      else
        raise ArgumentError, "option policy (#{policy.inspect}) is none of :each, :breadth_each, :direct_or_sibling, :direct_only and :name"
      end
    end


    # Constructs Arrays for {#cmp}
    #
    # Retruns a doulbe Array (self, other). Each Array consists of
    #   [Root.name, Integer(sibling_rank(0<=x)), Integer, ...]
    #
    # For example, if self is a third grandchild of the eldest child of theroot
    # with the name "Root1", the array is
    #   ["Root1", 0, 2]
    #
    # @param [Tree::TreeNode] other The other node to compare against.
    # @return [Array] Double array(array_for_self, array_for_other)
    def _make_arrays_for_cmp(other)
      [self, other].map{ |tre|
        arret = []
        ctree = tre
        loop do
          (paren = ctree.parent) || break
          arret << paren.children.find_index{|i| i == ctree}
          ctree = paren
        end
        arret << ctree.name
        arret.reverse
      }
    end
    private :_make_arrays_for_cmp

    # Overwrite {#<=>}
    #
    # The policy is +:direct_or_sibling+, i.e., instances in separate branches
    # would NOT be comparable, returning +nil+.
    #
    # This should set +<+ and +>+ and alike (+<=+ etc).
    #
    # @param other [Tree::TreeNode] The other node to compare against.
    # @return [Integer, NilClass] +1 if this node is a 'successor', 0 if equal and -1 if
    #                   this node is a 'predecessor'. Returns 'nil' if the other
    #                   object is not like a {Tree::TreeNode}.
    def <=>(other)
      cmp(other, policy: :direct_or_sibling)
    end
  end
end

