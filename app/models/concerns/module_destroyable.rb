# -*- coding: utf-8 -*-

# Module to implement {#destroyable?} to ApplicationRecord (ActiveRecord)
#
# This module provides the instance method +destroyable?+
# which returns true if the record is allowed to be destroyed safely
# by sufficiently-privileged users, regardless of whether the user
# caling this method has a sufficient priviledge or not.
#
# The constraint that this method expresses is a combination of application-level
# Rails-level, and DB-level constraints, but not based on the user-privilege;
# anyway, the model does not know the user (in general).
# For example, if +something#unknown?+ is true, +something+ usually should not
# be destroyed even by superuser, though there are probably no DB-level constraints.
#
# The class that includes this module MUST define the Array +DEPENDENT_CHILDREN+
# listing the methods of its dependent children (or Boolean), the existence of any of which
# should prohibit the record to be destroyed; specifically, if the return value
# of any method is +present?+, {#destroyable?} returns false, else true.
#
# In addition to +DEPENDENT_CHILDREN+, +unknown?+ method is, if defined,
# taken into account.
#
# @example
#    class Bear < ApplicationRecord
#      include ModuleDestroyable  # for destroyable?
#
#      DEPENDENT_CHILDREN = [:cubs, :spouse, :dogs, :important?]  # essential for ModuleDestroyable
#      # If any of the methods [:cubs, :spouse, :dogs, :important?] returns something significant,
#      # Bear#destroyable? is false.
#
#      has_many :hairs, dependent: :destroy  # Bear can be destroyed regardless of Hair-s
#      has_many :cubs, dependent: :restrict_with_exception
#      has_one  :spouse, dependent: :restrict_with_exception
#      def collab_dogs
#        Dog.friends_with(self).to_a  # => Array
#      end
#      def important?
#        !!@important  # => Boolean
#      end
#    end
#
module ModuleDestroyable
  def destroyable?
    return false if self.class::DEPENDENT_CHILDREN.any?{
      send(_1).present?
    }
    return true if !respond_to?(:unknown?)
    !unknown?
  end
end

