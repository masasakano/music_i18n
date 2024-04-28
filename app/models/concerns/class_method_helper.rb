# -*- coding: utf-8 -*-

# Common module to implement helper class-methods
#
# @example
#   include ClassMethodHelper
#
module ClassMethodHelper
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  module ClassMethods
    # Implementing self.default for Classes
    #
    # If regex is given and if the model is BaseWithTranslation, regexp is used to search title and alt_title.
    # langcode can be specified.
    # If model is given, it is simply used.
    #
    # @example an example
    #    # Class-method helpers
    #    include ClassMethodHelper
    #
    #    case context.to_s.underscore.singularize
    #    when *(%w(harami_vid harami1129))
    #      return find_default(self, regex: /John +Mac/i)
    #    end
    #    unknown
    #
    # @example other examples
    #    return (find_default(self, regex: /John +Mac/, raises: false) || self.unknown)
    #    return (find_default(my_method_abc)  # may raise an Exception
    #
    # @option model [BaseWithTranslation] 
    # @param regex [Regexp] if this is given, model must be given.
    # @param langcode [Symbol, String]
    # @param raises [Boolean] if true (Def), raises if something goes wrong. If false, nil is returned.
    def find_default(model=nil, regex: nil, langcode: nil, raises: true, sql_regexp: true)
      bind = caller_locations(1,1)[0]  # Ruby 2.0+
      caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/(test|app|config|db|lib)/)@, '\1'), bind.lineno
      # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

      ret = 
        if regex
          select_regex(:titles, regex, langcode: langcode, sql_regexp: sql_regexp).first  # ".distinct" can be added but makes no difference with just a possibility of messing up!
        else
          model
        end

      return ret if ret  # This should never fail!

      msg = "Failed to identify the default #{self.name}"
      msg_head = "ERROR(#{caller_info}): "
      logger.error(msg_head+msg)
      warn msg_head+msg
      raise msg if raises
      nil
    end # def find_default(model=nil, regex: nil, langcode: nil, raises: true)
  end # module ClassMethods
end

