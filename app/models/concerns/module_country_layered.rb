# -*- coding: utf-8 -*-

# Common module for Country/Prefecture/Place
#
# @example
#   include ModuleCountryLayered  # for more_significant_than?
#
module ModuleCountryLayered
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  #module ClassMethods
  #end # module ClassMethods

  # Returns true if self is "more significant" than other.
  #
  # "more significant" means self is not {#unknown?} and other is {#unknown}
  # at the same layer.  If they are identical, returns false
  #
  # == Algorithm
  #
  # 1. If {#layered_significances} are equal, returns false.
  # 2. If self's Country is more significant than other, return true. If the other way around, return false. If statuses are equal, go next.
  # 3. Same as 1 but with Prefecture
  # 4. Same as 1 but with Place
  #
  # @see less_significant_than?
  #
  # @param [Country, Prefecture, Place] other
  def more_significant_than?(other)
    ret = _more_significant_than_or_absolute_false(other)
    ((:absolute_false == ret) ? false : ret)
  end

  # Similar to the inverse of {#more_significant_than?}
  #
  # But this returns false when the significance levels for both self and other
  # are the same.  Namely, 
  # Some combinations of +[self, other], for example
  #   [Country.second, Country.second.unknown_prefecture] 
  # would return false in any of:
  #
  #   self.more_significant_than?(other)
  #   self.less_significant_than?(other)
  #   other.more_significant_than?(self)
  #   other.less_significant_than?(self)
  #
  # @param [Country, Prefecture, Place] other
  def less_significant_than?(other)
    ret = _more_significant_than_or_absolute_false(other)
    ((:absolute_false == ret) ? false : !ret)
  end

  # Core routine of {#more_significant_than?} and {#less_significant_than?}
  #
  # @return [Boolean, Symbol] Boolean or :absolute_false when it should be false when called from either
  def _more_significant_than_or_absolute_false(other)
    self_lss = layered_significances  # lss: Layered_SignificanceS 
    other_lss = other.layered_significances
    return :absolute_false if self_lss == other_lss
    (self_lss != [self_lss, other.layered_significances].sort.first)
  end
  private :_more_significant_than_or_absolute_false
end

