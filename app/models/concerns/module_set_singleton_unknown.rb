# -*- coding: utf-8 -*-

# Simply to implement +set_singleton_unknown+
#
# Place (or Prefecture) does not include {ModuleUnknown} but implements the same methods
# with a different algorithm.  Yet, it still needs this method, hence this separate module.
#
# @example
#   include ModulePrimaryArtist
#   ChannelOnwer.primary  # => primary ChannelOnwer
#
module ModuleSetSingletonUnknown
  include ModuleCommon  # for set_singleton_method_val

  # In Object (usually String), sets a singleton method +unknown?+
  #
  # clobber is +ModuleCommon#set_singleton_method_val+ always set true.
  #
  # @param target [Object]
  # @return [Object] result of +target.unknown?+ which should be the same as +self.unknown?+
  def set_singleton_unknown(target)
    set_singleton_method_val(:unknown?, target: target, clobber: true, reader: true, derive: true)  # defined in module_common.rb
  end
end

