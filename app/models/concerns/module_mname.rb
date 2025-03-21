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
# either the constant +REGEXP_IDENTIFY_MODEL+
# or method +regexp_identify_model+, which returns an equivalent
# (see prefecture.rb for a real example).  The constant is a Hash
# +with_indifferent_access+ with keys of mname with values
# of one of a model record, a Regular Expression to identify the record for the mname,
# and an Array of a pair of elements with the first one being the Regexp
# and the latter being a Hash to pass to {BaseWithTranslation#select_regex}
# to identify the record, which may contain the keys like +:langcode+ and/or +:where+.
#
# Note that the Regexp defined in +REGEXP_IDENTIFY_MODEL+ must be
# PostgreSQL-copabible although some basic differences between
# Ruby and PostgreSQL Regexps are corrected (see models/translation.rb for detail).
#
# @note
#   If the model +include ModuleCommon+, when {ModuleUnknown#unknown} is called first time (or +relaod: true+)
#   {#mname} is set to "unknown"
#
# @example
#   include ModuleMname
#   REGEXP_IDENTIFY_MODEL = {
#     default_XXX: /\Aあいうえお|\bXYZ\b/i,
#     default_YYY: [/\bABC\b/i, {langcode: "en", where: {"prefectures.country_id" => Country["GBR"].id}}],
#     default_ZZZ: MyModel.find(123),
#   }.with_indifferent_access
#     # Note the "prefectures." prefix is mandatory in the +where` value.
#     # Note "country_id" as opposed to "country" is mandatory.
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
      hsall = get_model_or_regexp_to_identify_model
      raise ArgumentError, "No mname of #{mname_in.inspect} for Class #{self.name}. Contact the code developer" if !hsall.keys.include?(mname_in.to_s)

      val = hsall[mname_in.to_s]
      re, hsin =
          if val.respond_to? :map
            val
          else
            [val, {}]
          end

      if re.class == self
        re
      else
        self.select_regex(:titles, re, sql_regexp: true, **(hsin.symbolize_keys)).first
      end
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

    # @return REGEXP_IDENTIFY_MODEL or that taken from method regexp_identify_model
    def get_model_or_regexp_to_identify_model
      if respond_to? :regexp_identify_model
        regexp_identify_model
      else
        self::REGEXP_IDENTIFY_MODEL
      end
    end
    #private :get_regexp_identify_model
  end # module ClassMethods

  # returns a significant mname as long as mname is defined for self
  #
  # @note The second element of each value of REGEXP_IDENTIFY_MODEL is ignored(!), and
  #    the first one that matches the Regexp is returned, regardless of
  #    the second element.
  #
  # @return [String] mname.to_s if mname.present?  If not, judge it according to Translation.
  #    If no corresponding mname is found, English (falling back to Japanese) Translation is returned.
  #    This should never return nil (or an empty String except when neither title nor alt_title is defined)
  def mname_to_s
    if mname.present? && !(s=mname.to_s.strip).empty?
      return s
    end

    self.class.get_model_or_regexp_to_identify_model.each_pair do |ek, ea_val|
      ea_re = (ea_val.respond_to?(:map) ? ea_val.first : ea_val)
      if ea_re.class == self.class
        return ek.to_s if ea_re == self
      else
        (alltras = best_translations).values.each do |tra|
          %i(title alt_title).each do |metho|
            return ek.to_s if (s=tra.send(metho)).present? && ea_re =~ s
          end
        end
      end
    end

    # mname is not found. Returns the English title (or alt_title) instead
    (best_translations["en"] || best_translations["ja"]).slice(:title, :alt_title).values.map{|i| (i.present? && i.strip.present?) ? i : nil}.compact.first || ""  # should never be an empty String in normal operations, but playing safe.
  end
end

