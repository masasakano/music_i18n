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
  # @param [Country, Prefecture, Place] other
  def more_significant_than?(other)
    self_lss = layered_significances
    other_lss = other.layered_significances
    return false if self_lss == other_lss
    (self_lss != [self_lss, other.layered_significances].sort.first)
  end

end

