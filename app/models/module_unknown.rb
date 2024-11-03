# -*- coding: utf-8 -*-

# Module to implement {#unknown} to ApplicationRecord (ActiveRecord)
#
# This module provides a class method +unknown+ and instance method +unknown?+
# where the algorithm relies on the name ({Translation}) alone.  Note that
# some classes (such as {Place}, {Sex} and {Enknown}, for different reasons)
# implement their own method of `unknown`.
#
# The class that includes this module MUST define the +with_indifferent_access+ hash +UNKNOWN_TITLES+
# having keys of "ja|en|fr" each with translation to express the unknown model
# or its (one or) two-element Array for title and +alt_title+ (or String for title only) as in the following example.
#
# @example
#    class Work < ApplicationRecord
#      include ModuleUnknown
#
#      UNKNOWN_TITLES = UnknownPlayRole = {
#        "ja" => ['仕事形態不明', '仕事不明'],
#        "en" => ['Unknown work attitude', 'Unknown work'],
#        "fr" => ['Attitude de travail inconnue', 'Travail inconnu'],
#      }.with_indifferent_access
#
module ModuleUnknown
  include ModuleSetSingletonUnknown # for method set_singleton_unknown

  extend ActiveSupport::Concern
  module ClassMethods
    # @return [ApplicationRecord] attribute "mname"="unknown" may be set.
    def unknown(reload: false)
      #@record_unknown ||= self[[self::UNKNOWN_TITLES['en']].flatten.first, 'en']
      if reload || !@record_unknown
        @record_unknown = _unknown_forcible
      else
        return @record_unknown
      end

      if @record_unknown.respond_to? "mname="
        @record_unknown.mname = "unknown"
      end
      @record_unknown
    end

    # Private method to forcibly re-determine the "unknown".
    #
    # This basically OR-s all unknown title and alt_title in all the languages.
    #
    # @return [ApplicationRecord]
    def _unknown_forcible
      self.find_by_regex(:titles, /\A\s*(#{self::UNKNOWN_TITLES.values.inject([]){|i,j| i+[j].flatten}.map{|k| Regexp.quote(k)}.join('|')})\s*\z/i, sql_regexp: true)
    end
    private :_unknown_forcible
  end

  def unknown?
    (respond_to?(:mname) && "unknown" == mname.to_s) || (self == self.class.unknown)
  end
end

