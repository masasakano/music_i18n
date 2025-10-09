# -*- coding: utf-8 -*-

# Module to implement methods of default_place and add_default_place
#
# == Description
#
# Class method +default_place+ and instance method +add_default_place+
#
# @example
#   include ModuleDefaultPlace
#
module ModuleDefaultPlace
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # extend ModuleApplicationBase
  # extend ModuleCommon

  module ClassMethods
    #
    # Returns the default Place for the class
    #
    # The class may define up to two default candidate Places
    #
    # 1. DEF_FIRST_CANDIDATE_PLACE    # First candidate Place or keyword like JPN (A3-code)
    # 2. DEF_FALLBACK_CANDIDATE_PLACE # Fallback Place if DEF_FIRST_CANDIDATE_PLACE and {Place.unknown} fail.
    #
    # Here, the value can be these constants can be nil, Place, or Prefecture, Country, or keywords
    # like JP (A2-code), JPN (A3) to determine the {Country}, which indicates the Unknown {Place} in it.
    #
    # @example  
    #    HaramiVid.default_place  # defined in ModuleDefaultPlace
    #
    # @return [Place, NilClass]
    def default_place
      (self.const_defined?(:DEF_FIRST_CANDIDATE_PLACE) && Place.unknown_place_from_any(self::DEF_FIRST_CANDIDATE_PLACE)) ||
        (Place.unknown rescue nil) ||
        (self.const_defined?(:DEF_LATTER_CANDIDATE_PLACE) && Place.unknown_place_from_any(self::DEF_LATTER_CANDIDATE_PLACE)) ||
        (Place.first rescue nil)
    end
  end  # module ClassMethods

  # Associate a Place to self IF and only IF no Place is currently associated to the model instance.
  #
  # @param cand_place [Place, NilClass] The first candidate
  # @return [Place, FalseClass]  False if a significant Place is already associated.
  def add_default_place(cand_place=nil)
    self.place = (cand_place || self.class.default_place) if !self.place
  end

  #################
  private 
  #################

end
