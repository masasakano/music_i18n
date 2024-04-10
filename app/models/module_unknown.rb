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
# or its two-element Array for title and +alt_title+ as in the following example.
#
# @example
#    class Work < ApplicationRecord
#      include ModuleUnknown
#
#      UNKNOWN_TITLES = UnknownEngageEventItemHow = {
#        "ja" => ['仕事形態不明', '仕事不明'],
#        "en" => ['Unknown work attitude', 'Unknown work'],
#        "fr" => ['Attitude de travail inconnue', 'Travail inconnu'],
#      }.with_indifferent_access
#
module ModuleUnknown

  extend ActiveSupport::Concern
  module ClassMethods
    # @return [ApplicationRecord]
    def unknown
      #@record_unknown ||= self[[self::UNKNOWN_TITLES['en']].flatten.first, 'en']
      @record_unknown ||= self.find_by_regex(:titles, /\A\s*(#{self::UNKNOWN_TITLES.values.inject([]){|i,j| i+[j].flatten}.map{|k| Regexp.quote(k)}.join('|')})\s*\z/i)
    end
  end

  def unknown?
    self == self.class.unknown
  end
end

