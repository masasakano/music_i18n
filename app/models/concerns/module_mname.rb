# -*- coding: utf-8 -*-

# Common module to provide the method 'mname' (machine-name)
#
# +mname+ is usually used for a limited number of records that
# are actively used in some algorithms of this app.  The contents
# of the record that can be identified with +maname+ are usually
# supposed not to change significantly.
#
# For example, {RoleCategory} has method +mname+ (though RoleCategory
# does not include this module).  Although the records of RoleCategory
# are stored in DB, they have only four and racially changing their records's
# contents would result in a serious impact on this app's behaviour.
#
# Each class that includes this module is assumed to have
# the constant +REGEXP_IDENTIFY_MODEL+ which is a Hash
# +with_indifferent_access+ with keys of mname with values
# of Regular Expression to identify the record for the mname.
#
# Note that the Regexp defined in +REGEXP_IDENTIFY_MODEL+ must be
# PostgreSQL-copabible although some basic differences between
# Ruby and PostgreSQL Regexps are corrected (see models/translation.rb for detail).
#
# @example
#   include ModuleMname
#   REGEXP_IDENTIFY_MODEL = {
#     default_XXX: /\Aあいうえお|\bXYZ\b/i,
#     default_YYY: /\Aイロハ|\bABC\b/i,
#   }.with_indifferent_access
#
module ModuleMname
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  attr_accessor :mname  # defined occasionally for later use (by the caller).
  alias_method :text_new, :[] if self.method_defined?(:[]) && !self.method_defined?(:text_new) # Preferred to  alias :text_new :to_s


  module ClassMethods
    # Returns the record of the specified mname
    #
    # @param mname_in [String, Symbol]
    def find_by_mname(mname_in)
      raise ArgumentError, "No mname of #{mname_in} for Class #{self.name}. Contact the code developer" if !self::REGEXP_IDENTIFY_MODEL.keys.include?(mname_in.to_s)

      self.select_regex(:titles, self::REGEXP_IDENTIFY_MODEL[mname_in.to_s], sql_regexp: true).first
    end

    # Adds a new option to []
    #
    # If the first Argument is Symbol, it is interpreted as mname
    #
    # @param arg1 [Symbol, Object]
    def [](arg1, *args)
      if arg1.is_a? Symbol
        find_by_mname(arg1)
      else
        super(arg1, *args)  # This would raise NoMethodError or something if the original class does not have the method [], but it is a correct response.
      end
    end
  end # module ClassMethods

  # returns a significant mname as long as mname is defined for self
  #
  # @return [String, NilClass] mname.to_s if mname.present?  If not, judge it according to Translation.
  #    returns nil only when mname is not defined for self.
  def mname_to_s
    if mname.present? && !(s=mname.to_s.strip).empty?
      return s
    end

    self.class::REGEXP_IDENTIFY_MODEL.each_pair do |ek, ea_re|
      (alltras = best_translations).values.each do |tra|
        %i(title alt_title).each do |metho|
          return ek.to_s if (s=tra.send(metho)).present? && ea_re =~ s
        end
      end
    end

    (best_translations["en"] || best_translations["ja"]).slice(:title, :alt_title).values.map{|i| (i.present? && i.strip.present?) ? i : nil}.compact.first || ""  # should never be an empty String in normal operations, but playing safe.
  end

end

